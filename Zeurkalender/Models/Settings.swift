//
//  Settings.swift
//  Zeurkalender
//
//  Created by Manfred on 23/11/2025.
//


import Foundation

struct Settings: Codable {
    let firstDate: Date
    let lastDate: Date
    let refresh: Date
    let appName: String
    let mailBody: String
    let hideDate: Bool
    let landscape: Bool
    let zoomable: Bool
    let zoomFactor: Int
    let iPhone5Alignment: String
    let compositeRGB: String
    let subs: [String]

    enum CodingKeys: String, CodingKey {
        case firstDate = "FirstDate"
        case lastDate = "LastDate"
        case refresh = "Refresh"
        case appName = "AppName"
        case mailBody = "MailBody"
        case hideDate = "HideDate"
        case landscape = "Landscape"
        case zoomable = "Zoomable"
        case zoomFactor = "ZoomFactor"
        case iPhone5Alignment = "iPhone5Alignment"
        case compositeRGB = "CompositeRGB"
        case subs = "subs"
    }
}
