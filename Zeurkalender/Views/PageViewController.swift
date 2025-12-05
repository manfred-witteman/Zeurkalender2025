import SwiftUI
import UIKit

struct PageCurlView: UIViewControllerRepresentable {
    var dates: [Date]
    @Binding var currentPage: Int
    var viewModel: AppViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .vertical,
            options: nil
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator

        // Start met vandaag
        if let firstVC = context.coordinator.controller(for: currentPage) {
            pageVC.setViewControllers([firstVC], direction: .forward, animated: false)
        }

        return pageVC
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        if let controller = context.coordinator.controller(for: currentPage) {
            uiViewController.setViewControllers([controller], direction: .forward, animated: false)
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlView
        var controllers: [Int: UIViewController] = [:] // cache per index

        init(_ parent: PageCurlView) {
            self.parent = parent
        }

        func controller(for index: Int) -> UIViewController? {
            guard parent.dates.indices.contains(index) else { return nil }
            if let cached = controllers[index] { return cached }
            let date = parent.dates[index]
            let vc = ImageLoaderViewController(date: date, viewModel: parent.viewModel)
            controllers[index] = vc
            return vc
        }

        func indexFor(viewController: UIViewController) -> Int? {
            controllers.first(where: { $0.value === viewController })?.key
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = indexFor(viewController: viewController), index > 0 else { return nil }
            return controller(for: index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = indexFor(viewController: viewController), index < parent.dates.count - 1 else { return nil }
            return controller(for: index + 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed,
                  let visibleVC = pageViewController.viewControllers?.first,
                  let index = indexFor(viewController: visibleVC) else { return }
            parent.currentPage = index

            // --- PREFETCH LOGICA ---
            // Prefetch buffer-dagen terug en 1 dag vooruit, alleen als ze niet al gecached zijn
            let bufferPast = parent.viewModel.imageCache.bufferPast
            let bufferFuture = 1 // bijvoorbeeld 1 dag vooruit

            let prefetchOffsets = (-bufferPast...bufferFuture).filter { $0 != 0 } // Exclude huidige dag
            for offset in prefetchOffsets {
                let prefetchIndex = index + offset
                guard parent.dates.indices.contains(prefetchIndex) else { continue }
                let dateToPrefetch = parent.dates[prefetchIndex]
                // Download alleen als nog niet in cache
                if parent.viewModel.imageCache.cachedImage(for: dateToPrefetch) == nil {
                    Task {
                        _ = await parent.viewModel.image(for: dateToPrefetch)
                    }
                }
            }
            // --- EINDE PREFETCH LOGICA ---
        }
    }
}

// Een UIViewController die een image laadt voor een dag
class ImageLoaderViewController: UIViewController {
    let date: Date
    let viewModel: AppViewModel

    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)

    init(date: Date, viewModel: AppViewModel) {
        self.date = date
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        loadImage()
    }

    private func loadImage() {
        spinner.startAnimating()
        Task {
            let img = await viewModel.image(for: date)
            await MainActor.run {
                imageView.image = img
                spinner.stopAnimating()
            }
        }
    }
}
