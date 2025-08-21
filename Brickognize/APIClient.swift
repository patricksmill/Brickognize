//
//  APIClient.swift
//  Brickognize
//
//  Created by Assistant on 8/20/25.
//

import Foundation
import UIKit

enum APIClientError: Error, CustomStringConvertible {
    case invalidURL
    case invalidResponse
    case serverError(status: Int, body: String?)
    case decodingError(body: String)
    case network(underlying: Error)
    case noResults

    var description: String {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid server response."
        case let .serverError(status, body):
            let snippet = body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return snippet.isEmpty ? "Server error (status: \(status))." : "Server error (status: \(status)): \(snippet)"
        case let .decodingError(body):
            let snippet = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Failed to read API response: \(snippet)"
        case let .network(underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .noResults:
            return "No results returned by the recognition service."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://api.brickognize.com")!
    private let session: URLSession
    private let uploadFieldName: String = Bundle.main.object(forInfoDictionaryKey: "BRICKOGNIZE_UPLOAD_FIELD") as? String ?? "query_image"
    private let endpointPath: String = Bundle.main.object(forInfoDictionaryKey: "BRICKOGNIZE_RECOGNIZE_PATH") as? String ?? "/predict/"
    private let apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "BRICKOGNIZE_API_KEY") as? String

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    func recognizeBrick(from image: UIImage) async throws -> RecognitionResult {
        guard let url = URL(string: endpointPath, relativeTo: baseURL) else { throw APIClientError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey = apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        let jpegData = image.jpegData(compressionQuality: 0.8) ?? Data()
        var body = Data()
        let lineBreak = "\r\n"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(uploadFieldName)\"; filename=\"scan.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIClientError.network(underlying: error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8)
            throw APIClientError.serverError(status: http.statusCode, body: bodyText)
        }

        do {
            // According to OpenAPI, /predict/ returns LegacySearchResultsSchema
            let decoded = try JSONDecoder().decode(LegacySearchResultsSchema.self, from: data)
            guard let first = decoded.items.first else { throw APIClientError.noResults }
            let url = URL(string: first.img_url)
            return RecognitionResult(id: first.id, name: first.name, confidence: first.score, imageURL: url)
        } catch {
            let bodyText = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            throw APIClientError.decodingError(body: bodyText)
        }
    }
}

// MARK: - OpenAPI response models (subset)

private struct LegacySearchResultsSchema: Decodable {
    let listing_id: String
    let items: [LegacyCandidateItemSchema]
}

private struct LegacyCandidateItemSchema: Decodable {
    let id: String
    let name: String
    let img_url: String
    let category: String?
    let type: String
    let score: Double
}


