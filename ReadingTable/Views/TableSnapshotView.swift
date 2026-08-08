import SwiftUI

struct TableSnapshotView: View {
    let composition: CoffeeTableComposition
    var size: CGSize = CGSize(width: 402, height: 874)

    var body: some View {
        ZStack {
            Image(composition.surfaceImageName)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .scaleEffect(1.04, anchor: .bottom)
                .clipped()

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
        .overlay(alignment: .bottom) {
            Text("Made on MyTablo")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35), in: Capsule())
                .padding(.bottom, 14)
        }
    }
}
