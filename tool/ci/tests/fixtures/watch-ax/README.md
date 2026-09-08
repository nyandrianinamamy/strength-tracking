# Watch accessibility fixtures

Captured with AXe 1.8.0 on the disposable watchOS 26.2 simulator used for the
8 September 2026 implementation run. Source captures:
`build/implementation-evidence/watch-ax/timed-workout.json` and `idle.json`.

These fixtures retain the actual hierarchy, roles, labels, frames, enabled
flags and identifiers. Runtime process IDs and unused/null metadata were
removed. They validate parsing of a real 208 x 248 Watch display and visible
English timed-workout/French idle text. The timed/idle fixtures contain no authorization sheet.

`watch-write-access.json` and `watch-write-access-scrolled.json` were captured
from the actual fresh Health Write Access form, in
`build/implementation-evidence/paired-final/`. They preserve the unchecked
Workouts values and the observed GenericElement Done control. Tests derive
synthetic checked-state variants without changing those source captures.
These fixtures do not prove successful HealthKit authorization.

The helper runs only against the supplied booted, disposable Watch simulator.
For the current native request, which contains only Workouts write access, it
taps the fully visible Workouts checkbox, or All Requested Data Below on the
captured top form. Every toggle requires a fresh AX capture confirming value
`1` before any further action. It then checks the specific Workouts checkbox
value before tapping Done. Controls beneath the fixed Write Access header
are scrolled into view before tapping; no hidden or offscreen control is
tapped. Unknown permission requests fail. No permission database or preference
is modified directly. The paired driver separately checks the native Health
authorization result; the helper does not infer it from closing the sheet.

AXe 1.8.0's semantic tap on the Health GenericElement Done resolved to the
clock at (175, 16) during the live run. Tapping the center of its observed
frame dismissed the form, captured in
`build/implementation-evidence/paired-final/watch-after-coordinate-done.json`.
The helper therefore derives that control's coordinates from each fresh AX
frame after validating the Health identity, enabled state, and visibility.
The Review button retains its semantic tap. This delayed manual dismissal
does not establish a Health authorization outcome for an active workout.
