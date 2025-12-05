//
//  CalendarImageCache.swift
//  Zeurkalender
//
//  Created by Manfred on 23/11/2025.
//

import Foundation
import UIKit

@MainActor
final class CalendarImageCache {

    // MARK: - Public Properties

    let bufferPast: Int               // Number of past days to cache
    let baseURL: String               // Full base URL to images folder
    private let cacheFolder: URL      // Disk cache folder
    private let memoryCache = NSCache<NSString, UIImage>() // In-memory cache
    private(set) var cachedDates: [Date] = []

    // MARK: - Init

    init(bufferPast: Int = 3, baseURL: String) {
        self.bufferPast = bufferPast
        self.baseURL = baseURL

        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheFolder = caches.appendingPathComponent("ZeurkalenderImages")
        print("Cache folder:", cacheFolder.path)
        
        try? fm.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Fetch image for a specific date
    /// - Parameter date: The date of the cartoon
    /// - Parameter allowFuture: If true, allows fetching images for future dates (for prefetching)
    func image(for date: Date, allowFuture: Bool = false) async -> UIImage? {
        // Only allow requested date if in the past/until today, unless allowFuture is true
        if !allowFuture && date > Date() {
            return nil
        }

        let filename = filenameFor(date: date)

        // 1️⃣ Check in-memory cache
        if let img = memoryCache.object(forKey: filename as NSString) {
            return img
        }

        // 2️⃣ Check disk cache
        let fileURL = cacheFolder.appendingPathComponent(filename)
        if let img = UIImage(contentsOfFile: fileURL.path) {
            memoryCache.setObject(img, forKey: filename as NSString)
            return img
        }

        // 3️⃣ Download from network
        guard let url = URL(string: baseURL + filename) else { return nil }
        print("Downloading image for date: \(filename) from URL: \(url)")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let img = UIImage(data: data) else { return nil }

            // Save to memory & disk
            memoryCache.setObject(img, forKey: filename as NSString)
            try? data.write(to: fileURL)

            cachedDates.append(date)
            cleanupCache(today: Date())

            return img
        } catch {
            print("Failed to download \(filename):", error)
            return nil
        }
    }

    /// Prefetch images around today (past buffer + tomorrow)
    func prefetchImages(today: Date) async {
        let calendar = Calendar.current
        var datesToPrefetch: [Date] = []

        // Past buffer
        for offset in (0...bufferPast).reversed() {
            if let past = calendar.date(byAdding: .day, value: -offset, to: today) {
                datesToPrefetch.append(past)
            }
        }

        // Tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            datesToPrefetch.append(tomorrow)
        }

        for date in datesToPrefetch {
            // Alleen bij prefetchen mag allowFuture true zijn
            let isTomorrow = calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: today)!)
            _ = await image(for: date, allowFuture: isTomorrow)
        }

        cleanupCache(today: today)
    }

    // MARK: - Private Helpers

    /// Convert Date to filename (yyMMdd.png)
    private func filenameFor(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: date) + ".png"
    }

    /// Remove files outside the buffer, but always keep yesterday, today, and tomorrow
    private func cleanupCache(today: Date) {
        let fm = FileManager.default
        let calendar = Calendar.current

        guard let minDate = calendar.date(byAdding: .day, value: -bufferPast, to: today) else { return }

        // Bereken gisteren, vandaag, morgen
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let keepDates: Set<Date> = [yesterday, today, tomorrow]

        do {
            let files = try fm.contentsOfDirectory(at: cacheFolder, includingPropertiesForKeys: nil)
            for file in files {
                let name = file.deletingPathExtension().lastPathComponent
                let formatter = DateFormatter()
                formatter.dateFormat = "yyMMdd"
                formatter.locale = Locale(identifier: "nl_NL")

                if let fileDate = formatter.date(from: name) {
                    // Vergelijk alleen op jaar, maand, dag (tijd negeren)
                    let isKeepDate = keepDates.contains { calendar.isDate($0, inSameDayAs: fileDate) }

                    if !isKeepDate && (fileDate < minDate || fileDate > today.addingTimeInterval(24*60*60)) {
                        try? fm.removeItem(at: file)
                        memoryCache.removeObject(forKey: file.lastPathComponent as NSString)
                    }
                }
            }
        } catch {
            print("Cleanup error:", error)
        }
    }
}
