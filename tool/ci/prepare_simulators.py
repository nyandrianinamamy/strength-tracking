#!/usr/bin/env python3
"""Create isolated simulators, or validate an explicitly supplied test pair."""
import argparse
import json
import os
from pathlib import Path
import subprocess


def simctl(*args):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True).strip()


def cleanup(manifest):
    for device in reversed(manifest.get("owned", [])):
        subprocess.run(["xcrun", "simctl", "shutdown", device], capture_output=True)
        subprocess.run(["xcrun", "simctl", "delete", device], capture_output=True)


def choose_runtime(runtimes, platform, override):
    candidates = [r for r in runtimes if r.get("isAvailable") and
                  r["identifier"].startswith(f"com.apple.CoreSimulator.SimRuntime.{platform}-")]
    if override:
        candidates = [r for r in candidates if r["identifier"] == override]
    if not candidates:
        raise ValueError(f"No available {platform} runtime; install it in Xcode first")
    return max(candidates, key=lambda r: tuple(map(int, r["version"].split("."))))


def choose_type(runtime, preferred, family, all_types):
    candidates = [d for d in runtime.get("supportedDeviceTypes", all_types)
                  if d.get("productFamily") == family or d["identifier"] == preferred]
    if preferred:
        candidates = [d for d in candidates if d["identifier"] == preferred]
    if not candidates:
        raise ValueError(f"No compatible {family} device type for {runtime['identifier']}")
    return candidates[0]["identifier"]


def prepare(paired):
    phone = os.environ.get("IOS_E2E_SIMULATOR_UDID", "")
    watch = os.environ.get("WATCH_SIMULATOR_UDID", "") if paired else ""
    manifest = {"phone": phone, "watch": watch, "owned": []}
    if paired and bool(phone) != bool(watch):
        raise ValueError("Supply both phone and Watch UDIDs, or neither for a disposable pair")
    if phone:
        groups = json.loads(simctl("list", "devices", "available", "--json"))["devices"].values()
        available = {d["udid"] for group in groups for d in group}
        if phone not in available or (paired and watch not in available):
            raise ValueError("Explicit UDIDs must identify available simulators")
        if paired:
            pairs = json.loads(simctl("list", "pairs", "--json"))["pairs"].values()
            if not any(p.get("phone", {}).get("udid") == phone and p.get("watch", {}).get("udid") == watch for p in pairs):
                raise ValueError("The supplied simulators are not paired")
        return manifest
    runtimes = json.loads(simctl("list", "runtimes", "--json"))["runtimes"]
    types = json.loads(simctl("list", "devicetypes", "--json"))["devicetypes"]
    try:
        for platform, family, key, env in [("iOS", "iPhone", "phone", "IOS"), ("watchOS", "Apple Watch", "watch", "WATCH")]:
            if key == "watch" and not paired:
                continue
            runtime = choose_runtime(runtimes, platform, os.environ.get(f"{env}_E2E_RUNTIME"))
            device_type = choose_type(runtime, os.environ.get(f"{env}_E2E_DEVICE_TYPE"), family, types)
            manifest[key] = simctl("create", f"Kotrana E2E {key} {os.getpid()}", device_type, runtime["identifier"])
            manifest["owned"].append(manifest[key])
        if paired:
            manifest["pair"] = simctl("pair", manifest["watch"], manifest["phone"])
        return manifest
    except BaseException:
        cleanup(manifest)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--paired-watch", action="store_true")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--cleanup", type=Path)
    args = parser.parse_args()
    if args.cleanup:
        if args.cleanup.exists():
            cleanup(json.loads(args.cleanup.read_text()))
        return
    if not args.output:
        parser.error("--output is required")
    manifest = prepare(args.paired_watch)
    try:
        args.output.write_text(json.dumps(manifest, indent=2) + "\n")
    except BaseException:
        cleanup(manifest)
        raise


if __name__ == "__main__":
    main()
