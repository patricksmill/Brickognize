//
//  Models.swift
//  Brickognize
//
//  Created by Assistant on 8/20/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class ScanRecord {
    var id: UUID
    var timestamp: Date
    var recognizedName: String
    var recognizedId: String?
    var confidence: Double?
    var thumbnailJPEGData: Data?
    var remoteImageURL: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), recognizedName: String, recognizedId: String? = nil, confidence: Double? = nil, thumbnailJPEGData: Data? = nil, remoteImageURL: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.recognizedName = recognizedName
        self.recognizedId = recognizedId
        self.confidence = confidence
        self.thumbnailJPEGData = thumbnailJPEGData
        self.remoteImageURL = remoteImageURL
    }

    @MainActor
    var thumbnailImage: Image? {
        guard let data = thumbnailJPEGData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
}

struct RecognitionResult: Decodable {
    let id: String?
    let name: String
    let confidence: Double?
    let imageURL: URL?
}


