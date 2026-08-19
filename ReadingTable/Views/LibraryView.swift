import SwiftUI
import PhotosUI
import ImageIO

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    var onDismiss: (() -> Void)? = nil
    var onSelect: (Book) -> Void
    var placesOnTap: Bool = false
    @Environment(\.palette) private var palette

    @State private var showAddBook = false
    @State private var editingBook: Book? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.books.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(palette.faint)
                        Text("Nothing on the shelf yet")
                            .displayTitleStyle()
                            .multilineTextAlignment(.center)
                        Text("Search by title or author.")
                            .captionStyle()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button {
                            Haptics.tap()
                            showAddBook = true
                        } label: {
                            Text("Add a book")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(palette.ink, in: Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 18, alignment: .top)], spacing: 20) {
                            ForEach(viewModel.books) { book in
                                BookTileView(book: book, onPlace: {
                                    Haptics.tap()
                                    onSelect(book)
                                }, placesOnTap: placesOnTap, onEdit: {
                                    editingBook = book
                                }, onDelete: {
                                    withAnimation {
                                        viewModel.deleteBook(book)
                                    }
                                }, onToggleCurrentlyReading: {
                                    viewModel.setCurrentlyReading(book, isCurrentlyReading: !book.isCurrentlyReading)
                                })
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(SanctuaryBackground())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onDismiss {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onDismiss) {
                            Image(systemName: "chevron.down")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.tap()
                        showAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fullScreenCover(isPresented: $showAddBook) {
                AddBookView(viewModel: viewModel)
                    .onDisappear {
                        viewModel.isbnInput = ""
                        viewModel.errorMessage = nil
                    }
            }
            .fullScreenCover(item: $editingBook) { book in
                EditBookView(viewModel: viewModel, book: book)
            }
        }
    }
}

private enum BookCamera: Equatable {
    case takePhoto
}

struct EditBookView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var title: String
    @State private var author: String
    @State private var customCoverData: Data?
    @State private var camera: BookCamera?
    @State private var reviewImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false

    init(viewModel: LibraryViewModel, book: Book) {
        self.viewModel = viewModel
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _customCoverData = State(initialValue: book.coverImageData)
    }

    var body: some View {
        if camera == .takePhoto {
            PhotoCoverFlowScreen { finalImage, isCutout, _ in
                customCoverData = finalImage.preparedForCover(asCutout: isCutout)
                camera = nil
            } onCancel: {
                camera = nil
            }
        } else if let reviewImage {
            BackgroundRemovalReviewScreen(originalImage: reviewImage) { finalImage, isCutout in
                customCoverData = finalImage.preparedForCover(asCutout: isCutout)
                self.reviewImage = nil
            } onCancel: {
                self.reviewImage = nil
            }
        } else {
            NavigationStack {
                ZStack {
                    SanctuaryBackground()
                    ScrollView {
                        VStack(spacing: 22) {
                            CoverPhotoCard(coverImageData: $customCoverData) {
                                Task {
                                    guard await CameraAccess.request() else { return }
                                    camera = .takePhoto
                                }
                            } onChoosePhoto: {
                                showPhotoPicker = true
                            }

                            editField(label: "Title", text: $title)
                            editField(label: "Author", text: $author)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
                .navigationTitle("Edit Book")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.updateBook(book, title: title, author: author, coverImageData: customCoverData)
                            dismiss()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
                .onChange(of: selectedPhoto) { _, item in
                    guard let item else { return }
                    Task {
                        guard let data = try? await item.loadTransferable(type: Data.self),
                              let image = UIImage.downsampled(from: data, maxPixelSize: 1600) else {
                            return
                        }
                        reviewImage = image
                        selectedPhoto = nil
                    }
                }
            }
        }
    }

    private func editField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.muted)
            TextField(label, text: text)
                .textInputAutocapitalization(.words)
                .font(.system(size: 17, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.line, lineWidth: 1)
                )
        }
    }
}

