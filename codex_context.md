# codex_context.md — Garmin Connect IQ App (eGym / Training Logger)

## Project
Garmin Connect IQ app to log/assist strength training (eGym round / Zirkel).
Goal: quick input, robust on different devices, avoid crashes on older models.

## Language / SDK
- Monkey C, Connect IQ SDK
- Target devices include older models (e.g., fenix 5) and newer (e.g., Forerunner 955)

## Compatibility Constraints
- Avoid APIs missing on older devices (e.g., some String methods like compareTo may not exist everywhere).
- Prefer safe comparisons and utility methods that are broadly supported.
- Memory/CPU constraints: keep views lightweight.

## Architecture
- Delegate/controller: navigation and app state
- Views: rendering + input handlers only
- Model: session records, parsing, persistence
- Storage keys:
  - Keep a documented list of keys (single source of truth)
  - Provide migration if keys change

## Data Handling
- Defensive programming around nulls and missing properties
- Persist minimal state required for "resume"
- Prefer arrays of simple maps/records; avoid deep object graphs

## UI
- Fast navigation, big touch targets where applicable
- Avoid heavy redraw; cache computed values between onUpdate calls

## Implementation Expectations for Codex
- Return FULL updated files
- Always note device compatibility implications
- Provide fallback for missing APIs (e.g., string compare without compareTo)

## Quality Gates
- No crash on older devices (fenix 5)
- Storage reads/writes are consistent and keyed
- Scroll logic bounds-checked (no negative index / overflow)