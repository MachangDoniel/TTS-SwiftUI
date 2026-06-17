# Project Rules

## Scope

These rules are based on repository evidence. They document existing conventions already used by this codebase; they are not intended to introduce a new engineering style.

## Coding Standards

### Facts from the repo
- SwiftUI is the primary UI framework.
- Files are organized by feature and then by role such as `Views`, `ViewModels`, `Models`, `Services`, `Components`, and `Utilities`.
- Types generally use `UpperCamelCase`.
- Enums, models, and services are small and focused.
- Shared app state is commonly exposed through `ObservableObject`.
- New async work uses Swift concurrency in many places, even where older Combine remains present.

### Rules
- Prefer SwiftUI for new UI unless a UIKit bridge is already required.
- Place new code in the existing feature/core/shared folder structure instead of creating parallel architecture layers.
- Keep types focused; avoid putting unrelated responsibilities into a single view or service.
- Prefer `async/await` for new asynchronous logic.
- Use `ObservableObject`, `@Published`, and environment objects consistently with the existing state-sharing model.
- Preserve the existing dark-theme assumptions unless a feature specifically requires otherwise.

## Naming Conventions

### Rules
- Use `*View` for SwiftUI screen or component views.
- Use `*ViewModel` for stateful presentation logic where the repo already does so.
- Use `*Service` for integration, persistence, or orchestration logic.
- Use `*Store` for shared persisted collections.
- Use `*DTO`, `*Request`, and `*Response` for API payload shapes.
- Use `*Assets`, `*Constants`, and `*Utility` for static helpers and constants.

## Error Handling

### Facts from the repo
- Errors are commonly logged through `Logger`.
- Network and auth code surfaces `APIError`.
- Several persistence methods fail softly with logs rather than crashing.
- Some Core Data initialization uses `assertionFailure` on store load problems.

### Rules
- For network code, use `APIError` or preserve its semantics.
- Log operational failures with enough context to trace the failing subsystem.
- Fail gracefully in UI flows when user content cannot be loaded or persisted.
- Only use assertions for unrecoverable programmer/configuration errors, matching current persistence setup patterns.
- Do not silently swallow errors in new code without at least logging them.

## State and Persistence

### Rules
- Preserve security-scoped bookmark handling for externally selected files.
- Do not replace existing persistence stores casually:
  - `RecentStore` for local recents
  - `BackendChunkStore` for backend chunk metadata
  - `OnlineLibraryStore` for backend project metadata
- If changing persisted schemas or file locations, document the migration impact.

## Networking

### Rules
- Route backend HTTP calls through `APIClient` and `APIEndpoints`.
- Respect the existing split between auth endpoints and TTS endpoints.
- If adding auth-protected requests, integrate with the existing interceptor/session-refresh path.
- Do not hardcode new backend URLs outside the constants layer.

## Playback and Reader Behavior

### Rules
- Use `TTSPlayer` as the single source of truth for playback state.
- New reading flows should prepare content through `TTSPlayer` rather than owning their own speech engines.
- Preserve the distinction between:
  - preparing content without auto-play
  - opening content and auto-starting playback
- Keep sentence/word highlighting aligned with `TTSPlayer` tokenization.

## Testing Requirements

### Facts from the repo
- No automated tests are present.

### Rules
- For any significant behavioral change, add tests if a test target is introduced.
- Until a test target exists, every change should include manual verification notes.
- High-risk areas that especially need verification:
  - auth/login refresh flows
  - file/bookmark reopening
  - OCR extraction
  - PDF text extraction
  - backend voice generation/playback

## Pull Request Requirements

### Facts from the repo
- No in-repo PR template or CI gating exists.

### Rules
- Summarize the user-visible impact.
- Note which app target(s) were affected: `TTS`, `TTS Prod`, or both.
- List manual verification performed.
- Call out persistence, auth, or backend contract changes explicitly.
- Mention any TODOs or intentionally deferred follow-up work.

## Documentation Requirements

### Rules
- Update `AI_CONTEXT.md`, `ARCHITECTURE.md`, `CURRENT_STATE.md`, or ADRs when architecture or workflows materially change.
- If adding a new major subsystem or integration, add a new ADR under `docs/decisions/`.
- Keep facts separate from assumptions when documenting product behavior that is not directly evidenced in code.