struct BookTileView: View {
    let book: Book
    var onPlace: (() -> Void)? = nil
    var placesOnTap: Bool = false
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onToggleCurrentlyReading: (() -> Void)? = nil
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    if let imageData = book.coverImageData,
                       BookLookupSession.isUsableCover(imageData),
                       let uiImage = UIImage(data: imageData) {
                        FillingCoverImage(uiImage: uiImage)
                    } else {
                        LinearGradient(
                            colors: [palette.muted, palette.ink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Text(book.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(10)
                        }
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .leading) {
                    LinearGradient(colors: [.black.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(palette.line, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 8, x: 2, y: 5)
                .onTapGesture {
                    if placesOnTap {
                        onPlace?()
                    }
                }
                .contextMenu {
                    if let onPlace {
                        Button("Place on table", systemImage: "plus") { onPlace() }
                    }
                    if let onToggleCurrentlyReading {
                        Button(
                            book.isCurrentlyReading ? "Not currently reading" : "Currently reading",
                            systemImage: book.isCurrentlyReading ? "bookmark.slash" : "bookmark"
                        ) { onToggleCurrentlyReading() }
                    }
                    if let onEdit {
                        Button("Edit", systemImage: "pencil") { onEdit() }
                    }
                    if let onDelete {
                        Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
                    }
                }
                .overlay(alignment: .topLeading) {
                    if book.isCurrentlyReading {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(palette.accent, in: Circle())
                            .padding(6)
                            .accessibilityLabel("Currently reading")
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.ink)
                    .lineLimit(2)
                Text(book.author)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
            .frame(minHeight: 42, alignment: .top)
        }
        .accessibilityHint(placesOnTap ? "Tap to place on the table. Touch and hold for more." : "Touch and hold for more.")
    }
}

/// `scaledToFill` inside an overlay does not actually fill unless the image
/// is given the overlay's exact size. Wes Anderson tiles were sitting short
/// in the book slot because of that.
struct FillingCoverImage: View {
    let uiImage: UIImage

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }
}

struct CoverPhotoCard: View {
    @Binding var coverImageData: Data?
    var onTakePhoto: () -> Void
    var onChoosePhoto: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 14) {
            Menu {
                Button("Take photo", systemImage: "camera", action: onTakePhoto)
                Button("Choose from photos", systemImage: "photo.on.rectangle", action: onChoosePhoto)
            } label: {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(width: 148)
                    .overlay { coverContent }
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .leading) {
                        LinearGradient(colors: [.black.opacity(0.18), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 7)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.line, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Take photo", systemImage: "camera", action: onTakePhoto)
                Button("Choose from photos", systemImage: "photo.on.rectangle", action: onChoosePhoto)
            } label: {
                Text(coverImageData == nil ? "Add a photo of the cover" : "Change photo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.ink)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var coverContent: some View {
        if let coverImageData,
           let uiImage = UIImage(data: coverImageData) {
            FillingCoverImage(uiImage: uiImage)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "camera")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(palette.faint)
                Text("Cover")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.faint)
            }
        }
    }
}

extension UIImage {
    /// Bakes imageOrientation into the pixel data as `.up` (WidgetKit doesn't
    /// reliably honor a UIImage's orientation tag) and forces a standard RGB
    /// color space — VisionKit document scans can come back in a non-standard
    /// color space that renders inverted/black if saved untouched.
    func normalizedOrientation() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// Reads a photo at a capped pixel size so a full camera image never
    /// gets decoded at original resolution. Orientation is applied as part
    /// of the thumbnail, so callers do not need `normalizedOrientation()`.
    static func downsampled(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Shrinks a cover so a camera photo cannot take down a smaller iPad.
    /// Cutouts stay PNG so transparent pixels are not flattened into a white box.
    func preparedForCover(asCutout: Bool) -> Data? {
        let source = asCutout ? trimmedToOpaqueContent() : self
        if asCutout {
            let small = source.downsampledPreservingAlpha(maxPixelSize: 1600)
            return small.pngData()
        }
        guard let data = source.jpegData(compressionQuality: 0.95) ?? source.pngData(),
              let small = UIImage.downsampled(from: data, maxPixelSize: 1600) else {
            return source.jpegData(compressionQuality: 0.82)
        }
        return small.jpegData(compressionQuality: 0.82)
    }

    var hasAlphaChannel: Bool {
        guard let alpha = cgImage?.alphaInfo else { return false }
        switch alpha {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
            return true
        default:
            return false
        }
    }

    /// Crops away empty transparent margins so a cut-out cover is just the book.
    func trimmedToOpaqueContent(padding: CGFloat = 0) -> UIImage {
        guard let cgImage else { return self }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return self }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        let alphaThreshold: UInt8 = 48

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
                guard alpha > alphaThreshold else { continue }
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }

        guard maxX > minX, maxY > minY else { return self }

        let padX = Int(CGFloat(maxX - minX) * padding)
        let padY = Int(CGFloat(maxY - minY) * padding)
        let cropX = max(0, minX - padX)
        let cropY = max(0, minY - padY)
        let cropWidth = min(width - cropX, (maxX + padX) - cropX + 1)
        let cropHeight = min(height - cropY, (maxY + padY) - cropY + 1)
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        guard let cropped = cgImage.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }

    func downsampledPreservingAlpha(maxPixelSize: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxPixelSize, longest > 0 else { return self }
        let scaleFactor = maxPixelSize / longest
        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
