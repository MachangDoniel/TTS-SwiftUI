# Workflow

## Purpose

This workflow is for AI agents and engineers working in this repository. It is intentionally grounded in the repo's current maturity: no automated tests, no CI, and meaningful reliance on external backend services.

## Development Workflow

### 1. Requirement Analysis
- Read `AI_AGENT.md` first.
- Confirm whether the task affects local TTS, backend TTS, auth, persistence, or UI routing.
- Inspect the relevant feature, core service, and shared UI files before changing code.
- Separate evidence from assumption. If the repo does not prove a requirement, label it as an inference.

### 2. Planning
- Identify impacted targets: `TTS`, `TTS Prod`, or both.
- Identify whether the change touches persisted data, backend contracts, or auth/session logic.
- For non-trivial changes, decide whether `ARCHITECTURE.md`, `CURRENT_STATE.md`, or ADRs also need updates.

### 3. Architecture Review
- Check whether the change should plug into existing structures:
  - `TTSPlayer` for playback
  - `APIClient` / `APIEndpoints` for networking
  - `RecentStore`, `BackendChunkStore`, `OnlineLibraryStore` for persistence
  - Feature-folder organization for UI
- Avoid introducing competing state containers or alternate networking stacks without a documented reason.

### 4. Implementation
- Keep UI logic in feature views/components unless it clearly belongs in a service or view model.
- Keep external integrations behind service/constant layers.
- Preserve current behavior differences between dev and production builds unless the task explicitly changes them.
- Preserve security-scoped file handling for user-selected documents.

### 5. Testing and Validation
- Prefer targeted validation over broad unverified claims.
- At minimum, validate impacted flows manually.
- If build/test commands cannot run in the current environment, say so explicitly.
- For backend-dependent features, distinguish:
  - verified locally in code or UI logic
  - unverified because backend/network access was unavailable

### 6. Documentation
- Update project docs when architecture, workflows, constraints, or known risks change.
- Add or revise ADRs for major technical decisions.
- Record new uncertainties rather than silently assuming answers.

### 7. Completion
- Summarize what changed.
- Summarize what was verified.
- Summarize what remains uncertain or untested.

## Task Checklist

Before completing any task, confirm all applicable items below:

- I read the relevant feature/core/shared files before editing.
- I checked whether both app targets are affected.
- I preserved `TTSPlayer` as the playback source of truth.
- I used existing networking and persistence layers where applicable.
- I considered dev-vs-production auth behavior.
- I considered bookmark/security-scoped file access if files are involved.
- I updated documentation if the architecture or workflow changed.
- I recorded manual verification steps or stated why verification could not be completed.
- I called out backend, persistence, or auth risks explicitly.

## Change-Type Guidance

### Auth changes
- Inspect `AuthGateView`, `AuthViewModel`, `GoogleAuthViewModel`, `APIClient`, and the auth endpoints.
- Verify token persistence and logout/refresh implications.

### Playback changes
- Inspect `TTSPlayer`, `FullPlayerView`, and the relevant reader/viewer flow.
- Verify both system voice mode and backend voice mode when applicable.

### Input-source changes
- Inspect `HomeView`, `TabBarView`, and the relevant reader/import view.
- Verify recents persistence and reopen behavior.

### Persistence changes
- Inspect `RecentStore`, `BackendChunkStore`, and `OnlineLibraryStore`.
- Document migration impact if persisted formats or locations change.

### Backend TTS changes
- Inspect `TTSBackendService`, `PublicTTSJobService`, `APIEndpoints`, and online library models.
- Verify how request IDs, chunk metadata, transcript persistence, and audio restoration are affected.
