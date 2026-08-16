import SwiftUI

/// Full-bleed table surface. Scaled a hair so the texture reaches every edge.
struct TableSurfaceView: View {
    let imageName: String
    var size: CGSize? = nil

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size?.width, height: size?.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(1.02, anchor: .center)
            .background(Palette.light.bg)
            .clipped()
    }
}
