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
                ProgressView("Cartoons laden...")
            } else {
                ZStack {
                    PageCurlView(images: images, currentPage: $currentPage)
                        .aspectRatio(1290/2288, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

//                    // TOP IMAGE overlay
//                    VStack {
//                        Image("randje")
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(maxWidth: .infinity)
//                                    .padding(.top, 0)             // aligns to the very top of safe area
//                                    .ignoresSafeArea(edges: .top) // optionally move into status bar area
//                                    .allowsHitTesting(false)
//                                Spacer()
//                    }

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
            await loadImages()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            scrollToToday()
        }
    }

    // MARK: - Helper functions
    private func loadImages() async {
        await viewModel.loadSettings()
        guard let settings = viewModel.settings else { return }

        let calendar = Calendar.current
        var loadedImages: [UIImage] = []
        var loadedDates: [Date] = []

        var date = settings.firstDate
        while date <= Date() {
            if let img = await viewModel.image(for: date) {
                loadedImages.append(img)
                loadedDates.append(date)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        self.images = loadedImages
        self.dates = loadedDates

        scrollToToday()
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
