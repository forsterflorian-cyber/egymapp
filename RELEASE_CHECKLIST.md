# EGYM App Release Checklist

## Build Gate
1. Build succeeds with no new errors.
2. App launches on at least one simulator/device.
3. No obvious UI regressions on start screen.
4. Run matrix compile command:
   `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compile-matrix.ps1`
5. Unit-test build compiles:
   `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compile-tests.ps1`
6. Release gate passes (fails on any non-allowed warning):
   `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\release-gate.ps1`

## Compile Matrix (Codex)
1. Run compile checks on:
   `epix2` (baseline AMOLED touch),
   `fenix6` (legacy MIP/button-first),
   `fr955` (Forerunner 955),
   `fenix847mm` and `fenix8solar51mm` (latest Fenix family).
2. If one target fails, record the device id and the exact compiler error before fixing.
3. Workspace analyzer is locked to compiler2 lookup rules to avoid compiler1-vs-compiler2 noise.
4. Warning policy: launcher icon scaling is currently the only allowed warning class.

## Core Flow Gate
1. Start normal workout, complete at least one set, save session.
2. Start workout, discard session, verify it does not count as saved.
3. Test mode flow works (weight picker opens, save/cancel both behave).
4. Individual mode flow works (pick exercise, continue, finish).

## Data Gate
1. Session stats update after save:
   sessions, total volume, streak.
2. Exercise records update for RM and W where expected.
3. Records text in FIT session field uses current app language labels.
4. Settings sync does not wipe or corrupt stored exercise values.
5. Storage migration sanity:
   old installs still launch,
   defaults are repaired when values are invalid,
   no loss of existing stats/custom circle.

## Localization Gate
1. English:
   start menu labels, exercise names, records strings are English/default.
2. German:
   start menu labels, exercise names, records strings are German.

## Navigation Gate
1. Hardware keys:
   UP/DOWN/ENTER/ESC behave correctly in all workout phases.
2. Gestures:
   swipe up/down/left/right behavior is correct and does not leak to system.
3. Back/close behavior:
   no stuck overlays or orphaned views.

## UI Smoke Gate
1. Open `Stats` and press `Select/OK` to cycle filters:
   `All -> RM -> Watt -> All`.
2. Confirm after each filter change:
   list redraws,
   scroll still works,
   no stale or mismatched rows.
3. Open `Diagnostics` and confirm:
   schema/program/circle lines populate,
   error counters render,
   layout does not overlap.
4. Press `OK` on `Diagnostics` to reset counters.
5. Confirm the screen stays responsive and counter values remain valid after reset.

## Device Coverage Gate
1. Test at least:
   one AMOLED touch model,
   one MIP/button-first model.
2. Confirm layout:
   no clipped critical text in workout and stats screens.

## Debug Gate (Optional)
1. Launch once and inspect logs for startup sanity validator findings:
   missing exercise mappings,
   missing property keys,
   duplicate cleaned keys.

## Release Decision
1. No high/medium issues open.
2. All checklist items pass.
3. Version/changelog updated.



