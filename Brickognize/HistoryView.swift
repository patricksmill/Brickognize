//
//  HistoryView.swift
//  Brickognize
//
//  Created by Assistant on 8/20/25.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.timestamp, order: .reverse) private var records: [ScanRecord]

    var body: some View {
        List {
            ForEach(records) { record in
                HStack(alignment: .top, spacing: 12) {
                    if let urlString = record.remoteImageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure(_):
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.gray.opacity(0.2))
                                    .frame(width: 56, height: 56)
                                    .overlay(Image(systemName: "cube.fill").foregroundStyle(.secondary))
                            case .empty:
                                ProgressView()
                                    .frame(width: 56, height: 56)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else if let image = record.thumbnailImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(Image(systemName: "cube.fill").foregroundStyle(.secondary))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.recognizedName).font(.headline)
                        if let id = record.recognizedId { Text("ID: \(id)").font(.subheadline).foregroundStyle(.secondary) }
                        HStack(spacing: 8) {
                            Text(record.timestamp, style: .date).font(.caption).foregroundStyle(.secondary)
                            Text(record.timestamp, style: .time).font(.caption).foregroundStyle(.secondary)
                            if let confidence = record.confidence { Text(String(format: "%.0f%%", confidence * 100)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Scan History")
        .toolbar { EditButton() }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(records[index]) }
        do { try modelContext.save() } catch { }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: ScanRecord.self, inMemory: true)
}


