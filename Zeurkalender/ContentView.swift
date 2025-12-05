import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var currentPage = 0
    @State private var images: [UIImage] = []
    @State private var dates: [Date] = []
    @State private var isSharePresented = false

    var body: some View {
        ZStack {
            Color.red
                .ignoresSafeArea()

            if images.isEmpty {
                ProgressView("Cartoon van vandaag laden...")
            } else {
                ZStack {
                    PageCurlView(images: images, currentPage: $currentPage)
                        .aspectRatio(1290/2288, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // BOTTOM BUTTON overlay
                    VStack {
                        Spacer()
                        Button(
                            action: { isSharePresented = true },
                            label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .background(Color.white.opacity(0.4))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        )
                        .padding(.bottom, 40)
                    }
                }
                .statusBar(hidden: false)
            }
        }
        .sheet(isPresented: $isSharePresented) {
            if !images.isEmpty && currentPage < images.count {
                ShareSheet(items: [
                    images[currentPage],
                    MailShareItem(settings: viewModel.settings!)
                ])
            }
        }
        .task {
            await loadTodayAndPrefetch()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            scrollToToday()
        }
    }

    // MARK: - Helper functions
    private func loadTodayAndPrefetch() async {
        await viewModel.loadSettings()
        guard let settings = viewModel.settings else { return }

        let calendar = Calendar.current
        let today = Date()

        // 1. Laad alleen cartoon van vandaag
        var loadedImages: [UIImage] = []
        var loadedDates: [Date] = []

        if let todayImage = await viewModel.image(for: today) {
            loadedImages.append(todayImage)
            loadedDates.append(today)
            self.images = loadedImages
            self.dates = loadedDates
            self.currentPage = 0 // Vandaag is altijd eerste
        }

        // 2. Laad de rest asynchroon (oudere cartoons, gisteren, etc.)
        Task.detached { [settings] in
            let calendar = Calendar.current
            var extraImages: [(img: UIImage, date: Date)] = []

            var date = settings.firstDate
            while date < calendar.startOfDay(for: today) {
                if let img = await viewModel.image(for: date) {
                    extraImages.append((img, date))
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = next
            }

            // Gisteren eerst, dan de rest
            extraImages.sort { $0.date < $1.date }

            // Voeg de nieuwe cartoons toe vóór vandaag (zodat chronologie klopt)
            await MainActor.run {
                self.images = extraImages.map { $0.img } + loadedImages
                self.dates = extraImages.map { $0.date } + loadedDates
                scrollToToday()
            }
        }
    }

    private func scrollToToday() {
        guard !dates.isEmpty else { return }
        let calendar = Calendar.current
        if let todayIndex = dates.firstIndex(where: { calendar.isDateInToday($0) }) {
            self.currentPage = todayIndex
        }
    }
}

// UIKit Share Sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
