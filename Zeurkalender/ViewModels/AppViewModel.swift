//
//  AppViewModel.swift
//  Zeurkalender
//
//  Created by Manfred on 23/11/2025.
//

import UIKit
import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var settings: Settings?
    @Published var errorMessage: String?

    private let service = SettingsService()
    let imageCache = CalendarImageCache(
        bufferPast: 3,
        baseURL: AppConfig.imagesBaseURL
    )

    /// Load settings and prefetch images
    func loadSettings() async {
        do {
            settings = try await service.fetchSettings()
            
            // Prefetch images for today + buffer
            await imageCache.prefetchImages(today: Date())

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetch image for a specific date
    func image(for date: Date) async -> UIImage? {
        return await imageCache.image(for: date)
    }
}


