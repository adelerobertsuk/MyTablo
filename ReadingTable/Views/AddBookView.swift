import SwiftUI
import PhotosUI

struct AddBookView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private enum Stage {
        case find
        case found
        case photo
    }

    private enum Camera: Equatable {
        case barcode
        case photo
    }

    @State private var stage: Stage = .find
    @State private var isbn: String = ""
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var coverData: Data?
    @State private var camera: Camera?
    @State private var reviewImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        if camera == .barcode {
            BarcodeScannerScreen { scannedCode in
                isbn = LibraryViewModel.sanitizeISBN(scannedCode)
                camera = nil
                Haptics.success()
                Task { await lookUp() }
            } onCancel: {
                camera = nil
            }
        } else if camera == .photo {
            PhotoCoverFlowScreen { finalImage, isCutout, original in
                applyPhoto(finalImage, isCutout: isCutout, readTextFrom: original)
                camera = nil
            } onCancel: {
                camera = nil
            }
        } else if let reviewImage {
            BackgroundRemovalReviewScreen(originalImage: reviewImage) { finalImage, isCutout in
                applyPhoto(finalImage, isCutout: isCutout, readTextFrom: reviewImage)
                self.reviewImage = nil
            } onCancel: {
                self.reviewImage = nil
            }
        } else {
            form
        }
    }

    private var form: some View {
        NavigationStack {
            ZStack {
                SanctuaryBackground()
                ScrollView {
                    VStack(spacing: 28) {
                        switch stage {
                        case .find:
                            findStage
                        case .found:
                            foundStage
                        case .photo:
                            photoStage
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await loadPickedPhoto(item) }
            }
        }
    }

    private var findStage: some View {
        VStack(spacing: 22) {
            Text("Scan the barcode on the back of the book.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Button {
                Haptics.tap()
                Task {
                    guard await CameraAccess.request() else {
                        viewModel.errorMessage = "Camera access is needed to scan a barcode. You can type the ISBN instead."
                        return
                    }
                    camera = .barcode
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 20, weight: .medium))
                    Text("Scan barcode")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(palette.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .frame(minHeight: 52)

            HStack(spacing: 12) {
                Rectangle().fill(palette.line).frame(height: 1)
                Text("or type the ISBN")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .fixedSize()
                Rectangle().fill(palette.line).frame(height: 1)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("ISBN")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.muted)
                TextField("978…", text: $isbn)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 17, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.line, lineWidth: 1)
                    )
            }

            Button {
                Haptics.tap()
                Task { await lookUp() }
            } label: {
                Text(viewModel.isLoading ? "Finding your book" : "Look up")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        lookUpEnabled ? palette.accent : palette.faint,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .disabled(!lookUpEnabled || viewModel.isLoading)
            .frame(minHeight: 52)

            if viewModel.isLoading {
                findingCard
            }

            if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button("Add a photo instead") {
                    Haptics.tap()
                    viewModel.errorMessage = nil
                    stage = .photo
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.ink)
            }
        }
    }

    private var foundStage: some View {
        VStack(spacing: 22) {
            CoverPhotoCard(coverImageData: $coverData) {
                openCamera()
            } onChoosePhoto: {
                showPhotoPicker = true
            }

            if coverData == nil {
                Text("We found the book. Add a photo of the cover if you have one.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .multilineTextAlignment(.center)
            }

            field(label: "Title", text: $title, placeholder: "Title")
            field(label: "Author", text: $author, placeholder: "Author")

            Button {
                Haptics.success()
                saveAndDismiss()
            } label: {
                Text("Add to library")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        title.trimmingCharacters(in: .whitespaces).isEmpty ? palette.faint : palette.accent,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .frame(minHeight: 52)

            Button("Try another book") {
                Haptics.tap()
                resetToFind()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(palette.muted)
        }
    }

    private var photoStage: some View {
        VStack(spacing: 22) {
            Text("Add a photo of the front cover. We'll fill in the title if we can.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            CoverPhotoCard(coverImageData: $coverData) {
                openCamera()
            } onChoosePhoto: {
                showPhotoPicker = true
            }

            field(label: "Title", text: $title, placeholder: "Title")
            field(label: "Author", text: $author, placeholder: "Author")

            Button {
                Haptics.success()
                saveAndDismiss()
            } label: {
                Text("Add to library")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        title.trimmingCharacters(in: .whitespaces).isEmpty ? palette.faint : palette.accent,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .frame(minHeight: 52)

            Button("Scan a barcode instead") {
                Haptics.tap()
                resetToFind()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(palette.muted)
        }
    }

    private var findingCard: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.card)
                .frame(width: 108, height: 162)
                .overlay {
                    ProgressView()
                        .tint(palette.accent)
                }
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            Text("Finding your book")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.muted)
        }
        .padding(.top, 8)
    }

    private func field(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.muted)
            TextField(placeholder, text: text)
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

    private var lookUpEnabled: Bool {
        LibraryViewModel.sanitizeISBN(isbn).count >= 10
    }

    private func lookUp() async {
        viewModel.isbnInput = isbn
        if let result = await viewModel.lookupBook(isbn: isbn) {
            isbn = result.isbn
            title = result.title
            author = result.author
            coverData = result.coverImageData
            stage = .found
            Haptics.success()
        }
    }

    private func openCamera() {
        Task {
            guard await CameraAccess.request() else {
                viewModel.errorMessage = "Camera access is needed to photograph a cover."
                return
            }
            camera = .photo
        }
    }

    private func applyPhoto(_ image: UIImage, isCutout: Bool, readTextFrom original: UIImage) {
        coverData = image.preparedForCover(asCutout: isCutout)
        Haptics.tap()
        Task {
            guard let guess = await recognizeCoverText(from: original) else { return }
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !guess.title.isEmpty {
                title = BookText.displayName(guess.title)
            }
            if author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !guess.author.isEmpty {
                author = BookText.displayName(guess.author)
            }
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        defer { selectedPhoto = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage.downsampled(from: data, maxPixelSize: 1600) else {
            return
        }
        await MainActor.run {
            reviewImage = image
        }
    }

    private func saveAndDismiss() {
        viewModel.saveBook(
            isbn: LibraryViewModel.sanitizeISBN(isbn),
            title: title,
            author: author,
            coverImageData: coverData
        )
        if viewModel.errorMessage == nil {
            dismiss()
        }
    }

    private func resetToFind() {
        stage = .find
        title = ""
        author = ""
        coverData = nil
        viewModel.errorMessage = nil
    }
}
