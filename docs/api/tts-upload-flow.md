# TTS Upload Flow

This app uses two different transport paths:

- JSON API calls use `APIClient`, which is backed by Alamofire.
- Signed file uploads to R2 now also use Alamofire via `AF.upload(...)`.

## Current upload sequence

1. Request a signed upload URL from:
   - `POST /api/tts/public/jobs/upload-url`
2. Upload the source file with `PUT` to the returned R2 URL.
3. Trigger speech generation with:
   - `POST /api/tts/public/jobs/speech-generation`
4. Poll job status until a chunk download URL becomes available.

## Notes

- The upload request is a raw file upload, not JSON.
- Content type is derived from the source file extension.
- Upload logging is handled separately so silent hangs are easier to diagnose.
