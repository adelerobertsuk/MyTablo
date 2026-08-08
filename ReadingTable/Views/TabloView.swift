import SwiftUI

struct TabloView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject var compositionViewModel: CoffeeTableCompositionViewModel

    @State private var controlsRevealed = false
    @State private var showLibrary = false
    @State private var showStyle = false
    @State private var shareImage: UIImage?

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image(compositionViewModel.currentComposition?.surfaceImageName ?? "Kate-table-WhitePlaster")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.04, anchor: .bottom)
                    .clipped()
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
                        revealedControlBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    controlsRevealed = true
                                }
                                refreshShareImage()
                            }
                    }
                }
                .frame(height: 110)
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

    private func refreshShareImage() {
        guard let composition = compositionViewModel.currentComposition else { return }
        let renderer = ImageRenderer(content: TableSnapshotView(composition: composition))
        renderer.scale = UIScreen.main.scale

        DispatchQueue.main.async {
            self.shareImage = renderer.uiImage
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
                }
            }

            Button(action: { showStyle = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 22))
                    Text("Style")
                        .font(.caption2)
                }
            }

            if let shareImage {
                ShareLink(
                    item: Image(uiImage: shareImage),
                    message: Text("Here's what's on my Tablo right now 📚✨"),
                    preview: SharePreview("Tablo", image: Image(uiImage: shareImage))
                ) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22))
                        Text("Share")
                            .font(.caption2)
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
