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
    @State private var query: String = ""
    @State private var isbn: String = ""
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var coverData: Data?
    @State private var camera: Camera?
    @State private var reviewImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var hits: [LibraryViewModel.LookedUpBook] = []
    @State private var showISBN = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        if camera == .barcode {
            BarcodeScannerScreen { scannedCode in
                isbn = LibraryViewModel.sanitizeISBN(scannedCode)
                camera = nil
                Haptics.success()
                Task { await lookUpISBN() }
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
            Text("Search by title or author.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Book")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.muted)
                TextField("Artist's Way, Julia Cameron", text: $query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .font(.system(size: 17, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.line, lineWidth: 1)
                    )
                    .onSubmit {
                        Task { await search() }
                    }
            }

            Button {
                Haptics.tap()
                searchFocused = false
                Task { await search() }
            } label: {
                Text(viewModel.isLoading ? "Finding your book" : "Find")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        searchEnabled ? palette.accent : palette.faint,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .disabled(!searchEnabled || viewModel.isLoading)
            .frame(minHeight: 52)

            if viewModel.isLoading {
                findingCard
            }

            if !hits.isEmpty, !viewModel.isLoading {
                VStack(spacing: 10) {
                    ForEach(hits) { hit in
                        Button {
                            Haptics.tap()
                            applyHit(hit)
                        } label: {
                            searchRow(hit)
                        }
                        .buttonStyle(.plain)
                    }
                }
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

            HStack(spacing: 12) {
                Rectangle().fill(palette.line).frame(height: 1)
                Text("or")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .fixedSize()
                Rectangle().fill(palette.line).frame(height: 1)
            }
            .padding(.top, 4)

            secondaryButton(symbol: "camera.fill", title: "Photograph the cover") {
                openCamera()
            }

            secondaryButton(symbol: "photo.on.rectangle", title: "Choose a photo") {
                showPhotoPicker = true
            }

            Button {
                Haptics.tap()
                Task {
                    guard await CameraAccess.request() else {
                        viewModel.errorMessage = "Camera access is needed to scan a barcode. You can type the title instead."
                        return
                    }
                    camera = .barcode
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 16, weight: .medium))
                    Text("Scan barcode")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.line, lineWidth: 1)
                )
            }

            Button {
                Haptics.tap()
                withAnimation(.easeOut(duration: 0.2)) {
                    showISBN.toggle()
                }
            } label: {
                Text(showISBN ? "Hide ISBN" : "I have the ISBN")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.muted)
            }

            if showISBN {
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
                    Task { await lookUpISBN() }
                } label: {
                    Text("Look up ISBN")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.line, lineWidth: 1)
                        )
                }
                .disabled(LibraryViewModel.sanitizeISBN(isbn).count < 10 || viewModel.isLoading)
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

            Button("Search another book") {
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

            Button("Search by title instead") {
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

    private func secondaryButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.line, lineWidth: 1)
            )
        }
    }

    private func searchRow(_ hit: LibraryViewModel.LookedUpBook) -> some View {
        HStack(spacing: 14) {
            Group {
                if let data = hit.coverImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(palette.faint.opacity(0.35))
                }
            }
            .frame(width: 44, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(hit.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(hit.author)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.faint)
        }
        .padding(12)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        )
    }

    private var searchEnabled: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func search() async {
        hits = []
        let results = await viewModel.searchBooks(query: query)
        if results.count == 1, let only = results.first {
            applyHit(only)
            return
        }
        hits = results
        if !results.isEmpty {
            Haptics.success()
        }
    }

    private func lookUpISBN() async {
        if let result = await viewModel.lookupBook(isbn: isbn) {
            applyHit(result)
        }
    }

    private func applyHit(_ hit: LibraryViewModel.LookedUpBook) {
        isbn = hit.isbn
        title = hit.title
        author = hit.author
        coverData = hit.coverImageData
        hits = []
        stage = .found
        Haptics.success()
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
        if stage == .find {
            stage = .photo
        }
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
            isbn: LibraryViewModel.looksLikeISBN(isbn) ? LibraryViewModel.sanitizeISBN(isbn) : isbn,
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
        query = ""
        isbn = ""
        title = ""
        author = ""
        coverData = nil
        hits = []
        showISBN = false
        viewModel.errorMessage = nil
    }
}
