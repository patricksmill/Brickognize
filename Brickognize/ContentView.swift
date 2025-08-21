//
//  ContentView.swift
//  Brickognize
//
//  Created by Patrick Mill on 8/20/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            NavigationStack {
                CameraScannerView()
                    .navigationTitle("Scan")
                    .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { NavigationLink(destination: HistoryView()) { Image(systemName: "clock") } } }
            }
            .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
