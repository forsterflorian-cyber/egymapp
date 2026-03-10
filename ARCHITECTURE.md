# Architecture

## Overview

The EGYM Garmin app is organized around a workout view, a recording/session manager, a workout calculation engine, and persistent storage helpers.

- `EGYMView` owns workout state, set completion, round progression, and save or discard decisions.
- `EGYMSessionManager` owns the `Toybox.ActivityRecording.Session` lifecycle and all FIT developer-field interaction.
- `EGYMWorkoutEngine` calculates reps, workload, learned factors, and session totals.
- `EGYMSafeStore` persists settings, checkpoints, learned calibration, and session-related state that must survive app restarts.

## ActivityRecording Lifecycle

`EGYMSessionManager.createAndStart()` creates the recording session, sets up FIT developer fields, and starts the Garmin `ActivityRecording.Session`.

The session creation path uses a compatibility-first fallback chain:

1. `SPORT_GENERIC` with `SUB_SPORT_STRENGTH_TRAINING`
2. `SPORT_HIIT` with `SUB_SPORT_HIIT`
3. `SPORT_HIIT`
4. `SPORT_GENERIC` with `SUB_SPORT_GENERIC`

If field creation fails, the session still attempts to start so the workout can continue without custom FIT fields.

## Session Start, Stop, and Save

At workout start:

1. The active program or restored checkpoint calls `createAndStart()`.
2. The session manager creates lap and session developer fields.
3. Initial zero or empty values are written so the FIT field definitions are present from the beginning of the activity.
4. `session.start()` begins the recording.

At workout end:

1. `EGYMView.forceEndZirkel()` or `EGYMView.emergencyStopAndSave()` calls `EGYMSessionManager.stopAndSave(...)`.
2. Session-level developer fields are populated with total volume, average performance, program name, method, and record summary.
3. If the current set has not yet been flushed into a lap, a final `addLap()` is attempted.
4. The session is stopped and then saved.

Discard paths call `cleanup()` or `discard()` and do not save a FIT file.

## Lap Creation Per Set

Each completed set is processed in `EGYMView.processEndOfSet()`. The workout engine calculates reps and workload, and the view then calls `writeLapData(...)` with the current exercise and set values.

`writeLapData(...)` only updates the current lap-field buffer. The actual lap boundary is created later when the workout advances:

- leaving the break phase for the next exercise
- accepting another round
- confirming the next exercise in individual mode
- final save, if there is still unflushed set data

This design keeps one completed set per saved lap.

## Developer Fields

The app uses Garmin FIT developer fields defined in `resources/resources.xml`.

Lap-level fields:

- `0`: reps
- `1`: weight
- `2`: performance
- `3`: workload
- `5`: exercise name

Session-level fields:

- `4`: total session load
- `6`: average performance
- `7`: program name
- `8`: watt record summary
- `9`: method name

Lap fields describe a single completed set. Session fields describe the saved workout as a whole.

## High-Level Data Flow

1. The user selects a workout mode and program.
2. `EGYMView` starts a recording session through `EGYMSessionManager`.
3. The workout engine calculates target weight, reps, workload, and running totals for each set.
4. Completed-set data is written into lap developer fields.
5. Phase transitions call `addLap()` so each set becomes a saved FIT lap.
6. End-of-session logic writes summary developer fields, flushes any final pending lap, then stops and saves the session.
7. Saved data is available through standard Garmin activity storage plus the app-specific FIT developer fields.

## Persistence and Recovery

The app stores minimal recovery state so an interrupted workout can be resumed. Checkpoints preserve enough view and session context to restart the workout flow and continue from the saved state without rebuilding the whole session model by hand.
