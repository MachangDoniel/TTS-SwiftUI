//
//  PublicTTSJobService.swift
//  TTS
//
//  Created by Assistant on 6/10/26.
//

import Foundation
import Alamofire
import UniformTypeIdentifiers

struct PreparedInitialUpload {
    let fileURL: URL
    let fileExtension: String
}

struct PersistedTranscriptFile {
    let fileURL: URL
    let fileName: String
}

final class PublicTTSJobService {
    func createUploadURL(_ body: UploadJobURLRequest) async throws -> UploadJobURLData {
        let request: APIRequestDescriptor<UploadJobURLResponse> = APIEndpoints.makeTTSRequest(
            path: APIEndpoints.uploadJobURL,
            body: body
        )
        let response = try await APIClient.shared.send(request)
        return response.data
    }

    func uploadFile(fileURL: URL, to uploadURL: String) async throws {
        guard let url = URL(string: uploadURL) else {
            throw APIError.invalidURL(uploadURL)
        }

        Logger.log("⬆️ Starting upload for \(fileURL.lastPathComponent)")
        let data = try Data(contentsOf: fileURL)
        let headers: HTTPHeaders = [
            HTTPHeader(name: "Content-Type", value: mimeType(for: fileURL)),
            HTTPHeader(name: "Content-Length", value: String(data.count))
        ]

        var logRequest = URLRequest(url: url)
        logRequest.httpMethod = "PUT"
        headers.forEach { logRequest.setValue($0.value, forHTTPHeaderField: $0.name) }
        Logger.apiRequest(logRequest)

        let response = await AF.upload(
            fileURL,
            to: url,
            method: .put,
            headers: headers
        )
        .serializingData()
        .response

        let statusCode = response.response?.statusCode ?? -1
        Logger.apiResponse(
            url: url.absoluteString,
            statusCode: statusCode,
            data: response.data
        )

        switch response.result {
        case .success:
            guard (200...299).contains(statusCode) else {
                throw APIError.server(statusCode)
            }
            Logger.log("✅ Upload finished for \(fileURL.lastPathComponent)")
        case .failure(let error):
            if let responseCode = response.response?.statusCode {
                throw APIError.server(responseCode)
            }
            throw APIError.network(error)
        }
    }

    func fetchStatus(requestId: String, userId: String?, visitorId: String?) async throws -> JobStatusData {
        let requestBody = JobStatusRequest(
            requestId: requestId,
            userId: userId,
            visitorId: visitorId
        )
        let request: APIRequestDescriptor<JobStatusResponse> = APIEndpoints.makeTTSRequest(
            path: APIEndpoints.jobStatus,
            body: requestBody
        )
        let response = try await APIClient.shared.send(request)
        return response.data
    }

    func triggerSpeechGeneration(
        requestId: String,
        userId: String?,
        visitorId: String?
    ) async throws -> JobStatusData {
        let requestBody = JobStatusRequest(
            requestId: requestId,
            userId: userId,
            visitorId: visitorId
        )
        let request: APIRequestDescriptor<JobStatusResponse> = APIEndpoints.makeTTSRequest(
            path: APIEndpoints.speechGeneration,
            body: requestBody
        )
        let response = try await APIClient.shared.send(request)
        return response.data
    }

    func waitForJobCompletion(
        requestId: String,
        userId: String?,
        visitorId: String?,
        maxAttempts: Int = 60,
        pollIntervalNanos: UInt64 = 5_000_000_000,
        onUpdate: ((JobStatusData) -> Void)? = nil
    ) async throws -> JobStatusData {
        var lastStatus: JobStatusData?

        for _ in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: pollIntervalNanos)
            do {
                let status = try await fetchStatus(
                    requestId: requestId,
                    userId: userId,
                    visitorId: visitorId
                )
                lastStatus = status
                onUpdate?(status)

                if let downloadURL = status.downloadUrl,
                   !downloadURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return status
                }
            } catch let error as APIError {
                if case .server(400) = error {
                    continue
                }
                throw error
            }
        }

        return lastStatus ?? JobStatusData(
            requestId: requestId,
            status: "timeout",
            progress: nil,
            downloadUrl: nil,
            chunkTextUrls: nil
        )
    }

    func downloadChunkTexts(from urls: [String]) async throws -> [DownloadedChunkText] {
        var items: [DownloadedChunkText] = []

        for (index, value) in urls.enumerated() {
            items.append(try await downloadChunkText(from: value, index: index))
        }

        return items
    }

    func downloadChunkText(from sourceURL: String, index: Int) async throws -> DownloadedChunkText {
        guard let url = URL(string: sourceURL) else {
            throw APIError.invalidURL(sourceURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw APIError.server(httpResponse.statusCode)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw APIError.decoding(NSError(domain: "ChunkTextDecoding", code: -1))
        }

        return DownloadedChunkText(
            index: index,
            sourceURL: sourceURL,
            text: text
        )
    }

    func normalizedInitialExtension(from fileURL: URL?) -> String {
        let ext = fileURL?.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ext.isEmpty ? "txt" : ext.lowercased()
    }

    func prepareInitialUpload(
        originalFileURL: URL?,
        fallbackText: String,
        requestId: String,
        title: String?
    ) throws -> PreparedInitialUpload {
        if let originalFileURL,
           FileManager.default.fileExists(atPath: originalFileURL.path) {
            return PreparedInitialUpload(
                fileURL: originalFileURL,
                fileExtension: normalizedInitialExtension(from: originalFileURL)
            )
        }

        let derivedExtension = normalizedInitialExtension(
            from: title.flatMap { URL(fileURLWithPath: $0) }
        )
        let fileURL = try makeUploadFile(
            text: fallbackText,
            requestId: requestId,
            chunkIndex: 1,
            fileExtension: derivedExtension
        )
        return PreparedInitialUpload(
            fileURL: fileURL,
            fileExtension: derivedExtension
        )
    }

    func makeUploadFile(
        text: String,
        requestId: String,
        chunkIndex: Int,
        fileExtension: String
    ) throws -> URL {
        let sanitizedRequestId = requestId.replacingOccurrences(of: "/", with: "_")
        let normalizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "txt"
            : fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedRequestId)_chunk_\(chunkIndex)")
            .appendingPathExtension(normalizedExtension)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func persistTranscriptFile(
        text: String,
        requestId: String,
        voiceName: String,
        preferredBaseName: String?
    ) throws -> PersistedTranscriptFile {
        let docsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let baseName = sanitizedFileComponent(
            preferredBaseName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? preferredBaseName!
                : "Online Transcript"
        )
        let voiceComponent = sanitizedFileComponent(voiceName)
        let requestComponent = sanitizedFileComponent(requestId).prefix(8)
        let fileName = "\(baseName)_\(voiceComponent)_\(requestComponent).txt"
        let fileURL = docsURL.appendingPathComponent(fileName)
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        return PersistedTranscriptFile(fileURL: fileURL, fileName: fileName)
    }
}

private extension PublicTTSJobService {
    func mimeType(for fileURL: URL) -> String {
        if let type = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType {
            return type
        }
        return "text/plain"
    }

    func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let collapsed = value
            .replacingOccurrences(of: " ", with: "_")
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
        let string = String(collapsed)
            .replacingOccurrences(of: "__", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return string.isEmpty ? "file" : string
    }
}
