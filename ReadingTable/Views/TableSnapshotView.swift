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
        .overlay(alignment: .bottomTrailing) {
            Text("Tablo")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .padding(.trailing, 8)
                .padding(.bottom, 10)
        }
    }
}
