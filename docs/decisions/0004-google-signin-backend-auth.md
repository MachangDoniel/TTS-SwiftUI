# ADR 0004: Authenticate with Google Sign-In and Backend Tokens

## Context

The client integrates Google Sign-In, then exchanges the Google ID token with a backend auth API for app-specific access and refresh tokens. Tokens are stored in Keychain and refreshed through the network layer.

## Decision

Use Google Sign-In as the identity provider and backend-issued tokens as the session mechanism for the app.

## Consequences

- The client avoids handling password-based auth directly.
- Session control remains with the backend through access/refresh tokens.
- Auth behavior depends on correct coordination between Google SDK state, backend token state, and Keychain persistence.
- Authentication bugs can span SDK integration, networking, and local persistence.
