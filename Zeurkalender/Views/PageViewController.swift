import SwiftUI
import UIKit

struct PageCurlView: UIViewControllerRepresentable {
    var images: [UIImage]
    @Binding var currentPage: Int

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

        // Use persistent view controllers from coordinator
        if context.coordinator.controllers.isEmpty {
            context.coordinator.controllers = images.map { image in
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFit
                return UIViewControllerWrapper(view: imageView)
            }
        }

        if let first = context.coordinator.controllers.first {
            pageVC.setViewControllers([first], direction: .forward, animated: false)
        }

        return pageVC
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        // Synchroniseer controllers-lijst met images indien nodig
        if context.coordinator.controllers.count != images.count {
            context.coordinator.controllers = images.map { image in
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFit
                return UIViewControllerWrapper(view: imageView)
            }
        }

        // Corrigeer currentPage als die buiten bereik valt
        let safePage = min(max(currentPage, 0), context.coordinator.controllers.count > 0 ? context.coordinator.controllers.count - 1 : 0)
        if currentPage != safePage {
            DispatchQueue.main.async {
                self.currentPage = safePage
            }
        }

        if context.coordinator.controllers.indices.contains(safePage) {
            let controller = context.coordinator.controllers[safePage]
            uiViewController.setViewControllers([controller], direction: .forward, animated: false)
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlView                   // <-- store a reference to parent
        var controllers: [UIViewController] = []

        init(_ parent: PageCurlView) {
            self.parent = parent                   // <-- assign parent
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController), index > 0 else { return nil }
            return controllers[index - 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController), index < controllers.count - 1 else { return nil }
            return controllers[index + 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            if completed, let visibleVC = pageViewController.viewControllers?.first,
               let index = controllers.firstIndex(of: visibleVC) {
                parent.currentPage = index
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                spineLocationFor orientation: UIInterfaceOrientation) -> UIPageViewController.SpineLocation {
            guard let currentVC = pageViewController.viewControllers?.first else { return .min }
            pageViewController.setViewControllers([currentVC], direction: .forward, animated: false)
            pageViewController.isDoubleSided = false
            return .min
        }
    }
}

// Simple wrapper for a UIView
class UIViewControllerWrapper: UIViewController {
    init(view: UIView) {
        super.init(nibName: nil, bundle: nil)
        self.view = view
    }
    required init?(coder: NSCoder) { fatalError() }
}
