# ADR 0003: Persist Different Content States with Multiple Local Stores

## Context

The app persists multiple categories of state:

- local recent activities in programmatic Core Data
- backend chunk metadata in a separate programmatic Core Data store
- online library metadata in a JSON file under Documents
- auth tokens in Keychain
- profile display details in `UserDefaults`

## Decision

Use purpose-specific local stores instead of one unified persistence layer.

## Consequences

- Each subsystem can evolve independently with simple local ownership.
- The app can restore local and online playback state across launches.
- Data flow is harder to reason about because related document state spans several stores and file locations.
- Migration, cleanup, and debugging are more complex.
