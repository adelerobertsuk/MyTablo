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
                            Label("Close Library", systemImage: "chevron.down")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddBook = true }) {
                        Label("Add book", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView(viewModel: viewModel)
            }
            .sheet(item: $editingBook) { book in
                EditBookView(viewModel: viewModel, book: book)
            }
        }
    }
}

struct AddBookView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var customCoverData: Data? = nil
    @State private var showBarcodeScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ISBN") {
                    TextField("Enter ISBN", text: $viewModel.isbnInput)
                        .keyboardType(.numberPad)

                    Button(action: { showBarcodeScanner = true }) {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                            Text("Scan Barcode")
                        }
                    }
                }

                Section("Custom Cover (optional)") {
                    CustomCoverPicker(coverImageData: $customCoverData)
                        .frame(maxWidth: .infinity)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
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
                        Task {
                            await viewModel.addBook(isbn: viewModel.isbnInput, customCoverData: customCoverData)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isbnInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack {
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
                .frame(height: 140)
                .frame(maxWidth: .infinity)
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
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Delete \(book.title)")
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

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Upload Clean Cover")
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            coverImageData = image.normalizedOrientation().jpegData(compressionQuality: 0.9) ?? data
                        }
                    }
                }
            }
        }
    }
}

private extension UIImage {
    /// Bakes imageOrientation into the pixel data as `.up`, since WidgetKit
    /// doesn't reliably honor a UIImage's orientation tag the way UIKit does.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
