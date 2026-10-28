import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var currentPage = 0
    @State private var dates: [Date] = []
    @State private var isSharePresented = false
    @State private var didLoadDays = false

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
            guard !didLoadDays else { return }
            didLoadDays = true
            await loadDays()
        }
        // Niet via onReceive: die publisher wordt bij elke render opnieuw opgebouwd,
        // waarna @Published de huidige waarde meteen opnieuw levert en removeDuplicates
        // geen geheugen heeft. Dat liet het archief honderden keren per seconde herbouwen.
        .onChange(of: viewModel.settings != nil) { ready in
            if ready { Task { await loadDays() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshIfDayChanged() }
        }
        // Vuurt om middernacht en bij tijdzone- of zomertijdwissels. Nodig naast de
        // notificatie hierboven, omdat een app die in Split View zichtbaar blijft staan
        // nooit opnieuw naar de voorgrond komt.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await refreshIfDayChanged() }
        }
    }

    // MARK: - Helper functions
    private func loadDays() async {
        // Settings worden nu automatisch in AppViewModel.init() geladen
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

    /// Bouwt het archief opnieuw op zodra de dag is verschoven sinds de laatste keer.
    ///
    /// `dates` loopt tot en met de dag waarop de lijst is samengesteld. Blijft de app
    /// dagenlang in het geheugen staan, dan ontbreekt vandaag in die lijst en heeft
    /// scrollToToday() niets om naartoe te springen.
    private func refreshIfDayChanged() async {
        let today = Calendar.current.startOfDay(for: Date())
        guard let last = dates.last, last < today else {
            scrollToToday()
            return
        }
        await loadDays()
        await viewModel.prefetchAroundToday()
    }

    private func scrollToToday() {
        guard !dates.isEmpty else { return }
        let calendar = Calendar.current
        // Valt terug op de laatste pagina, zodat de app nooit stil op een oude dag
        // blijft hangen als vandaag onverhoopt toch ontbreekt.
        let todayIndex = dates.firstIndex(where: { calendar.isDateInToday($0) }) ?? dates.count - 1
        self.currentPage = todayIndex
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
