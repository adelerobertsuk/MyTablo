import SwiftUI

/// Maps saved table positions onto the current screen, so a landscape
/// arrangement still fits when the iPad is turned to portrait (and back).
struct TableLayout: Equatable {
    var layoutSize: CGSize
    var canvasSize: CGSize

    static let identity = TableLayout(
        layoutSize: CGSize(width: 1, height: 1),
        canvasSize: CGSize(width: 1, height: 1)
    )

    func display(_ point: CGPoint) -> CGPoint {
        guard layoutSize.width > 0, layoutSize.height > 0 else { return point }
        return CGPoint(
            x: point.x / layoutSize.width * canvasSize.width,
            y: point.y / layoutSize.height * canvasSize.height
        )
    }

    func stored(_ point: CGPoint) -> CGPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return point }
        return CGPoint(
            x: point.x / canvasSize.width * layoutSize.width,
            y: point.y / canvasSize.height * layoutSize.height
        )
    }
}

private struct TableLayoutKey: EnvironmentKey {
    static let defaultValue: TableLayout = .identity
}

extension EnvironmentValues {
    var tableLayout: TableLayout {
        get { self[TableLayoutKey.self] }
        set { self[TableLayoutKey.self] = newValue }
    }
}
