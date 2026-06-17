# ADR 0005: Maintain Separate Dev and Production App Targets

## Context

The Xcode project defines two targets and two shared schemes:

- `TTS`
- `TTS Prod`

Production builds define `PRODUCTION`, use a different plist, and enforce the auth gate. Non-production builds bypass auth gating in `AuthGateView`.

## Decision

Keep separate development and production targets, with compile-time behavior differences controlled by the `PRODUCTION` flag and target-specific build settings.

## Consequences

- Development can move faster when auth is bypassed locally.
- Production can enforce stricter entry behavior.
- Behavior divergence between targets increases QA risk.
- Future changes that affect auth or startup must be checked against both targets.
