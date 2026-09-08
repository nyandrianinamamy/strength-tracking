# iOS and Watch implementation record

Implemented on 8 September 2026. Baseline: `v1.0.31+309` / `e288c4984dc4ea9fe36468cd37fed64bdde42f47`. Branch: `codex/testflight-309-ios-watch-review`. Release candidate: `v1.0.31+310`, authorized for commit and TestFlight tagging after local verification. No production access data was mutated during local testing.

## Implementation

- **A1–A4, M1–M3:** account-bound repositories, durable per-account cache/outbox, three-way reconciliation and visible recovery controls; nullable Firebase fallback; verified invitation gating; reauthentication before account deletion; per-account training/Health state. Offline edits and prior-account recovery copies are retained.
- **D1–D7:** preserve typed timed-workout effort during replay; prevent duplicate swaps; disable unsupported app supersets; recompute planner duration and expose infeasible limits; rank PRs from each historical set with shared valid RPE fallback; exclude archived defaults; fingerprint relevant history/metadata. Planner work is cancelled/reset across account transitions.
- **N1–N5, M4:** identity/revision-scoped Watch updates and completion, reinstall handshake, authoritative idle, phone-driven paging with explicit manual-selection behavior, serialized Live Activities, cancellable rest work and post-permission deadline checks, French/English labels and one shared Activity attributes source. Optional Health denial leaves Watch display usable.
- **Cleanup:** Flutter web entry point, browser wrappers/runner, unused direct dependencies, tracked build caches, obsolete design exports and SideStore listing removed. Static privacy/terms/support pages preserve public routes. Lexend is bundled for offline startup. Tested package APIs are retained with their scope documented.
- **Tests and release gate:** strict native UI, emulator identity/bootstrap, real process restart, native Activity state and paired Watch cache/accessibility assertions. PR and release checks share pinned Flutter/Xcode settings; upload depends on checks for the resolved source SHA.

## Findings from implementation review

Additional regressions exposed and repaired:

- Library clearing deleted history despite its confirmation text; it now archives referenced definitions and retains sessions.
- An old recovery request could mutate a newly bound account; the captured repository/generation now fences its result.
- Account state could publish before its engine repository; ownership bindings are staged together.
- Cached planner output could survive an account transition; pending generation is fenced and the preview resets.
- Reconnect updated providers without refreshing onboarding/navigation; visible profile setup and home routing now update.
- Settings disposed credential controllers before dialog reverse transitions completed; TextFields now own their controller lifetime. Submit and cancel both have regression tests.
- Recovery could lock users out after conflict/capacity failures, and old repositories could overwrite a reopened account's outbox. Account-scoped storage ownership, serialized writes, retirement on deletion, and fresh online admission checks now have regressions.
- Apple sign-in omitted the nonce and supplied the authorization code as an access token. Sign-in and reauthentication now share secure nonce/ID-token handling, validate missing credentials, and normalize cancellation. Ten boundary tests cover these paths. This does not establish the cause or resolution of the earlier physical-iPad App Review rejection.
- Repeated phone requests to launch the Watch could dismiss its Health permission sheet. Launches are now limited per active session and skipped when the Watch is reachable. A successful Health authorization callback could also precede the actual authorization-state update; bounded rechecks handle that delay without assuming approval.
- iPad execution exposed fixed-height metric-card overflows, a long profile-name overflow, and a finish-confirmation sheet that did not fit above the keyboard. Content-sized cards, a constrained profile header, and a scrolling keyboard-aware sheet retain all content and actions. Text-scale and short-viewport widget regressions cover the repairs.
- First-party privacy manifests now declare preferences access and the app's actual collection categories. Health usage text matches the current behavior: the Watch starts an HKWorkoutSession but does not save/export workouts.
- Ordinary release archives left Watch and Live Activity versions at `1.0 (1)`. Both now inherit Flutter's version/build through a shared companion configuration. Fastlane passes optional version overrides as build settings, preserving source plist placeholders instead of rewriting them with `agvtool`.

## Verification

Evidence lives under `build/implementation-evidence/`. The final native runner exited successfully with all seven suites passing, and the unsigned release archive passed inspection. Earlier failures remain available as diagnostic evidence and are not counted as current passes.

