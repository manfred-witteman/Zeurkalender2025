//
//  MailShareItem.swift
//  Zeurkalender
//
//  Created by Manfred on 23/11/2025.
//


import UIKit
import SwiftUI

// Must be a class inheriting from NSObject
class MailShareItem: NSObject, UIActivityItemSource {
    let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return " " // placeholder
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        switch activityType {
        case .mail?:
            return settings.mailBody
        default:
            return nil
        }
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return settings.appName // or a fixed string like "Peter van Straaten"
    }
}
