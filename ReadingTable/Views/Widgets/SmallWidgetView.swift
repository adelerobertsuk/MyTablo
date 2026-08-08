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

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(book.author)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let coverImage = book.coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.35, green: 0.25, blue: 0.2),
                        Color(red: 0.15, green: 0.1, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.3))
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
