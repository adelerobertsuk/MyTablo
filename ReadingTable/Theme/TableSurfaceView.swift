import SwiftUI

/// Full-bleed table surface. The wood is cropped to the glass, never stretched.
struct TableSurfaceView: View {
    let imageName: String
    var size: CGSize? = nil

    var body: some View {
        Image(imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size?.width, height: size?.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.light.bg)
            .clipped()
            .allowsHitTesting(false)
    }
}
