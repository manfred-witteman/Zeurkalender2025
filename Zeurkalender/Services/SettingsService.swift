//
//  SettingsService.swift
//  Zeurkalender
//
//  Created by Manfred on 23/11/2025.
//


import Foundation

final class SettingsService {
    func fetchSettings() async throws -> Settings {
        let urlString = AppConfig.settingsURL
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        print("Fetching settings from: \(urlString)")

        let (data, _) = try await URLSession.shared.data(from: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .useDefaultKeys

        return try decoder.decode(Settings.self, from: data)
    }
}
