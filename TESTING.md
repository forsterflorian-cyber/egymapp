# Testing

## Prerequisites

- Garmin Connect IQ SDK with `monkeyc` on `PATH`
- A valid developer key, either through `CIQ_DEVELOPER_KEY` or `C:\Users\forst\developer_key`
- The project root as the working directory

## Build Instructions

Representative compile matrix:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compile-matrix.ps1
```

Unit-test build compilation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compile-tests.ps1
```

Full release gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\release-gate.ps1
```

## compile-matrix Usage

The default compile matrix checks a representative set of supported devices:

- `epix2`
- `fr255`
- `fr955`
- `fenix847mm`
- `fenix8solar51mm`
- `instinct3solar45mm`
- `venu3`
- `vivoactive6`

Use `-Devices` to override the target list if you need a narrower or broader smoke pass.

## release-gate Usage

`release-gate.ps1` compiles the full supported device list and also performs a test build on the configured test device.

Behavior:

- fails on any compile error
- fails on any warning outside the allowlist
- currently allows launcher-icon scaling warnings only

Run `release-gate.ps1 -SkipTests` when you only want the product build gate.

## FIT Validation Workflow

There is no separate FIT validator script in this repository. FIT validation is a manual workflow built around short real or simulator workouts.

Recommended workflow:

1. Build and install the app on a supported device or simulator.
2. Record a short workout with at least two completed sets and save it normally.
3. Sync the activity and inspect the result in Garmin Connect.
4. Confirm that completed sets were written as laps.
5. Confirm that the lap developer fields contain the expected numeric values for reps, weight, performance, and workload.
6. Confirm that session developer fields contain the saved workout summary, including total volume, program, average performance, method, and record summary.

When investigating lap or developer-field issues, compare the expected set count with the rendered lap count. If Garmin Connect platform views disagree, validate the saved activity through the exported FIT file to separate app-side recording issues from Garmin Connect rendering differences.

## Manual Release Checklist

Before a release candidate is accepted:

- build succeeds with no new compile errors
- the app launches on a supported device or simulator
- save and discard flows behave correctly
- stats and record summaries update after save
- English and German strings render correctly
- key and gesture navigation work across the active workout phases
- at least one AMOLED model and one MIP model receive a visual smoke test
