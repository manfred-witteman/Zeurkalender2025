//
//  PageController.swift
//  Zeurkalender
//
//  Created by Manfred on 23/11/2025.
//


import SwiftUI
import UIKit

struct PageController: UIViewControllerRepresentable {
    var controllers: [UIViewController]

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pvc.setViewControllers([controllers.first!], direction: .forward, animated: true)
        return pvc
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {}
}
