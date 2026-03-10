# EGYM Training

## Short Introduction

EGYM Training is a Garmin Connect IQ strength app for guided machine-based workouts and manual free-flow strength sessions. It records each completed set as a FIT lap and stores additional strength data in FIT developer fields for later review.

## Main Features

- Guided upper-body and lower-body circuit workouts
- Custom circuit order from Garmin Connect settings
- Individual mode for free exercise selection
- RM-based target weight guidance with learned calibration
- Quality rating or watt tracking, depending on the active training method
- Session summary with total volume, average performance, method, and record highlights
- English and German user interface

## Typical Workout Workflow

1. Choose a program and start a circuit or free-flow workout.
2. Follow the current exercise, adjust the suggested weight if needed, and confirm the set.
3. Enter or rate performance where the method requires it.
4. Advance through the break phase to continue with the next set or exercise.
5. Save the workout to write the FIT activity and the final summary fields.

## Data Recorded

- Every completed set is written as a lap in the saved FIT activity.
- Lap developer fields store reps, weight, performance, workload, and exercise name.
- Session developer fields store total session load, average performance, program name, training method, and record summary.
- Standard Garmin activity metadata is recorded through the Connect IQ ActivityRecording session.

## Device Compatibility

Current manifest support:

- Forerunner: `fr255`, `fr265`, `fr955`, `fr965`, `fr970`
- Epix: `epix2`, `epix2pro42mm`, `epix2pro47mm`, `epix2pro51mm`
- Fenix 7 / 8: `fenix7`, `fenix7pro`, `fenix7s`, `fenix7spro`, `fenix7x`, `fenix7xpro`, `fenix843mm`, `fenix847mm`, `fenix8pro47mm`, `fenix8solar47mm`, `fenix8solar51mm`
- Instinct 3: `instinct3amoled45mm`, `instinct3amoled50mm`, `instinct3solar45mm`
- Venu / Vivoactive: `venu3`, `venu3s`, `vivoactive5`, `vivoactive6`

## Notes / Limitations

- The app is designed for manual workout logging on the watch. It does not connect directly to EGYM gym machines.
- RM and watt reference values are maintained through the app and Garmin Connect settings workflow.
- The app is not affiliated with or endorsed by EGYM GmbH.
