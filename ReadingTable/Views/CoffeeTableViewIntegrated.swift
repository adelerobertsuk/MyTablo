import SwiftUI
import SwiftData
import PhotosUI

struct StickyNoteEditorContext: Identifiable {
    let id = UUID()
    let decoration: Decoration?
}

struct StyleView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject var compositionViewModel: CoffeeTableCompositionViewModel
    var onDismiss: () -> Void = {}
    @Environment(\.palette) private var palette

    @State private var showLibraryPicker = false
    @State private var showStickerPicker = false
    @State private var stickyNoteEditorContext: StickyNoteEditorContext?
    @State private var snapToGridEnabled = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var editingPhotoDecoration: Decoration?
    @State private var canvasSize: CGSize = CGSize(width: 402, height: 874)
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Center of the actual table canvas, with a little jitter so repeated
    /// taps don't stack new items in an identical spot.
    private var newItemPosition: CGPoint {
        CGPoint(
            x: canvasSize.width / 2 + Double.random(in: -30...30),
            y: canvasSize.height / 2 + Double.random(in: -30...30)
        )
    }

    private let surfaceOptions: [(name: String, label: String)] = [
        ("Kate-table-AntiqueWood", "Antique Wood"),
        ("Kate-table-Wood", "Wood"),
        ("Kate-table-BedLinen", "Bed Linen"),
        ("Kate-table-Concrete", "Concrete"),
        ("Kate-table-Marble", "Marble"),
        ("Kate-table-WhitePlaster", "White Plaster")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { geometry in
                    Image(compositionViewModel.currentComposition?.surfaceImageName ?? "Kate-table-WhitePlaster")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(1.04, anchor: .bottom)
                        .clipped()
                        .onAppear { canvasSize = geometry.size }
                        .onChange(of: geometry.size) { _, newSize in canvasSize = newSize }
                }
                .ignoresSafeArea()

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        compositionViewModel.selectedBook = nil
                        compositionViewModel.selectedDecoration = nil
                    }

                Group {
                    if let composition = compositionViewModel.currentComposition {
                        ForEach(composition.items.sorted(by: { $0.zIndex < $1.zIndex })) { composedBook in
                            TableBookView(
                                composedBook: composedBook,
                                isSelected: compositionViewModel.selectedBook?.id == composedBook.id,
                                onSelect: {
                                    compositionViewModel.selectedBook = composedBook
                                    compositionViewModel.bringToFront(composedBook)
                                },
                                onUpdate: { x, y, scale, rotation in
                                    compositionViewModel.updateBook(composedBook, offsetX: x, offsetY: y, scale: scale, rotation: rotation)
                                },
                                onDelete: {
                                    compositionViewModel.removeBook(composedBook)
                                },
                                onStraighten: {
                                    compositionViewModel.updateBook(composedBook, offsetX: composedBook.x, offsetY: composedBook.y, scale: composedBook.scale, rotation: 0)
                                },
                                snapToGridEnabled: snapToGridEnabled
                            )
                            .zIndex(composedBook.zIndex)
                        }

                        ForEach(composition.decorations.sorted(by: { $0.zIndex < $1.zIndex })) { decoration in
                            DecorationView(
                                decoration: decoration,
                                isSelected: compositionViewModel.selectedDecoration?.id == decoration.id,
                                onSelect: {
                                    compositionViewModel.selectedDecoration = decoration
                                    compositionViewModel.bringDecorationToFront(decoration)
                                },
                                onUpdate: { x, y, scale, rotation in
                                    compositionViewModel.updateDecoration(decoration, offsetX: x, offsetY: y, scale: scale, rotation: rotation)
                                },
                                onDelete: {
                                    compositionViewModel.removeDecoration(decoration)
                                },
                                onEditText: {
                                    stickyNoteEditorContext = StickyNoteEditorContext(decoration: decoration)
                                },
                                onEditPhoto: {
                                    editingPhotoDecoration = decoration
                                    showPhotoPicker = true
                                },
                                onStraighten: {
                                    compositionViewModel.updateDecoration(decoration, offsetX: decoration.x, offsetY: decoration.y, scale: decoration.scale, rotation: 0)
                                },
                                onToggleClockStyle: {
                                    compositionViewModel.toggleClockStyle(decoration)
                                }
                            )
                            .zIndex(decoration.zIndex)
                        }
                    }

                    VStack {
                        Spacer()
                        styleTray
                    }
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Arrange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.down")
                    }
                }
            }
        }
        .sheet(isPresented: $showLibraryPicker) {
            LibraryView(viewModel: libraryViewModel) { selectedBook in
                compositionViewModel.addExistingBook(selectedBook, at: newItemPosition)
                showLibraryPicker = false
            }
        }
        .sheet(isPresented: $showStickerPicker) {
            StickerPickerView { imageName in
                compositionViewModel.addDecoration(imageName: imageName, at: newItemPosition)
            }
        }
        .sheet(item: $stickyNoteEditorContext) { context in
            if let decoration = context.decoration {
                StickyNoteEditorView(
                    existingText: decoration.noteText ?? "",
                    existingColor: StickyNoteColor(rawValue: decoration.noteColorName ?? "") ?? .yellow
                ) { text, color in
                    compositionViewModel.updateStickyNoteText(decoration, text: text, color: color)
                }
            } else {
                StickyNoteEditorView { text, color in
                    compositionViewModel.addStickyNote(text: text, color: color, at: newItemPosition)
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    let normalized = image.normalizedOrientation()
                    guard let jpegData = normalized.jpegData(compressionQuality: 0.9) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    await MainActor.run {
                        if let editingPhotoDecoration {
                            compositionViewModel.updatePhotoDecorationImage(editingPhotoDecoration, imageData: jpegData)
                        } else {
                            compositionViewModel.addPhotoDecoration(imageData: jpegData, at: newItemPosition)
                        }
                        editingPhotoDecoration = nil
                        photoPickerItem = nil
                    }
                } catch {
                    await MainActor.run {
                        compositionViewModel.errorMessage = "Couldn't load that photo. Try picking a different one."
                        editingPhotoDecoration = nil
                        photoPickerItem = nil
                    }
                }
            }
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { compositionViewModel.errorMessage != nil },
            set: { if !$0 { compositionViewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(compositionViewModel.errorMessage ?? "")
        }
    }

    private var styleTray: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(surfaceOptions, id: \.name) { option in
                    let selected = (compositionViewModel.currentComposition?.surfaceImageName ?? "Kate-table-WhitePlaster") == option.name
                    Button {
                        Haptics.select()
                        compositionViewModel.setSurface(option.name)
                    } label: {
                        Image(option.name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selected ? palette.accent : palette.line, lineWidth: selected ? 2 : 1)
                            )
                            .shadow(color: .black.opacity(selected ? 0.18 : 0.08), radius: selected ? 6 : 3, y: 2)
                    }
                    .accessibilityLabel(option.label)
                }
            }

            HStack(spacing: 0) {
                trayButton(symbol: "book.closed.fill", title: "Book") {
                    showLibraryPicker = true
                }
                trayButton(symbol: "leaf.fill", title: "Stickers") {
                    showStickerPicker = true
                }
                trayButton(symbol: "note.text", title: "Note") {
                    stickyNoteEditorContext = StickyNoteEditorContext(decoration: nil)
                }
                trayButton(symbol: "photo", title: "Polaroid") {
                    editingPhotoDecoration = nil
                    showPhotoPicker = true
                }
                trayButton(symbol: "calendar", title: "Calendar") {
                    compositionViewModel.addDecoration(imageName: Decoration.calendarImageName, at: newItemPosition)
                }
                Button {
                    Haptics.select()
                    snapToGridEnabled.toggle()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 16, weight: .medium))
                        Text("Grid")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(snapToGridEnabled ? palette.accent : palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityLabel(snapToGridEnabled ? "Snap to grid on" : "Snap to grid off")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 20, y: 8)
        .padding(.horizontal, 16)
    }

    private func trayButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(palette.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Subviews (File-Level Scope)

struct TableBookView: View {
    let composedBook: ComposedBook
    var isSelected: Bool = false
    var isInteractive: Bool = true
    var onSelect: () -> Void = {}
    var onUpdate: (Double, Double, Double, Double) -> Void = { _, _, _, _ in }
    var onDelete: () -> Void = {}
    var onStraighten: () -> Void = {}
    var snapToGridEnabled: Bool = false

    private let gridSize: Double = 40

    private func snapped(_ value: Double) -> Double {
        (value / gridSize).rounded() * gridSize
    }

    @State private var dragOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    @GestureState private var rotateBy: Angle = .zero

    private var coverImage: UIImage? {
        guard let data = composedBook.book?.coverImageData else { return nil }
        return UIImage(data: data)
    }

    private var coverContent: some View {
        ZStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.4))
            }
        }
        .frame(width: 112, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .leading) {
            LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 5)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(isSelected ? 0.35 : 0.25), radius: isSelected ? 10 : 6, x: 3, y: 5)
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 16, height: 16))
        }
        .offset(x: 8, y: -8)
    }

    private var dragMagnifyRotateGesture: some Gesture {
        SimultaneousGesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        var newX = composedBook.x + value.translation.width
                        var newY = composedBook.y + value.translation.height
                        if snapToGridEnabled {
                            newX = snapped(newX)
                            newY = snapped(newY)
                        }
                        dragOffset = .zero
                        onUpdate(newX, newY, composedBook.scale, composedBook.rotation)
                    },
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let newScale = max(0.25, min(4.0, composedBook.scale * value))
                        onUpdate(composedBook.x, composedBook.y, newScale, composedBook.rotation)
                    }
            ),
            RotationGesture()
                .updating($rotateBy) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    let newRotation = composedBook.rotation + value.degrees
                    onUpdate(composedBook.x, composedBook.y, composedBook.scale, newRotation)
                }
        )
    }

    var body: some View {
        if isInteractive {
            ZStack(alignment: .topTrailing) {
                coverContent
                    .highPriorityGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                onStraighten()
                            }
                            .exclusively(before: TapGesture(count: 1).onEnded {
                                onSelect()
                            })
                    )

                if isSelected {
                    deleteButton
                }
            }
            .scaleEffect(composedBook.scale * magnifyBy)
            .rotationEffect(.degrees(composedBook.rotation + rotateBy.degrees))
            .position(x: composedBook.x + dragOffset.width, y: composedBook.y + dragOffset.height)
            .gesture(dragMagnifyRotateGesture)
        } else {
            coverContent
                .scaleEffect(composedBook.scale)
                .rotationEffect(.degrees(composedBook.rotation))
                .position(x: composedBook.x, y: composedBook.y)
        }
    }
}
