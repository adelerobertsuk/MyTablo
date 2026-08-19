import SwiftUI

/// Maps saved table positions onto the current screen.
/// Uses one scale for width and height so a cup stays round when the iPad turns,
/// and the whole arrangement sits in the safe area instead of under the notch.
struct TableLayout: Equatable {
    var layoutSize: CGSize
    var canvasSize: CGSize
    var safeInsets: EdgeInsets = EdgeInsets()

    static let identity = TableLayout(
        layoutSize: CGSize(width: 1, height: 1),
        canvasSize: CGSize(width: 1, height: 1)
    )

    /// The glass minus notch, home indicator, and a little extra so books are not clipped.
    var itemBounds: CGRect {
        let extraTop: CGFloat = 12
        let extraSide: CGFloat = 8
        let top = safeInsets.top + extraTop
        let leading = safeInsets.leading + extraSide
        let bottom = safeInsets.bottom + extraSide
        let trailing = safeInsets.trailing + extraSide
        return CGRect(
            x: leading,
            y: top,
            width: max(1, canvasSize.width - leading - trailing),
            height: max(1, canvasSize.height - top - bottom)
        )
    }

    var itemScale: CGFloat { fit.scale }

    func display(_ point: CGPoint) -> CGPoint {
        let f = fit
        return CGPoint(
            x: f.origin.x + point.x * f.scale,
            y: f.origin.y + point.y * f.scale
        )
    }

    func stored(_ point: CGPoint) -> CGPoint {
        let f = fit
        guard f.scale > 0 else { return point }
        return CGPoint(
            x: (point.x - f.origin.x) / f.scale,
            y: (point.y - f.origin.y) / f.scale
        )
    }

    /// Keeps an item's centre on the visible table so pinch and drag cannot throw it off-screen.
    func clampedStored(fromDisplay point: CGPoint, inset: CGFloat = 56) -> CGPoint {
        let bounds = itemBounds
        let pad = min(inset, bounds.width / 4, bounds.height / 4)
        let clamped = CGPoint(
            x: min(max(point.x, bounds.minX + pad), bounds.maxX - pad),
            y: min(max(point.y, bounds.minY + pad), bounds.maxY - pad)
        )
        return stored(clamped)
    }

    private var fit: (scale: CGFloat, origin: CGPoint) {
        let bounds = itemBounds
        guard layoutSize.width > 0, layoutSize.height > 0 else {
            return (1, bounds.origin)
        }
        let scale = min(bounds.width / layoutSize.width, bounds.height / layoutSize.height)
        let scaled = CGSize(width: layoutSize.width * scale, height: layoutSize.height * scale)
        let origin = CGPoint(
            x: bounds.midX - scaled.width / 2,
            y: bounds.midY - scaled.height / 2
        )
        return (scale, origin)
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
