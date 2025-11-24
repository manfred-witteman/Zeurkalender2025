//
//  ZeurkalenderApp.swift
//  Zeurkalender
//
//  Created by Manfred on 23/11/2025.
//

import SwiftUI

@main
struct ZeurkalenderApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .task {
                    await viewModel.loadSettings()
                }
        }
        // Hide default menu bar
                .commands {
                    // Remove all default commands
                    CommandGroup(replacing: .newItem) {}
                    CommandGroup(replacing: .pasteboard) {}
                    CommandGroup(replacing: .appSettings) {}
                    CommandGroup(replacing: .undoRedo) {}
                    CommandGroup(replacing: .textEditing) {}
                    CommandGroup(replacing: .toolbar) {}
                }
    }
    
    
}
