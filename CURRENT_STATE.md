# Current State

## What Currently Works

### Evidence-backed
- The app has a complete SwiftUI shell with auth gating, tabs, and primary screens.
- Google Sign-In and backend token exchange are implemented in code.
- Production-mode auth gating is implemented.
- Development-mode auth bypass is implemented via compile-time condition.
- Users can create or ingest text from:
  - manual text entry
  - local files
  - PDFs
  - camera capture
  - photo library
  - web page extraction
- The app can read text aloud using:
  - system voices
  - backend-generated voice audio
- The app persists:
  - auth tokens in Keychain
  - profile details in `UserDefaults`
  - local recents in Core Data
  - backend chunk metadata in Core Data
  - online library metadata in JSON
- Voice catalog loading and remote/system voice merging are implemented.

## What Appears Incomplete

### Evidence-backed
- README does not document the project.
- Google Drive, Dropbox, and Book import actions are stubbed or marked coming soon.
- Some sharing/review/profile actions are TODO or commented out.
- `FileViewerView.swift` is a placeholder-style viewer and does not appear to be the real file-viewing path; `Features/FileViewer/FileViewer.swift` is the active implementation.
- No automated tests are present.
- No CI/CD automation is present.

### Assumptions / Inferences
- Product requirements and roadmap are only partially encoded in code, so onboarding currently depends heavily on source inspection.

## Technical Debt

### Evidence-backed
- Auth behavior diverges sharply between dev and prod builds.
- Multiple persistence mechanisms are used for related document state.
- Several services are global singletons, increasing hidden coupling.
- The backend TTS host uses plain HTTP plus an ATS exception.
- Programmatic Core Data models increase maintenance burden compared with model files plus migrations.
- `NetworkManager` coexists with `APIClient`, suggesting an older or parallel networking path.

## Known Risks

### High risk
- No tests protect auth, OCR, playback, or persistence regressions.
- External backend behavior cannot be validated from this repo alone.
- Backend transport uses insecure HTTP for TTS traffic.

### Medium risk
- Security-scoped bookmark handling is complex and easy to regress.
- The playback engine spans system speech, backend audio, highlighting, and online library restoration in one central object.
- The repo currently depends on implicit conventions rather than written docs.

### Environment risk
- Local command-line build verification was blocked in this environment by sandbox/cache permission issues during Swift package resolution, so buildability was not fully re-verified here.

## High-Priority Improvements

### Evidence-based recommendations
- Add at least one test target and start with smoke coverage for auth, text parsing, and persistence.
- Add CI that resolves packages and builds both app targets.
- Document backend API expectations and environment setup.
- Consolidate or formally document the persistence model across recents, chunks, and online library items.
- Remove or harden the dev-mode auth bypass before relying on the dev target for release-like QA.
- Replace the raw HTTP backend endpoint with HTTPS if the backend supports it.

## Suggested Next Tasks

1. Add repository-level onboarding docs and ADRs. This is completed by the documentation created in this change.
2. Introduce a test target with focused tests for `TTSSentenceParser`, auth token loading/refresh logic, and persistence stores.
3. Add CI for package resolution and both Xcode schemes.
4. Finish or remove stubbed import sources so the UI reflects actual capability.
5. Centralize environment configuration for backend hosts and production/dev behavior.
6. Reduce coupling around `TTSPlayer` and singleton services.

## Uncertainties

### Not directly provable from this repo
- The exact production backend contract beyond the client request/response models.
- Distribution/release workflow.
- Subscription, billing, or access-tier business rules beyond what can be inferred from enum names and UI strings.
- Whether the placeholder/legacy files are still used in manual internal workflows.
