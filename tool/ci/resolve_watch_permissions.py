#!/usr/bin/env python3
"""Resolve observed Watch Health controls, then verify the expected visible UI.

The caller supplies an isolated, booted watchOS simulator. This helper uses
AXe UI interactions only; it never writes permission databases or app data.
On a fresh Kotrana Health sheet it grants the requested Workouts write access
on that disposable simulator, confirms the checked state, then submits Done.
AXE_PATH must point to the AXe 1.8.0 executable bundled with xcodebuildmcp 2.7.0.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid


class ResolutionError(RuntimeError):
    pass


def normalized(value):
    return " ".join(value.split()) if isinstance(value, str) else ""


def node_label(node):
    return normalized(node.get("AXLabel") or node.get("label") or node.get("title"))


def node_role(node):
    return normalized(node.get("type") or node.get("role")).lower().removeprefix("ax")


def node_frame(node):
    value = node.get("frame")
    if isinstance(value, dict):
        numbers = [value.get(key) for key in ("x", "y", "width", "height")]
    else:
        raw = node.get("AXFrame", "")
        numbers = re.findall(r"-?\d+(?:\.\d+)?", raw) if isinstance(raw, str) else []
    try:
        numbers = [float(value) for value in numbers]
    except (ValueError, TypeError):
        return None
    if len(numbers) != 4 or not all(math.isfinite(value) for value in numbers):
        return None
    return tuple(numbers)


def flatten(tree):
    roots = tree if isinstance(tree, list) else [tree]
    if not all(isinstance(node, dict) for node in roots):
        raise ResolutionError("AXe returned an unsupported UI tree")
    result = []

    def visit(node):
        if node.get("hidden") is True or node.get("visible") is False:
            return
        result.append(node)
        children = node.get("children", [])
        if not isinstance(children, list):
            raise ResolutionError("AXe node children must be a list")
        for child in children:
            if not isinstance(child, dict):
                raise ResolutionError("AXe returned an invalid child node")
            visit(child)

    for node in roots:
        visit(node)
    return result


def visible_nodes(tree):
    nodes = flatten(tree)
    roots = tree if isinstance(tree, list) else [tree]
    screens = [node_frame(root) for root in roots]
    screens = [frame for frame in screens if frame and frame[2] > 0 and frame[3] > 0]
    if not screens:
        raise ResolutionError("AXe tree has no screen frame; cannot verify visibility")
    visible = []
    for node in nodes:
        if node.get("hidden") is True or node.get("visible") is False:
            continue
        frame = node_frame(node)
        if not frame or frame[2] <= 0 or frame[3] <= 0:
            continue
        x, y, width, height = frame
        if any(x < sx + sw and x + width > sx and y < sy + sh and y + height > sy
               for sx, sy, sw, sh in screens):
            visible.append(node)
    return visible


def screen_bounds(tree):
    roots = tree if isinstance(tree, list) else [tree]
    frames = {node_frame(root) for root in roots}
    if len(frames) != 1:
        raise ResolutionError("Health scrolling needs one unambiguous screen frame")
    frame = frames.pop()
    if frame is None or frame[2] <= 0 or frame[3] <= 0:
        raise ResolutionError("Invalid Watch screen frame")
    return frame


def fully_visible(node, bounds):
    frame = node_frame(node)
    if frame is None:
        return False
    x, y, width, height = frame
    sx, sy, sw, sh = bounds
    return x >= sx and y >= sy and x + width <= sx + sw and y + height <= sy + sh


def health_action(nodes, bounds):
    """Grant the captured Workouts-only request on the supplied test Watch."""
    labels = {node_label(node) for node in nodes}
    if "Health Access" in labels:
        return matching_button(nodes, "Review")
    if "Write Access" not in labels:
        return None

    request = '“Kotrana Watch” would like permission to write the following data to Health.'
    explanation = ('APP EXPLANATION: Kotrana uses workout access to keep the Watch '
                   'app active while you follow your workout.')
    identity = any(node_label(node) in {request, explanation} or
                   normalized(node.get("AXValue")) in {request, explanation} for node in nodes)
    health_controls = [node for node in nodes if
                       str(node.get("AXUniqueId", "")).startswith("UIA.Health.WatchAuthSheet.")]
    if not identity or not health_controls:
        return None
    permitted_checkbox_ids = {"UIA.Health.WatchAuthSheet.Workouts",
                              "UIA.Health.WatchAuthSheet.SwitchCellALL_REQUESTED_DATA",
                              "UIA.Health.WatchAuthSheet.SwitchOutlet"}
    if any(node_role(node) == "checkbox" and node.get("AXUniqueId") not in permitted_checkbox_ids
           for node in health_controls):
        raise ResolutionError("The Health form contains an unrecognized permission request")

    workouts = health_checkbox(nodes, "Workouts", "UIA.Health.WatchAuthSheet.Workouts")
    all_requested = health_checkbox(nodes, "All Requested Data Below",
                                    "UIA.Health.WatchAuthSheet.SwitchCellALL_REQUESTED_DATA")
    if not workouts and not all_requested:
        return None

    # The current native request contains only HKObjectType.workoutType().
    # Prefer its own checkbox when it can be tapped without hitting the header.
    for control in (workouts, all_requested if not workouts else None):
        if control and control.get("AXValue") == "0" and health_control_tappable(control, nodes, bounds):
            return {**frame_center_tap(control, "CheckBox"),
                    "confirm_checkbox": control["AXUniqueId"]}

    if workouts and workouts.get("AXValue") != "1":
        # The captured lower form can place Workouts beneath the fixed header.
        # Bring it back into view; never tap through that toolbar or submit Done.
        if workouts.get("AXValue") == "0" and workouts.get("enabled") is True:
            return health_scroll(bounds, reverse=True)
        return None
    if not workouts:
        # A fresh capture must confirm All Requested Data Below checked before
        # scrolling onward to verify the actual Workouts checkbox.
        if all_requested.get("AXValue") == "1":
            return health_scroll(bounds)
        return None

    done = [node for node in nodes if node_label(node) == "Done" and
            node_role(node) == "genericelement"]
    if len(done) > 1:
        raise ResolutionError("Ambiguous Health control: Done")
    if done:
        control = done[0]
        if (control.get("AXUniqueId") != "UIA.Health.WatchAuthSheet.ConfigureCell.Button" or
                not health_control_tappable(control, nodes, bounds)):
            return None
        # AXe 1.8.0 resolves this GenericElement's label to the clock instead
        # of its visible frame. Use the center of this freshly observed,
        # fully onscreen Health control; ignore its activation point.
        return frame_center_tap(control, "GenericElement")

    return health_scroll(bounds)


def health_checkbox(nodes, label, identifier):
    candidates = [node for node in nodes if node_role(node) == "checkbox" and
                  (node_label(node) == label or node.get("AXUniqueId") == identifier)]
    if len(candidates) > 1:
        raise ResolutionError(f"Ambiguous Health checkbox: {label}")
    if not candidates:
        return None
    control = candidates[0]
    if node_label(control) != label or control.get("AXUniqueId") != identifier:
        raise ResolutionError(f"Unrecognized Health checkbox: {label}")
    if control.get("AXValue") not in {"0", "1"}:
        raise ResolutionError(f"Unrecognized Health checkbox value: {label}")
    return control


def health_control_tappable(control, nodes, bounds):
    if control.get("enabled") is not True or not fully_visible(control, bounds):
        return False
    headers = [node_frame(node) for node in nodes if node.get("AXUniqueId") == "Write Access"]
    if len(headers) != 1 or headers[0] is None:
        return False
    _, top, _, height = headers[0]
    return node_frame(control)[1] >= top + height


def frame_center_tap(control, element_type):
    x, y, width, height = node_frame(control)
    return {"gesture": "tap", "label": node_label(control), "element_type": element_type,
            "x": x + width / 2, "y": y + height / 2}


def health_scroll(bounds, reverse=False):

    # This exact gesture revealed Done in the captured 208 x 248 Health form.
    # Scale it to the validated live screen frame, never to a hidden control.
    sx, sy, width, height = bounds
    start, end = (90, 219) if reverse else (219, 90)
    return {"gesture": "swipe", "start_x": round(sx + width / 2, 2),
            "start_y": round(sy + height * start / 248, 2),
            "end_x": round(sx + width / 2, 2),
            "end_y": round(sy + height * end / 248, 2)}


def matching_button(nodes, label):
    candidates = [node for node in nodes if node_label(node) == label and node_role(node) == "button"]
    if len(candidates) > 1:
        raise ResolutionError(f"Ambiguous Health control: {label}")
    if not candidates:
        return None
    node = candidates[0]
    if node.get("enabled") is False:
        return None
    return {"label": label, "element_type": "Button"}


def inspect_ui(tree, expected):
    nodes = visible_nodes(tree)
    labels = [node_label(node) for node in nodes if node_label(node)]
    action = health_action(nodes, screen_bounds(tree))
    if action:
        return {"state": "health", "action": action, "labels": labels}
    health_visible = any("health access" in label.lower() or label == "Write Access" for label in labels) or any(
        str(node.get("AXUniqueId", "")).startswith("UIA.Health.WatchAuthSheet.") for node in nodes)
    dialog_visible = any(node_role(node) in {"alert", "dialog", "sheet"} for node in nodes)
    if health_visible or dialog_visible:
        return {"state": "unresolved-dialog", "labels": labels}
    expected = normalized(expected)
    expected_visible = any(expected in node_label(node) for node in nodes
                           if node_role(node) not in {"application", "window"})
    return {"state": "expected" if expected_visible else "waiting", "labels": labels}


def validate_watch(inventory, udid):
    for runtime, devices in inventory.get("devices", {}).items():
        for device in devices:
            if device.get("udid", "").lower() != udid.lower():
                continue
            if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.watchOS-"):
                raise ResolutionError("The supplied UDID is not a watchOS simulator")
            if device.get("isAvailable") is False or device.get("state") != "Booted":
                raise ResolutionError("The supplied Watch simulator must be available and booted")
            return {"udid": udid, "name": device.get("name"), "runtime": runtime}
    raise ResolutionError("The supplied Watch simulator was not found")


class Resolver:
    def __init__(self, axe, udid, expected, output, timeout=60, run=subprocess.run,
                 monotonic=time.monotonic, sleep=time.sleep):
        self.axe = Path(axe)
        self.udid = udid
        self.expected = expected
        self.output = Path(output)
        self.deadline = monotonic() + timeout
        self.run = run
        self.now = monotonic
        self.sleep = sleep
        self.events = []
        self.capture_number = 0
        self.env = os.environ.copy()
        frameworks = self.axe.parent / "Frameworks"
        if frameworks.is_dir():
            existing = self.env.get("DYLD_FRAMEWORK_PATH", "")
            self.env["DYLD_FRAMEWORK_PATH"] = str(frameworks) + (os.pathsep + existing if existing else "")

    def command(self, args):
        remaining = self.deadline - self.now()
        if remaining <= 0:
            raise ResolutionError("Watch UI resolution timed out")
        try:
            result = self.run(args, capture_output=True, text=True, env=self.env,
                              timeout=min(10, remaining))
        except subprocess.TimeoutExpired as error:
            raise ResolutionError(f"Watch UI command timed out: {args[1]}") from error
        if result.returncode:
            raise ResolutionError(f"Watch UI command failed ({args[1]}): {result.stderr.strip()}")
        return result.stdout

    def capture(self):
        self.capture_number += 1
        raw = self.command([str(self.axe), "describe-ui", "--udid", self.udid])
        path = self.output / f"{self.capture_number:03d}-ui.json"
        path.write_text(raw)
        try:
            tree = json.loads(raw)
        except json.JSONDecodeError as error:
            raise ResolutionError(f"AXe returned invalid JSON; see {path.name}") from error
        return tree, hashlib.sha256(raw.encode()).hexdigest(), path.name

    def resolve(self):
        self.output.mkdir(parents=True, exist_ok=True)
        version = self.command([str(self.axe), "--version"]).strip()
        (self.output / "axe-version.txt").write_text(version + "\n")
        if version != "1.8.0":
            raise ResolutionError(f"Expected pinned AXe 1.8.0; got {version}")
        inventory = json.loads(self.command(["xcrun", "simctl", "list", "devices", "--json"]))
        device = validate_watch(inventory, self.udid)
        (self.output / "device.json").write_text(json.dumps(device, indent=2) + "\n")
        acted = set()
        pending_checkbox = None
        stable = 0
        while self.now() < self.deadline:
            tree, signature, filename = self.capture()
            observation = inspect_ui(tree, self.expected)
            if pending_checkbox:
                controls = [node for node in visible_nodes(tree) if
                            node.get("AXUniqueId") == pending_checkbox and node_role(node) == "checkbox"]
                if len(controls) == 1 and controls[0].get("AXValue") == "1":
                    observation["confirmed_checkbox"] = pending_checkbox
                    pending_checkbox = None
                else:
                    observation = {"state": "waiting-checkbox-confirmation",
                                   "checkbox": pending_checkbox, "labels": observation["labels"]}
            self.events.append({"capture": filename, **observation})
            (self.output / "events.json").write_text(json.dumps(self.events, indent=2) + "\n")
            if observation["state"] == "expected":
                stable += 1
                if stable >= 2:
                    return {"ok": True, "expected": self.expected, "captures": self.capture_number}
            else:
                stable = 0
            action = observation.get("action")
            if action and signature not in acted:
                if len(acted) >= 8:
                    raise ResolutionError("Too many Health UI transitions without reaching the expected screen")
                acted.add(signature)
                if action.get("gesture") == "swipe":
                    self.command([str(self.axe), "swipe", "--start-x", str(action["start_x"]),
                                  "--start-y", str(action["start_y"]), "--end-x", str(action["end_x"]),
                                  "--end-y", str(action["end_y"]), "--duration", "0.3", "--udid", self.udid])
                    self.events[-1]["swiped"] = action
                elif action.get("gesture") == "tap":
                    self.command([str(self.axe), "tap", "-x", str(action["x"]),
                                  "-y", str(action["y"]), "--udid", self.udid])
                    self.events[-1]["tapped"] = action
                    pending_checkbox = action.get("confirm_checkbox")
                else:
                    self.command([str(self.axe), "tap", "--label", action["label"],
                                  "--element-type", action["element_type"], "--udid", self.udid])
                    self.events[-1]["tapped"] = action
                (self.output / "events.json").write_text(json.dumps(self.events, indent=2) + "\n")
            self.sleep(min(0.5, max(0, self.deadline - self.now())))
        last = self.events[-1] if self.events else {}
        raise ResolutionError(f"Expected Watch screen did not appear or a permission dialog is unresolved: {last.get('labels', [])}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--expected-exercise", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--timeout", type=float, default=60)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    try:
        uuid.UUID(args.udid)
        if not 0 < args.timeout <= 90:
            raise ResolutionError("--timeout must be between 0 and 90 seconds")
        if not normalized(args.expected_exercise):
            raise ResolutionError("--expected-exercise cannot be empty")
        axe = os.environ.get("AXE_PATH", "")
        if not axe or not Path(axe).is_file() or not os.access(axe, os.X_OK):
            raise ResolutionError("AXE_PATH must point to the bundled axe executable from xcodebuildmcp@2.7.0")
        resolver = Resolver(axe, args.udid, args.expected_exercise, args.output_dir, args.timeout)
        result = resolver.resolve()
    except (ResolutionError, ValueError, OSError) as error:
        result = {"ok": False, "error": str(error)}
    (args.output_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
