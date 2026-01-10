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
    let bufferFuture: Int             // Number of future days to cache
    let baseURL: String               // Full base URL to images folder
    private let cacheFolder: URL      // Disk cache folder
    private let memoryCache = NSCache<NSString, UIImage>() // In-memory cache
    private(set) var cachedDates: [Date] = []
    // Registry van lopende download-taken per bestandsnaam
    private var ongoingTasks: [String: Task<UIImage?, Never>] = [:]
    private var didPrefetch = false

    // MARK: - Init

    init(bufferPast: Int = 3, bufferFuture: Int = 7, baseURL: String) {
        self.bufferPast = bufferPast
        self.bufferFuture = bufferFuture
        self.baseURL = baseURL

        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheFolder = caches.appendingPathComponent("ZeurkalenderImages")
        try? fm.createDirectory(at: cacheFolder, withIntermediateDirectories: true)

        print("!!!!!! CalendarImageCache.swift wordt geladen")
        print("[Cache init] instance: \(ObjectIdentifier(self))")
        print("Cache folder:", cacheFolder.path)
    }

    // MARK: - Public Methods

    /// Fetch image for a specific date
    /// - Parameter date: The date of the cartoon
    /// - Parameter allowFuture: If true, allows fetching images for future dates (for prefetching)
    func image(for date: Date, allowFuture: Bool = false) async -> UIImage? {
        // Only allow requested date if in the past/until today, unless allowFuture is true
        if !allowFuture && date > Date() {
            print("[Cache] Ignoring future date request: \(filenameFor(date: date))")
            return nil
        }

        let filename = filenameFor(date: date)
        print("[Cache] Begin fetch: \(filename)")
        defer { print("[Cache] End fetch: \(filename)") }

        print("[Cache] ongoingTasks: \(ongoingTasks.keys)")

        // Prevent dubbele downloads via registry
        if let existing = ongoingTasks[filename] {
            print("[Cache] Awaiting existing task for: \(filename)")
            return await existing.value
        }

        print("[Cache] Adding ongoing task: \(filename)")
        let task = Task<UIImage?, Never> {
            defer {
                ongoingTasks[filename] = nil
                print("[Cache] Removing completed task: \(filename)")
            }

            // 1️⃣ Check in-memory cache
            if let img = memoryCache.object(forKey: filename as NSString) {
                print("[Cache] Memory hit: \(filename)")
                return img
            }

            // 2️⃣ Check disk cache
            let fileURL = cacheFolder.appendingPathComponent(filename)
            if let img = UIImage(contentsOfFile: fileURL.path) {
                print("[Cache] Disk hit: \(filename)")
                memoryCache.setObject(img, forKey: filename as NSString)
                return img
            }

            // 3️⃣ Download from network
            guard let url = URL(string: baseURL + filename) else { return nil }
            print("Downloading image for date: \(filename) from URL: \(url)")

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let img = UIImage(data: data) else {
                    print("[Cache] Decode failed for: \(filename)")
                    return nil
                }

                // Save to memory & disk
                memoryCache.setObject(img, forKey: filename as NSString)
                let fileURL = cacheFolder.appendingPathComponent(filename)
                try? data.write(to: fileURL)
                print("[Cache] Saved to disk: \(filename)")

                cachedDates.append(date)
                // Removed cleanupCache(today:) call here as per instructions

                return img
            } catch {
                print("Failed to download \(filename):", error)
                return nil
            }
        }
        ongoingTasks[filename] = task
        return await task.value
    }

    /// Prefetch images around today (past buffer + tomorrow)
    func prefetchImages(today: Date) async {
        let calendar = Calendar.current

        if didPrefetch {
            print("[Prefetch] Skipping; already prefetched this session")
            return
        }
        didPrefetch = true

        // 1) Always fetch today's image first and await it
        let todayStart = calendar.startOfDay(for: today)
        print("[Prefetch] Fetching today's image first")
        let todaysImage = await image(for: todayStart, allowFuture: false)
        if todaysImage != nil {
            print("[Prefetch] Today's image ready")
        } else {
            print("[Prefetch] Failed to load today's image")
        }

        // 2) Then fetch past buffer sequentially (oldest to newest)
        if bufferPast > 0 {
            for offset in stride(from: bufferPast, through: 1, by: -1) { // e.g., 3,2,1
                if let past = calendar.date(byAdding: .day, value: -offset, to: todayStart) {
                    _ = await image(for: past, allowFuture: false)
                }
            }
        }

        // 3) Prefetch future days (bufferFuture days ahead)
        if bufferFuture > 0 {
            for offset in 1...bufferFuture {
                if let future = calendar.date(byAdding: .day, value: offset, to: todayStart) {
                    _ = await image(for: future, allowFuture: true)
                }
            }
        }

        // 4) Cleanup once after prefetching
        cleanupCache(today: todayStart)

        // removed didPrefetch = true here
    }

    /// Loads today's image for immediate UI use, then starts prefetching the rest in the background.
    @discardableResult
    func loadTodaysImageAndStartPrefetch() async -> UIImage? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        // 1) Get today's image for immediate UI update
        let img = await image(for: todayStart, allowFuture: false)
        // 2) Fire-and-forget the rest (only once due to didPrefetch)
        Task { [weak self] in
            guard let self else { return }
            await self.prefetchImages(today: todayStart)
        }
        return img
    }

    /// Geeft direct een gecachte afbeelding terug, of nil als niet aanwezig (géén disk/netwerk fetch)
    func cachedImage(for date: Date) -> UIImage? {
        let filename = filenameFor(date: date)
        return memoryCache.object(forKey: filename as NSString)
    }

    // MARK: - Private Helpers

    /// Convert Date to filename (yyMMdd.png)
    private func filenameFor(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: date) + ".png"
    }

    /// Remove files outside the buffer, keeping a window from past buffer to future buffer
    private func cleanupCache(today: Date) {
        let fm = FileManager.default
        let calendar = Calendar.current

        guard let minDate = calendar.date(byAdding: .day, value: -bufferPast, to: today) else { return }
        guard let maxDate = calendar.date(byAdding: .day, value: bufferFuture, to: today) else { return }

        do {
            let files = try fm.contentsOfDirectory(at: cacheFolder, includingPropertiesForKeys: nil)
            for file in files {
                let name = file.deletingPathExtension().lastPathComponent
                let formatter = DateFormatter()
                formatter.dateFormat = "yyMMdd"
                formatter.locale = Locale(identifier: "nl_NL")

                if let fileDate = formatter.date(from: name) {
                    // Remove file if outside the kept date range [minDate ... maxDate]
                    if fileDate < minDate || fileDate > maxDate {
                        print("[Cache] Removing from disk: \(file.lastPathComponent)")
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

