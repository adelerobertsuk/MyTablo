import SwiftUI
import UIKit
import LinkPresentation
import WidgetKit

private let tableShareMessage = "This is MyTablo. Come make yours."

struct TabloView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject var compositionViewModel: CoffeeTableCompositionViewModel
    @Environment(\.palette) private var palette
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var controlsRevealed = false
    @State private var showLibrary = false
    @State private var showStyle = false
    @State private var sharePNGData: Data?
    @State private var showShareSheet = false
    @State private var tableSize: CGSize = CGSize(width: 402, height: 874)

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                TableSurfaceView(
                    imageName: compositionViewModel.currentComposition?.surfaceImageName ?? "Kate-table-WhitePlaster",
                    size: geometry.size
                )
                .onAppear {
                    tableSize = geometry.size
                    compositionViewModel.ensureLayoutSize(matching: geometry.size)
                }
                .onChange(of: geometry.size) { _, newSize in
                    tableSize = newSize
                    compositionViewModel.ensureLayoutSize(matching: newSize)
                }
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
                            .frame(height: isRegularLayout ? 160 : 110)
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
        .environment(\.tableLayout, currentTableLayout)
        .fullScreenCover(isPresented: $showLibrary, onDismiss: refreshShareImage) {
            LibraryView(viewModel: libraryViewModel, onDismiss: { showLibrary = false }) { selectedBook in
                compositionViewModel.addExistingBook(selectedBook, at: currentTableLayout.stored(newItemPosition))
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
            // iPad's bottom tap strip is easy to miss on a 13-inch screen.
            // Show the bar up front; tap the table still hides it for photos.
            if tableIsEmpty || isRegularLayout {
                controlsRevealed = true
            }
            refreshShareImage()
        }
    }

    private var isRegularLayout: Bool { horizontalSizeClass == .regular }

    private var currentTableLayout: TableLayout {
        TableLayout(
            layoutSize: compositionViewModel.resolvedLayoutSize(for: tableSize),
            canvasSize: tableSize
        )
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
        // A 13-inch iPad at full screen scale is a 4K-class bitmap. Cap the
        // long edge so Share appears quickly and does not spike memory.
        let longestSide = max(tableSize.width, tableSize.height)
        let maxPixels: CGFloat = 2048
        renderer.scale = longestSide > 0 ? min(2, maxPixels / longestSide) : 1

        DispatchQueue.main.async {
            guard let image = renderer.uiImage else { return }
            self.sharePNGData = image.pngData()
            WidgetSnapshot.publish(image)
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

            if let sharePNGData {
                Button {
                    Haptics.tap()
                    showShareSheet = true
                } label: {
                    controlItem(symbol: "square.and.arrow.up", title: "Share") {
                        EmptyView()
                    }
                }
                .accessibilityLabel("Share")
                .background {
                    TableSharePresenter(isPresented: $showShareSheet, pngData: sharePNGData)
                }
            }
        }
        .foregroundStyle(palette.ink)
        .padding(.horizontal, isRegularLayout ? 36 : 30)
        .padding(.vertical, isRegularLayout ? 18 : 16)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(palette.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .padding(.bottom, isRegularLayout ? 32 : 28)
    }

    private func controlItem<Badge: View>(
        symbol: String,
        title: String,
        @ViewBuilder badge: () -> Badge
    ) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: isRegularLayout ? 24 : 20, weight: .medium))
                badge()
            }
            Text(title)
                .font(.system(size: isRegularLayout ? 13 : 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: isRegularLayout ? 64 : 56, minHeight: 44)
    }
}

/// ShareLink's preview title shows in the sheet but never reaches Messages.
/// A UIActivityItemSource can send the image everywhere, and the sentence
/// only to Messages and Mail, so it is not duplicated and not saved as a file.
private struct TableSharePresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let pngData: Data

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented, !context.coordinator.didPresent {
            guard let image = UIImage(data: pngData) else {
                DispatchQueue.main.async { isPresented = false }
                return
            }
            context.coordinator.didPresent = true
            let controller = UIActivityViewController(
                activityItems: [
                    TableShareImageSource(image: image, icon: UIImage(named: "MyTabloIcon")),
                    TableShareTextSource(text: tableShareMessage)
                ],
                applicationActivities: nil
            )
            controller.completionWithItemsHandler = { _, _, _, _ in
                context.coordinator.didPresent = false
                isPresented = false
            }
            if let popover = controller.popoverPresentationController {
                popover.sourceView = uiViewController.view
                popover.sourceRect = CGRect(
                    x: uiViewController.view.bounds.midX,
                    y: 0,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
            }
            uiViewController.present(controller, animated: true)
        } else if !isPresented, context.coordinator.didPresent {
            context.coordinator.didPresent = false
            uiViewController.presentedViewController?.dismiss(animated: true)
        }
    }

    final class Coordinator {
        var didPresent = false
    }
}

private final class TableShareImageSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let icon: UIImage?

    init(image: UIImage, icon: UIImage?) {
        self.image = image
        self.icon = icon
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = tableShareMessage
        metadata.imageProvider = NSItemProvider(object: image)
        if let icon {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}

private final class TableShareTextSource: NSObject, UIActivityItemSource {
    let text: String

    init(text: String) {
        self.text = text
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        if activityType == .message || activityType == .mail {
            return text
        }
        return nil
    }
}
