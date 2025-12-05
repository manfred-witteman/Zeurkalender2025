import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var currentPage = 0
    @State private var dates: [Date] = []
    @State private var isSharePresented = false

    var body: some View {
        ZStack {
            Color.red
                .ignoresSafeArea()

            if dates.isEmpty {
                ProgressView("Cartoon van vandaag laden...")
            } else {
                ZStack {
                    PageCurlView(
                        dates: dates,
                        currentPage: $currentPage,
                        viewModel: viewModel
                    )
                    .aspectRatio(1290/2288, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            if !dates.isEmpty && currentPage < dates.count, 
               let img = viewModel.imageCache.cachedImage(for: dates[currentPage]) {
                ShareSheet(items: [
                    img,
                    MailShareItem(settings: viewModel.settings!)
                ])
            }
        }
        .task {
            await loadDays()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            scrollToToday()
        }
    }

    // MARK: - Helper functions
    private func loadDays() async {
        await viewModel.loadSettings()
        guard let settings = viewModel.settings else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Stel archief samen van settings.firstDate t/m vandaag
        var ds: [Date] = []
        var date = calendar.startOfDay(for: settings.firstDate)
        while date <= today {
            ds.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        self.dates = ds
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
