//
//  AppConfig.swift
//  Zeurkalender
//
//  Created by Manfred on 23/11/2025.
//


import Foundation

struct AppConfig {
    static let baseURL = "https://www.tangibility.nl/icart/"
    static let bundleID = "nl.deharmonie.zeurkalender26"
    static let version = "1.0"

    static var settingsURL: String {
        return "\(baseURL)\(bundleID)/\(version)/settings.json"
    }

    static var imagesBaseURL: String {
        return "\(baseURL)\(bundleID)/\(version)/images/"
    }
}
