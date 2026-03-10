# EGYM Training for Garmin

EGYM Training is a Garmin Connect IQ watch app for guided strength-machine workouts and manual free-flow strength logging. It helps you run EGYM-style circuits from the wrist, records each completed set into the FIT activity, and stores strength-specific workout details in FIT developer fields.

Store: [Garmin Connect IQ Store](https://apps.garmin.com/)
License: [See License Notes](#license)

## Overview

The app is built for structured strength sessions on modern Garmin devices. It supports classic upper-body and lower-body circuits, custom machine orders, individual exercise selection, RM-based target weight guidance, watt/performance tracking, and post-workout summaries.

## Key Features

- Guided circuit and free-flow strength workouts on the watch
- RM-based target weight calculation with learned per-exercise calibration
- Support for EGYM basic programs and EGYM+ style program families
- Per-set FIT recording with lap markers and strength-specific developer fields
- Session summary data for total volume, average performance, method, and record highlights
- Resume checkpoint flow for interrupted workouts
- English and German localization

## Usage Overview

1. Choose a program and a workout mode from the start menu.
2. Follow the active exercise, adjust weight if needed, and confirm the set.
3. Enter or rate performance when the workout method requires it.
4. Advance through the break phase to start the next set or next exercise.
5. Save the session to write the FIT activity and the final session summary.

## Supported Device Families

Current manifest support covers the following product lines:

- Forerunner: `fr255`, `fr265`, `fr955`, `fr965`, `fr970`
- Epix: `epix2`, `epix2pro42mm`, `epix2pro47mm`, `epix2pro51mm`
- Fenix 7 / 8: `fenix7`, `fenix7pro`, `fenix7s`, `fenix7spro`, `fenix7x`, `fenix7xpro`, `fenix843mm`, `fenix847mm`, `fenix8pro47mm`, `fenix8solar47mm`, `fenix8solar51mm`
- Instinct 3: `instinct3amoled45mm`, `instinct3amoled50mm`, `instinct3solar45mm`
- Venu / Vivoactive: `venu3`, `venu3s`, `vivoactive5`, `vivoactive6`

## Documentation

- [Architecture](ARCHITECTURE.md)
- [Testing](TESTING.md)
- [Changelog](CHANGELOG.md)
- [Garmin Store Description (EN)](GARMIN_STORE_DESCRIPTION_EN.md)
- [Garmin Store Description (DE)](GARMIN_STORE_DESCRIPTION_DE.md)

## License

This repository currently does not include a standalone license file. Until one is added, reuse terms are not documented here.

## Notes

- The app is not affiliated with or endorsed by EGYM GmbH.
- Garmin Connect rendering can differ between platforms; use the FIT validation workflow in [TESTING.md](TESTING.md) when checking saved lap and developer-field data.