| Check | Latest result |
| --- | --- |
| Static analysis | Clean on Flutter 3.41.9 (`analyze-final.log`) |
| App unit/widget suite | 314 passed after the final metadata regressions (`app-tests-final.log`) |
| Training engine | 489 passed |
| Focused final planner/progress/training checks | 136 passed |
| Native Swift logic | 13 passed, including Watch launch and delayed Health authorization regressions |
| Focused Watch/Activity Dart checks | 20 passed |
| Heatmap | 2 exact goldens passed on Flutter 3.41.9 |
| Watch AX helper | 26 tests passed; fresh Watch accepted Workouts access through the real permission UI, then native status was granted (`2`) with pending false |
| Static legal/link tests | 6 passed; standalone route verifier passed |
| Settings credential dialog regression | Baseline crash reproduced, then all 4 submit/cancel paths passed |
| Reconnect onboarding | Baseline missing Next reproduced; all 4 onboarding tests passed after repair |
| Release metadata | All 8 focused tests passed; companion configuration bindings, source placeholders and Fastlane version overrides checked |
| iPad UI | All 11 passed (`ipad-acceptance/results.tsv`); strict selectors require a unique hittable control |
| iPhone UI | All 11 passed (`acceptance-final/app-ui.log`) |
| Native channel/ActivityKit | Both tests passed (`acceptance-final/native-wiring.log`) |
| Invitation/authentication | All 9 passed against demo emulators (`acceptance-final/invite-auth.log`) |
| Real app startup | Both tests passed, including restored guest startup after an injected Firebase failure (`acceptance-final/startup.log`) |
| Firestore rules | All 10 passed against demo emulators (`acceptance-final/firestore-rules.log`) |
| Terminated-process persistence | Write and read phases passed; the host confirmed the app was stopped between them (`acceptance-final/persistence-restart.log`) |
| Paired Watch | Both transport and joined real-main UI → Watch/Activity → durable-save scenarios passed (`acceptance-final/paired-watch.log`), including fresh permission UI, rapid session replacement, visible 80 kg × 6 and settled idle |
| Release archive | Built and inspected successfully; Runner, Watch and Live Activity all report `1.0.31 (309)` (`release-archive-final.log`, `release-archive-inspection.json`) |

The complete command was `tool/ci/run_ios_e2e.sh --with-auth --paired-watch`. Its `acceptance-final/results.tsv`, toolchain records and SHA-256 source manifest identify the run. The iPad used the same checked-in runner with `--ui-only`, in the app's existing iPhone-compatible mode. The production Firebase plist was restored byte-for-byte, and the automatically owned simulators were deleted on exit. The subsequent version-only configuration repair is covered by focused metadata tests and the confirming release archive; app/runtime sources did not change after native acceptance.

The heatmap reference update changed 468 caption-edge pixels per image after visual comparison; body drawing pixels were identical. Tests use Ahem at 800×600/1× with no tolerance or skips. Original references/diffs remain in the ignored evidence directory.

Archive inspection confirmed device binaries and minimum versions (iOS 15, Watch 10, Live Activity 16.2), the production `myappv4` Firebase configuration, source-matching Runner/Watch privacy manifests, all nine bundled Lexend fonts, and exclusion of the DEBUG workout observer. The archive is unsigned; no IPA was exported or uploaded.

## Limits before distribution

The cloud document remains compatible with installed TestFlight clients. The 900 KiB safety limit keeps oversized state durable locally and exposes a capacity-specific recovery message. Removing photos and retrying is tested; a storage split requires a versioned migration.

Local native validation uses Flutter 3.41.9 and Xcode 27 beta because Xcode 26.3 is not installed here. The checked-in GitHub workflow pins Xcode 26.3; it has not run remotely. Physical-device login, Bluetooth/background behavior, HealthKit authorization/readings, notifications/haptics, accessibility and Lock Screen/Dynamic Island acceptance remain release checks. The Watch uses an HKWorkoutSession but has no saved-workout export implementation.

The new joined scenario launches the real app with an explicit Firebase-initialization failure, starts a routine through the UI, logs a strength set, verifies the paired Watch display and actual ActivityKit set-count update, finishes through the UI, and reloads the durable guest envelope. Separate emulator scenarios cover authenticated bootstrap and account ownership. Neither replaces a real Apple/Google provider login.

Historical tagged-source failures and the independent Fable review remain in the approved plan and original reports; they are not current pass/fail results.
