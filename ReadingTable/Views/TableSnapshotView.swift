import SwiftUI

struct TableSnapshotView: View {
    let composition: CoffeeTableComposition
    var size: CGSize = CGSize(width: 402, height: 874)
    var showsShareMark: Bool = true

    var body: some View {
        ZStack {
            TableSurfaceView(imageName: composition.surfaceImageName, size: size)

            ForEach(composition.items.sorted(by: { $0.zIndex < $1.zIndex })) { composedBook in
                TableBookView(composedBook: composedBook, isInteractive: false)
                    .zIndex(composedBook.zIndex)
            }

            ForEach(composition.decorations.sorted(by: { $0.zIndex < $1.zIndex })) { decoration in
                DecorationView(decoration: decoration, isInteractive: false)
                    .zIndex(decoration.zIndex)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.tableLayout, TableLayout(
            layoutSize: CGSize(
                width: composition.layoutWidth >= 1 ? composition.layoutWidth : size.width,
                height: composition.layoutHeight >= 1 ? composition.layoutHeight : size.height
            ),
            canvasSize: size
        ))
        .overlay(alignment: .bottom) {
            if showsShareMark {
                Text("MyTablo")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.32), in: Capsule())
                    .padding(.bottom, 16)
            }
        }
    }
}
