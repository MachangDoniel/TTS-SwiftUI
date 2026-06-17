# AI Context

## Purpose

### Facts
- This repository contains a SwiftUI iOS application named `TTS` with two app targets: `TTS` and `TTS Prod`.
- The app converts text-based inputs into speech.
- Supported input flows implemented in code include typed text, local files, PDFs, photos, camera captures, and web pages.
- The app supports two speech paths:
  - On-device system speech via `AVSpeechSynthesizer`
  - Remote speech generation via a backend job API that returns chunked audio/text artifacts

### Assumptions / Inferences
- The product goal appears to be a consumer-facing reading/listening app for turning documents and captured text into audio.
- The "online library" feature suggests the product is evolving beyond simple on-device TTS toward reusable cloud-generated projects.

## Business Goals

### Facts
- Google sign-in is integrated.
- Production builds require an authenticated session before entering the main app.
- The profile area includes privacy policy, terms of use, and support/website links.
- Remote voice catalog and remote speech generation are first-class product features.

### Assumptions / Inferences
- The business likely differentiates through premium remote voices in addition to free system voices.
- The backend job pipeline and access-tier model imply monetization or tiered access is planned or already exists server-side.

## Problem Being Solved

### Facts
- Users can import or capture text from multiple sources.
- The app extracts text from PDFs, images, and web pages.
- The extracted or edited text can be read aloud with synchronized highlighting and playback controls.

### Assumptions / Inferences
- The product is solving "listen instead of read" for mixed document sources, including inaccessible or inconvenient formats.

## Main Features

### Facts
- Authentication
  - Google Sign-In via `GoogleSignIn`
  - Backend token exchange, refresh, logout, and keychain persistence
- Input sources
  - Manual text entry
  - Files picker
  - PDF reading
  - Photo library import
  - Camera capture with OCR
  - Web page text extraction
- Playback
  - Play/pause, seek, skip, progress timeline
  - Sentence and word highlighting
  - Voice selection
  - System voice mode and backend voice mode
- Persistence
  - Recent local activities persisted with Core Data
  - Backend chunk metadata persisted with Core Data
  - Online library metadata persisted as JSON in Documents
- Library surfaces
  - Local library filtered by file type
  - Online library grouped by project/source

### Incomplete or stubbed features
- Google Drive import is marked coming soon / TODO.
- Dropbox import is marked coming soon / TODO.
- "Book" import is marked coming soon / TODO.
- Some share/review/profile actions are TODO or commented out.

## Tech Stack

### Facts
- Language: Swift
- UI: SwiftUI
- Platform: iOS
- Minimum deployment target:
  - `TTS`: iOS 16.6
  - `TTS Prod`: iOS 16.0
- Packages
  - `Alamofire`
  - `GoogleSignIn`
  - `GoogleSignInSwift`
  - `Mantis`
- Apple frameworks used in code
  - `AVFoundation` / `AVFAudio`
  - `PDFKit`
  - `Vision`
  - `WebKit`
  - `CoreData`
  - `UIKit`

## Key Dependencies

### Facts
- `Alamofire` handles API requests and auth interception.
- `GoogleSignIn` handles Google authentication.
- `Mantis` is used for image cropping before OCR.
- `Vision` is used for OCR.
- `PDFKit` is used for PDF rendering and text extraction.

## Current Implementation Overview

### Facts
- App entry is `TTS/App/TTSApp.swift`.
- `AuthGateView` decides whether to show login, loading, or the main app.
- In non-production builds, `AuthGateView` returns `.authenticated` unconditionally.
- The main app shell is a tab-based SwiftUI UI with `Home`, `Library`, `Library Online`, and `Profile`.
- `TTSPlayer` is the central playback state machine used across screens.
- The remote TTS flow is orchestrated by `TTSBackendService` and `PublicTTSJobService`.
- The voice catalog merges remote voices with available system voices.

## Known Limitations

### Facts
- README content is effectively empty.
- No test target or test files were found in the repository.
- No CI/CD workflow files were found.
- The remote TTS API base URL is plain HTTP and requires an ATS exception for `68.183.127.122`.
- The development build bypasses auth gating unless `PRODUCTION` is defined.
- Some user flows are explicitly unimplemented via TODO comments.

### Assumptions / Inferences
- Because the backend host is a raw IP over HTTP, environment management and transport hardening are likely incomplete.
- Because persistence is programmatic and spread across multiple stores, schema evolution risk is higher than in a more centralized data layer.

## Important Constraints

### Facts
- Future changes must preserve the two-target setup (`TTS` and `TTS Prod`).
- Authentication behavior differs by compile-time configuration.
- Several flows depend on iOS security-scoped bookmarks for external files.
- Remote voice and backend generation depend on external services not present in this repo.
- User profile and auth tokens are stored locally using `UserDefaults` and Keychain respectively.

### Assumptions / Inferences
- Any agent working here should treat backend API contracts as external dependencies and avoid changing request/response assumptions without server coordination.
