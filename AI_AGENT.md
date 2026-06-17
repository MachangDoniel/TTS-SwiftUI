# AI Agent Instructions

## Read This First

Before making changes, read:

1. `AI_CONTEXT.md`
2. `ARCHITECTURE.md`
3. `WORKFLOW.md`
4. `CURRENT_STATE.md`
5. Relevant ADRs under `docs/decisions/`

## Project Mission

### Facts
- This is an iOS SwiftUI text-to-speech app.
- It accepts text from typed input, files, PDFs, images, camera capture, and web pages.
- It supports both on-device speech and backend-generated speech.

### Inference
- The product mission appears to be making mixed-format reading content easy to consume as audio.

## Development Principles

- Prefer repository evidence over speculation.
- Preserve existing feature-folder organization.
- Preserve `TTSPlayer` as the playback source of truth.
- Preserve the existing networking stack built around `APIClient` and `APIEndpoints`.
- Preserve current persistence layers unless the task explicitly changes them.
- Mark assumptions clearly when the repo does not prove a requirement.

## Architectural Constraints

- Two app targets exist: `TTS` and `TTS Prod`.
- Auth behavior differs by compile-time configuration.
- Backend voice generation depends on external services not present in this repo.
- External file access depends on security-scoped bookmarks.
- Online-library playback depends on persisted backend metadata and cached/generated files.

## Workflow Requirements

- Inspect relevant code before editing.
- Consider both local and backend TTS implications when changing playback-related code.
- Consider recents/bookmarks/persistence implications when changing file flows.
- Update docs and ADRs when architecture or project constraints materially change.
- State verification limits explicitly if the current environment prevents builds/tests.

## Coding Expectations

- Use SwiftUI for UI unless bridging to UIKit/AppKit is already required.
- Keep new code in the current folder structure.
- Prefer async/await for new asynchronous work.
- Log operational failures with useful context.
- Avoid introducing new global state containers unless there is a strong reason and it is documented.

## Current Hotspots

- `TTS/Core/TTS/Player/TTSPlayer.swift`
  - Central playback state machine and major coupling point
- `TTS/Core/Services/TTSBackendService.swift`
  - Remote generation orchestration
- `TTS/Core/Services/PublicTTSJobService.swift`
  - Backend API integration
- `TTS/Core/Models/RecentStore.swift`
  - Bookmark handling and Core Data persistence
- `TTS/Features/App Entry/Views/TabBarView.swift`
  - Main routing and modal orchestration

## Things To Be Careful About

- Non-production builds bypass the auth gate.
- There are no automated tests or CI protections.
- The backend TTS host uses a raw HTTP endpoint with ATS exception handling.
- Some UI paths are stubbed, placeholder, or partially implemented.

## When to Add an ADR

Add or update an ADR when you change:

- the speech architecture
- authentication strategy
- persistence format/location
- app target/environment strategy
- external service integration boundaries
