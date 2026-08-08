import SwiftUI
import PhotosUI

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    var onDismiss: (() -> Void)? = nil
    var onSelect: (Book) -> Void

    @State private var showAddBook = false
    @State private var editingBook: Book? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.books.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Library is empty")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Add a book using an ISBN to get started")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 16) {
                            ForEach(viewModel.books) { book in
                                VStack(spacing: 8) {
                                    BookTileView(book: book, onEdit: {
                                        editingBook = book
                                    }, onDelete: {
                                        withAnimation {
                                            viewModel.deleteBook(book)
                                        }
                                    }, onToggleCurrentlyReading: {
                                        viewModel.setCurrentlyReading(book, isCurrentlyReading: !book.isCurrentlyReading)
                                    })

                                    Button(action: { onSelect(book) }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add").font(.caption).fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(8)
                                        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
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
                    Button(action: { showAddBook = true }) {
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
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onToggleCurrentlyReading: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
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
                                gradient: Gradient(colors: [Color.gray, Color.black]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .leading) {
                    LinearGradient(colors: [.black.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 4)
                .onTapGesture {
                    onEdit?()
                }

                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 18, height: 18))
                    }
                    .padding(6)
                }

                if let onToggleCurrentlyReading {
                    Button(action: onToggleCurrentlyReading) {
                        Image(systemName: book.isCurrentlyReading ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(book.isCurrentlyReading ? Color.accentColor : Color.black.opacity(0.45)))
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityLabel(book.isCurrentlyReading ? "Currently reading" : "Mark as currently reading")
                }
            }

            Text(book.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            Text(book.author)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct CustomCoverPicker: View {
    @Binding var coverImageData: Data?
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
                        .overlay(
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
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
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
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
                        loadError = "Couldn't load that photo — try picking a different one."
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
