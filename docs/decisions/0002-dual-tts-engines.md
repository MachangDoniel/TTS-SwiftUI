# ADR 0002: Support Both System TTS and Backend TTS

## Context

The app contains both:

- system speech playback through `AVSpeechSynthesizer`
- remote speech generation and chunked audio playback through backend job APIs

The UI exposes voice selection, backend transcript display, online library restoration, and playback controls that operate across both modes.

## Decision

Keep a dual-engine speech architecture with `TTSPlayer` coordinating:

- local sentence-based speech for system voices
- backend-generated audio for remote voices

## Consequences

- Users can access free on-device voices and richer remote voices in one product.
- The playback state machine is more complex because it spans multiple execution paths.
- Feature work touching playback must account for both modes.
- Testing requirements increase because regressions can be mode-specific.
