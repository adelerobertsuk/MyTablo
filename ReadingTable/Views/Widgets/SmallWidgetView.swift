import SwiftUI

/// Placeholder for the widget's book data. Will be replaced by a real
/// WidgetKit TimelineEntry once we wire up data sharing between the app
/// and the widget extension.
struct CurrentReadPreview {
    let title: String
    let author: String
    let coverImage: UIImage?

    static let sample = CurrentReadPreview(
        title: "The Secret History",
        author: "Donna Tartt",
        coverImage: nil
    )
}

/// Layout for the Small (2x2) home screen widget: a full-bleed book cover
/// with the title/author legible over a bottom gradient scrim.
struct SmallWidgetView: View {
    let book: CurrentReadPreview
    private let palette = Palette.light

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(book.author)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let coverImage = book.coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                palette.ink
                EllipticalGradient(
                    gradient: Gradient(colors: [palette.accentGlow, Color.clear]),
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.7
                )
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
    }
}

#Preview("With Cover Placeholder") {
    SmallWidgetView(book: .sample)
        .frame(width: 158, height: 158)
}

#Preview("No Cover Fallback") {
    SmallWidgetView(
        book: CurrentReadPreview(
            title: "A Book With A Fairly Long Title",
            author: "Unknown Author",
            coverImage: nil
        )
    )
    .frame(width: 158, height: 158)
}
