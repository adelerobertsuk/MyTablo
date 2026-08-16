import SwiftUI
import PhotosUI

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    var onDismiss: (() -> Void)? = nil
    var onSelect: (Book) -> Void
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
                        Text("Add a book by ISBN, scan the barcode, or type the title.")
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
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 18)], spacing: 20) {
                            ForEach(viewModel.books) { book in
                                BookTileView(book: book, onPlace: {
                                    Haptics.tap()
                                    onSelect(book)
                                }, onEdit: {
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
            .sheet(isPresented: $showAddBook, onDismiss: { viewModel.isbnInput = "" }) {
                AddBookView(viewModel: viewModel)
            }
            .sheet(item: $editingBook) { book in
                EditBookView(viewModel: viewModel, book: book)
            }
        }
    }
}

private enum AddBookMode: String, CaseIterable {
    case isbn = "By ISBN"
    case manual = "Manual"
}

struct AddBookView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var customCoverData: Data? = nil
    @State private var showBarcodeScanner = false
    @State private var mode: AddBookMode = .isbn
    @State private var manualTitle: String = ""
    @State private var manualAuthor: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Add Method", selection: $mode) {
                    ForEach(AddBookMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)

                if mode == .isbn {
                    Section("ISBN") {
                        TextField("Enter ISBN", text: $viewModel.isbnInput)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button(action: { showBarcodeScanner = true }) {
                            HStack {
                                Image(systemName: "barcode.viewfinder")
                                Text("Scan Barcode")
                            }
                        }
                    }
                } else {
                    Section("Title") {
                        TextField("Title", text: $manualTitle)
                    }
                    Section("Author (optional)") {
                        TextField("Author", text: $manualAuthor)
                    }
                }

                Section(mode == .isbn ? "Custom Cover (optional)" : "Cover (optional)") {
                    CustomCoverPicker(coverImageData: $customCoverData)
                        .frame(maxWidth: .infinity)
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                        if mode == .isbn {
                            Button("Enter details manually instead") {
                                viewModel.errorMessage = nil
                                mode = .manual
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(SanctuaryBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        switch mode {
                        case .isbn:
                            Task {
                                await viewModel.addBook(isbn: viewModel.isbnInput, customCoverData: customCoverData)
                                if viewModel.errorMessage == nil {
                                    dismiss()
                                }
                            }
                        case .manual:
                            viewModel.addBookManually(title: manualTitle, author: manualAuthor, coverImageData: customCoverData)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isAddDisabled)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                BarcodeScannerScreen { scannedCode in
                    viewModel.isbnInput = scannedCode
                }
            }
        }
    }

    private var isAddDisabled: Bool {
        switch mode {
        case .isbn:
            return viewModel.isbnInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading
        case .manual:
            return manualTitle.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

struct EditBookView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let book: Book
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var author: String
    @State private var customCoverData: Data?

    init(viewModel: LibraryViewModel, book: Book) {
        self.viewModel = viewModel
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _customCoverData = State(initialValue: book.coverImageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                }

                Section("Author") {
                    TextField("Author", text: $author)
                }

                Section("Cover") {
                    CustomCoverPicker(coverImageData: $customCoverData)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(SanctuaryBackground())
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
        }
    }
}

struct BookTileView: View {
    let book: Book
    var onPlace: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onToggleCurrentlyReading: (() -> Void)? = nil
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(120.0 / 170.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    if let imageData = book.coverImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
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
                    onPlace?()
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
                    .lineLimit(1)
                Text(book.author)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
        }
        .accessibilityHint("Tap to place on the table. Touch and hold for more.")
    }
}

struct CustomCoverPicker: View {
    @Binding var coverImageData: Data?
    @Environment(\.palette) private var palette
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showScanner = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var pendingReviewImage: UIImage?
    @State private var showReview = false
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if let coverImageData, let uiImage = UIImage(data: coverImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.track)
                        .overlay(
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 24))
                                .foregroundStyle(palette.faint)
                        )
                }
            }
            .frame(width: 120, height: 170)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )

            Menu {
                Button {
                    loadError = nil
                    showScanner = true
                } label: {
                    Label("Scan Cover", systemImage: "viewfinder")
                }

                Button {
                    loadError = nil
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }

                Button {
                    loadError = nil
                    pendingReviewImage = nil
                    showPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Cover")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(palette.ink, in: Capsule())
                .foregroundStyle(.white)
            }

            if let loadError {
                Text(loadError)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            CameraCoverCaptureScreen { image in
                coverImageData = image.normalizedOrientation().jpegData(compressionQuality: 0.9)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureFlowScreen { finalImage, isCutout in
                let normalized = finalImage.normalizedOrientation()
                coverImageData = isCutout ? normalized.pngData() : normalized.jpegData(compressionQuality: 0.9)
                showCamera = false
            } onCancel: {
                showCamera = false
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: showPhotoPicker) { _, isPresented in
            if !isPresented {
                presentReviewIfNeeded()
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    await MainActor.run {
                        pendingReviewImage = image
                        presentReviewIfNeeded()
                    }
                } catch {
                    await MainActor.run {
                        loadError = "Couldn't load that photo. Try picking a different one."
                        selectedItem = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showReview) {
            if let pendingReviewImage {
                BackgroundRemovalReviewScreen(originalImage: pendingReviewImage) { finalImage, isCutout in
                    let normalized = finalImage.normalizedOrientation()
                    coverImageData = isCutout ? normalized.pngData() : normalized.jpegData(compressionQuality: 0.9)
                    showReview = false
                    self.pendingReviewImage = nil
                } onCancel: {
                    showReview = false
                    self.pendingReviewImage = nil
                }
            }
        }
    }

    /// `showPhotoPicker` and `showReview` are separate full-screen covers on the same view —
    /// presenting one while the other is still animating out leaves SwiftUI unable to animate
    /// both transitions at once, which showed up as a stuck blank screen. Only flip to the
    /// review screen once the photo picker has actually finished closing.
    private func presentReviewIfNeeded() {
        guard pendingReviewImage != nil, !showPhotoPicker, !showReview else { return }
        showReview = true
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
}
