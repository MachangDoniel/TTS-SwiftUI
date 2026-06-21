# Voice API and Asset Cache Contract

This note documents the public voice API shape used by `VoiceCatalog` and the cache rules for remote voice images and preview audio.

## Endpoints

- `GET /api/tts/public/voices`
- `GET /api/tts/public/languages`

The current backend base URL may vary by environment. Recent logs show:

- `http://68.183.127.122:8282/api/tts/public/voices`
- `http://68.183.127.122:8282/api/tts/public/languages`

## Voice Response Shape

The voices endpoint returns an envelope:

```json
{
  "status": "success",
  "message": "Voice samples fetched successfully",
  "data": [
    {
      "id": 44,
      "name": "Morgan Freeman",
      "type": "celebrity",
      "language": "English",
      "gender": "Male",
      "description": "Iconic, soothing voice for narration and storytelling.",
      "rating": 5,
      "useCount": 100,
      "priority": 95,
      "updatedAt": "2026-06-03T15:09:17.177730Z",
      "imageUrl": "https://.../44.jpg?...",
      "audioUrl": "https://.../44.mp3?...",
      "sampleInputText": "https://.../input_text_44.txt?..."
    }
  ]
}
```

Important details:

- `updatedAt` is the stable version marker for a voice asset set.
- `imageUrl`, `audioUrl`, and `sampleInputText` can be signed URLs with expiring query parameters.
- Because signed URLs can change on every fetch, they must not be the primary cache invalidation key when `updatedAt` exists.

## Language Response Shape

The languages endpoint returns an envelope:

```json
{
  "status": "success",
  "message": "Languages fetched successfully",
  "data": [
    {
      "name": "English",
      "code": "en"
    }
  ]
}
```

## Current App Mapping

`RemoteVoiceDTO.updatedAt` maps to `Voice.updatedAt`.

Remote voice fields used by the app:

- `id` -> `voiceSampleId`, `backendVoiceID`
- `name` -> `name`
- `language` -> `language`
- `gender` -> `genderHint`
- `type` -> `backendCategory`
- `description` -> `voiceDescription`
- `rating` -> `rating`
- `useCount` -> `useCount`
- `priority` -> `priority`
- `sampleInputText` -> `sampleInputTextURL`
- `audioUrl` -> `audioPreviewURL`
- `imageUrl` -> `imageURL`
- `updatedAt` -> `updatedAt`

## Cache Rules

Catalog cache:

- The fetched voice catalog is stored as JSON.
- When a new API response arrives, the app compares `updatedAt` timestamps for matching voice IDs.
- If the fetched `updatedAt` is newer than the cached one, fetched voice metadata replaces cached metadata.

Asset cache:

- Images are cached under the app caches directory.
- Downloaded preview audio is stored under `Application Support/voice_audio_previews`.
- Preview audio is not predownloaded; it is downloaded only when the user taps the download button.
- Asset filenames are versioned with `updatedAt` when available.
- If `updatedAt` is missing, the URL is used as a fallback version marker.
- Version markers are SHA-256 hashed before becoming filenames, so signed URLs do not create oversized filenames.
- If `updatedAt` changes, the app naturally looks for a new cache file and redownloads the asset.

## Validation

Asset downloads should only be persisted when:

- the HTTP status code is 2xx, or the response is not HTTP but still valid for local file reads
- the returned data is non-empty

Do not cache empty responses, expired signed URL responses, HTML/XML error pages, or non-2xx API responses as audio/image assets.
