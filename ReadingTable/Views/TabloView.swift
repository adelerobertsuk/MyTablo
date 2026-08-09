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
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        controlsRevealed = false
                    }
                }

            VStack {
                Spacer()

                ZStack {
                    if controlsRevealed {
                        VStack(spacing: 8) {
                            if let notice = sharingPrivacyNotice {
                                Text(notice)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.35), in: Capsule())
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
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
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
                compositionViewModel.addExistingBook(selectedBook)
            }
        }
        .fullScreenCover(isPresented: $showStyle, onDismiss: refreshShareImage) {
            StyleView(
                libraryViewModel: libraryViewModel,
                compositionViewModel: compositionViewModel,
                onDismiss: { showStyle = false }
            )
        }
        .onAppear(perform: refreshShareImage)
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
        HStack(spacing: 32) {
            Button(action: { showLibrary = true }) {
                VStack(spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 22))
                        Text("\(libraryViewModel.books.count)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(4)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                            .offset(x: 12, y: -8)
                    }
                    Text("Library")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Button(action: { showStyle = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 22))
                    Text("Style")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            if let shareImage, let sharePNGData {
                ShareLink(
                    item: ShareableTableSnapshot(pngData: sharePNGData),
                    message: Text("Here's what's on MyTablo right now 📚✨"),
                    preview: SharePreview("", image: Image(uiImage: shareImage))
                ) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22))
                        Text("Share")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 24)
    }
}
