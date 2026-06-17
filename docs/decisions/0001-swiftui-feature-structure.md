# ADR 0001: SwiftUI Feature-Oriented App Structure

## Context

The repository is organized around a single iOS application target with folders such as `Features`, `Core`, `Shared`, and `App`. UI code is predominantly SwiftUI, with focused UIKit bridges only where platform APIs require them.

## Decision

Use a feature-oriented SwiftUI structure:

- `App` for startup and app delegate concerns
- `Features` for end-user flows
- `Core` for reusable domain, service, and platform logic
- `Shared` for common UI and utilities

## Consequences

- Feature discovery is easier for onboarding and AI agents.
- Shared state remains accessible through environment objects and singleton services.
- Architectural boundaries are pragmatic rather than strictly layered.
- Without stronger module boundaries, cross-feature coupling remains possible.
