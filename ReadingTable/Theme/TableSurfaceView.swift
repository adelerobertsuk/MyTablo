import SwiftUI

/// Full-bleed table surface. The wood is cropped to the glass, never stretched.
struct TableSurfaceView: View {
    let imageName: String
    var size: CGSize? = nil

    var body: some View {
        GeometryReader { geo in
            let frame = size ?? geo.size
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: frame.width, height: frame.height)
                .clipped()
        }
        .background(Palette.light.bg)
        .allowsHitTesting(false)
    }
}
