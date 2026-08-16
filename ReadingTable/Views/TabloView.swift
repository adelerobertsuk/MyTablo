import SwiftUI
import UniformTypeIdentifiers

private struct ShareableTableSnapshot: Transferable {
    let pngData: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shareable in
            shareable.pngData
        }
        .suggestedFileName("MyTablo.png")
    }
}

struct TabloView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject var compositionViewModel: CoffeeTableCompositionViewModel
    @Environment(\.palette) private var palette

    @State private var controlsRevealed = false
    @State private var showLibrary = false
    @State private var showStyle = false
    @State private var shareImage: UIImage?
    @State private var sharePNGData: Data?
    @State private var tableSize: CGSize = CGSize(width: 402, height: 874)

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image(compositionViewModel.currentComposition?.surfaceImageName ?? "Kate-table-WhitePlaster")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.04, anchor: .bottom)
                    .clipped()
                    .onAppear { tableSize = geometry.size }
                    .onChange(of: geometry.size) { _, newSize in tableSize = newSize }
            }
            .ignoresSafeArea()

            if let composition = compositionViewModel.currentComposition {
                ForEach(composition.items.sorted(by: { $0.zIndex < $1.zIndex })) { composedBook in
                    TableBookView(composedBook: composedBook, isInteractive: false)
                        .zIndex(composedBook.zIndex)
                }

                ForEach(composition.decorations.sorted(by: { $0.zIndex < $1.zIndex })) { decoration in
                    DecorationView(decoration: decoration, isInteractive: false)
                        .zIndex(decoration.zIndex)
                }
            }

            Color.clear
                .contentShape(Rectangle())
                .accessibilityLabel("Your table")
                .accessibilityHint("Tap the bottom of the screen for Library, Arrange, and Share.")
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        controlsRevealed = false
                    }
                }

            VStack {
                Spacer()

                if tableIsEmpty && controlsRevealed {
                    Text("This table is yours. Add a book to begin.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.38), in: Capsule())
                        .padding(.horizontal, 28)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }

                ZStack {
                    if controlsRevealed {
                        VStack(spacing: 8) {
                            if let notice = sharingPrivacyNotice {
                                Text(notice)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.black.opacity(0.42), in: Capsule())
                                    .padding(.horizontal, 24)
                            }
                            revealedControlBar
                        }
                            .frame(minHeight: 110)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(height: 110)
                            .accessibilityLabel("Show table controls")
                            .accessibilityAddTraits(.isButton)
                            .onTapGesture {
                                Haptics.tap()
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    controlsRevealed = true
                                }
                                refreshShareImage()
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .fullScreenCover(isPresented: $showLibrary, onDismiss: refreshShareImage) {
            LibraryView(viewModel: libraryViewModel, onDismiss: { showLibrary = false }) { selectedBook in
                compositionViewModel.addExistingBook(selectedBook, at: newItemPosition)
            }
        }
        .fullScreenCover(isPresented: $showStyle, onDismiss: refreshShareImage) {
            StyleView(
                libraryViewModel: libraryViewModel,
                compositionViewModel: compositionViewModel,
                onDismiss: { showStyle = false }
            )
        }
        .onAppear {
            if tableIsEmpty {
                controlsRevealed = true
            }
            refreshShareImage()
        }
    }

    private var tableIsEmpty: Bool {
        let composition = compositionViewModel.currentComposition
        return (composition?.items.isEmpty ?? true) && (composition?.decorations.isEmpty ?? true)
    }

    private var newItemPosition: CGPoint {
        CGPoint(
            x: tableSize.width / 2 + Double.random(in: -30...30),
            y: tableSize.height / 2 + Double.random(in: -30...30)
        )
    }

    private var hasPhotoDecorations: Bool {
        compositionViewModel.currentComposition?.decorations.contains(where: { $0.isPhotoFrame }) ?? false
    }

    private var hasCalendarDecorations: Bool {
        compositionViewModel.currentComposition?.decorations.contains(where: { $0.isCalendar }) ?? false
    }

    /// Only shown when the table actually contains sensitive live content — not for sticky notes
    /// or ordinary stickers alone.
    private var sharingPrivacyNotice: String? {
        switch (hasPhotoDecorations, hasCalendarDecorations) {
        case (true, true):
            return "Sharing includes any personal photos and calendar events visible on your table"
        case (true, false):
            return "Sharing includes any personal photos visible on your table"
        case (false, true):
            return "Sharing includes any calendar events visible on your table"
        case (false, false):
            return nil
        }
    }

    private func refreshShareImage() {
        guard let composition = compositionViewModel.currentComposition else { return }
        let renderer = ImageRenderer(content: TableSnapshotView(composition: composition, size: tableSize))
        renderer.scale = UIScreen.main.scale

        DispatchQueue.main.async {
            self.shareImage = renderer.uiImage
            self.sharePNGData = renderer.uiImage?.pngData()
        }
    }

    private var revealedControlBar: some View {
        HStack(spacing: 28) {
            Button {
                Haptics.tap()
                showLibrary = true
            } label: {
                controlItem(symbol: "books.vertical.fill", title: "Library") {
                    if !libraryViewModel.books.isEmpty {
                        Text("\(libraryViewModel.books.count)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(palette.accent, in: Capsule())
                            .offset(x: 10, y: -8)
                    }
                }
            }
            .accessibilityLabel("Library")
            .frame(minHeight: 44)

            Button {
                Haptics.tap()
                showStyle = true
            } label: {
                controlItem(symbol: "square.and.pencil", title: "Arrange") {
                    EmptyView()
                }
            }
            .accessibilityLabel("Arrange")
            .frame(minHeight: 44)

            if let shareImage, let sharePNGData {
                ShareLink(
                    item: ShareableTableSnapshot(pngData: sharePNGData),
                    message: Text("Here's my table."),
                    preview: SharePreview("MyTablo", image: Image(uiImage: shareImage))
                ) {
                    controlItem(symbol: "square.and.arrow.up", title: "Share") {
                        EmptyView()
                    }
                }
            }
        }
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(palette.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .padding(.bottom, 28)
    }

    private func controlItem<Badge: View>(
        symbol: String,
        title: String,
        @ViewBuilder badge: () -> Badge
    ) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                badge()
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 56, minHeight: 44)
    }
}
