import SwiftUI
import UIKit

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
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
