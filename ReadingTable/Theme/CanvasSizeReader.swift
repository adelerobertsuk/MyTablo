import SwiftUI
import UIKit

struct CanvasMetrics: Equatable {
    var size: CGSize
    var safeInsets: EdgeInsets

    static var current: CanvasMetrics {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        if let window {
            return CanvasMetrics(size: window.bounds.size, safeInsets: EdgeInsets(window.safeAreaInsets))
        }
        return CanvasMetrics(size: UIScreen.main.bounds.size, safeInsets: EdgeInsets())
    }
}

private extension EdgeInsets {
    init(_ insets: UIEdgeInsets) {
        self.init(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)
    }
}

/// Reads the real view bounds from UIKit so rotation cannot squash the table.
/// SwiftUI's GeometryReader animates width and height separately, which turns
/// round objects into ovals until the animation catches up.
struct CanvasSizeReader: UIViewRepresentable {
    var onChange: (CanvasMetrics) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeUIView(context: Context) -> BoundsView {
        let view = BoundsView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: BoundsView, context: Context) {
        context.coordinator.onChange = onChange
        uiView.coordinator = context.coordinator
    }

    final class Coordinator {
        var onChange: (CanvasMetrics) -> Void
        var last = CanvasMetrics(size: .zero, safeInsets: EdgeInsets())

        init(onChange: @escaping (CanvasMetrics) -> Void) {
            self.onChange = onChange
        }

        func report(_ metrics: CanvasMetrics) {
            guard metrics.size.width > 1, metrics.size.height > 1 else { return }
            let sizeChanged = abs(metrics.size.width - last.size.width) > 0.5
                || abs(metrics.size.height - last.size.height) > 0.5
            let insetsChanged = abs(metrics.safeInsets.top - last.safeInsets.top) > 0.5
                || abs(metrics.safeInsets.bottom - last.safeInsets.bottom) > 0.5
                || abs(metrics.safeInsets.leading - last.safeInsets.leading) > 0.5
                || abs(metrics.safeInsets.trailing - last.safeInsets.trailing) > 0.5
            guard sizeChanged || insetsChanged else { return }
            last = metrics
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onChange(metrics)
            }
        }
    }

    final class BoundsView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            report()
        }

        private func report() {
            let insets = window?.safeAreaInsets ?? safeAreaInsets
            let metrics = CanvasMetrics(size: bounds.size, safeInsets: EdgeInsets(insets))
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.report(metrics)
            }
        }
    }
}
