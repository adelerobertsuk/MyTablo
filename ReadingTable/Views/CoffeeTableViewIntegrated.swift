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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showLibraryPicker = false
    @State private var showStickerPicker = false
    @State private var stickyNoteEditorContext: StickyNoteEditorContext?
    @State private var snapToGridEnabled = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var editingPhotoDecoration: Decoration?
    @State private var canvasMetrics = CanvasMetrics.current
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Center of the actual table canvas, with a little jitter so repeated
    /// taps don't stack new items in an identical spot.
    private var newItemPosition: CGPoint {
        let bounds = currentTableLayout.itemBounds
        return CGPoint(
            x: bounds.midX + Double.random(in: -30...30),
            y: bounds.midY + Double.random(in: -30...30)
        )
    }

    private var canvasSize: CGSize { canvasMetrics.size }

    private var isRegularLayout: Bool { horizontalSizeClass == .regular }
    private var trayIconSize: CGFloat { isRegularLayout ? 22 : 16 }
    private var trayLabelSize: CGFloat { isRegularLayout ? 12 : 10 }
    private var surfaceSwatchSize: CGFloat { isRegularLayout ? 52 : 44 }

    private var currentTableLayout: TableLayout {
        TableLayout(
            layoutSize: compositionViewModel.resolvedLayoutSize(for: canvasSize),
            canvasSize: canvasSize,
            safeInsets: canvasMetrics.safeInsets
        )
    }

    private var placementPoint: CGPoint {
        currentTableLayout.stored(newItemPosition)
    }

    private let surfaceOptions: [(name: String, label: String)] = [
        ("Kate-table-WhitePlaster", "Plaster"),
        ("Kate-table-Wood", "Wood"),
        ("Kate-table-Marble", "Marble"),
        ("Kate-table-Concrete", "Concrete")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ZStack {
                    TableSurfaceView(
                        imageName: compositionViewModel.currentComposition?.surfaceImageName ?? "Kate-table-WhitePlaster"
                    )

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            compositionViewModel.selectedBook = nil
                            compositionViewModel.selectedDecoration = nil
                        }

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

                    CanvasSizeReader { metrics in
                        canvasMetrics = metrics
                        compositionViewModel.ensureLayoutSize(matching: metrics.size)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.tableLayout, currentTableLayout)
                .ignoresSafeArea()
                .transaction { $0.animation = nil }

                VStack {
                    Spacer()
                    styleTray
                        .frame(maxWidth: isRegularLayout ? 560 : .infinity)
                }
                .padding(.bottom, isRegularLayout ? 20 : 12)
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
            .onAppear {
                compositionViewModel.ensureLayoutSize(matching: canvasSize)
            }
        }
        .sheet(isPresented: $showLibraryPicker) {
            LibraryView(viewModel: libraryViewModel, placesOnTap: true) { selectedBook in
                compositionViewModel.addExistingBook(selectedBook, at: placementPoint)
                showLibraryPicker = false
            }
        }
        .sheet(isPresented: $showStickerPicker) {
            StickerPickerView { imageName in
                compositionViewModel.addDecoration(imageName: imageName, at: placementPoint)
            }
        }
        .sheet(item: $stickyNoteEditorContext) { context in
            if let decoration = context.decoration {
                StickyNoteEditorView(
                    existingInkData: decoration.noteInkData,
                    existingColor: StickyNoteColor(rawValue: decoration.noteColorName ?? "") ?? .yellow
                ) { inkData, color in
                    compositionViewModel.updateStickyNote(decoration, inkData: inkData, text: decoration.noteText, color: color)
                }
            } else {
                StickyNoteEditorView { inkData, color in
                    compositionViewModel.addStickyNote(inkData: inkData, color: color, at: placementPoint)
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    // Polaroids display at ~140pt. Cap the decode so a 12–48MP
                    // camera photo cannot take down the app (or Xcode).
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = UIImage.downsampled(from: data, maxPixelSize: 1600),
                          let jpegData = image.jpegData(compressionQuality: 0.82) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    await MainActor.run {
                        if let editingPhotoDecoration {
                            compositionViewModel.updatePhotoDecorationImage(editingPhotoDecoration, imageData: jpegData)
                        } else {
                            compositionViewModel.addPhotoDecoration(imageData: jpegData, at: placementPoint)
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
                            .scaleEffect(1.02, anchor: .center)
                            .frame(width: surfaceSwatchSize, height: surfaceSwatchSize)
                            .clipped()
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
                    compositionViewModel.addDecoration(imageName: Decoration.calendarImageName, at: placementPoint)
                }
                Button {
                    Haptics.select()
                    snapToGridEnabled.toggle()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: trayIconSize, weight: .medium))
                        Text("Grid")
                            .font(.system(size: trayLabelSize, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(snapToGridEnabled ? palette.accent : palette.ink)
                    .frame(maxWidth: .infinity, minHeight: isRegularLayout ? 52 : 44)
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
        .padding(.horizontal, isRegularLayout ? 0 : 16)
    }

    private func trayButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: trayIconSize, weight: .medium))
                Text(title)
                    .font(.system(size: trayLabelSize, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(palette.ink)
            .frame(maxWidth: .infinity, minHeight: isRegularLayout ? 52 : 44)
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
    @Environment(\.tableLayout) private var tableLayout

    private var displayedOrigin: CGPoint {
        tableLayout.display(CGPoint(x: composedBook.x, y: composedBook.y))
    }

    private var coverImage: UIImage? {
        guard let data = composedBook.book?.coverImageData,
              BookLookupSession.isUsableCover(data) else { return nil }
        return UIImage(data: data)
    }

    private var isCutoutCover: Bool {
        coverImage?.hasAlphaChannel == true
    }

    private var coverSize: CGSize {
        let maxHeight: CGFloat = 168
        let maxWidth: CGFloat = 140
        guard let coverImage, coverImage.size.height > 1 else {
            return CGSize(width: 112, height: maxHeight)
        }
        let aspect = coverImage.size.width / coverImage.size.height
        var height = maxHeight
        var width = height * aspect
        if width > maxWidth {
            width = maxWidth
            height = width / aspect
        }
        return CGSize(width: width, height: height)
    }

    private var coverContent: some View {
        Group {
            if let coverImage, isCutoutCover {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: coverSize.width, height: coverSize.height)
                    .shadow(color: .black.opacity(isSelected ? 0.35 : 0.22), radius: isSelected ? 10 : 6, x: 2, y: 4)
            } else {
                ZStack {
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.4))
                    }
                }
                .frame(width: coverSize.width, height: coverSize.height)
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
        }
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
        let magnifyRotate = SimultaneousGesture(
            MagnificationGesture()
                .updating($magnifyBy) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    let newScale = max(0.25, min(4.0, composedBook.scale * value))
                    onUpdate(composedBook.x, composedBook.y, newScale, composedBook.rotation)
                },
            RotationGesture()
                .updating($rotateBy) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    let newRotation = composedBook.rotation + value.degrees
                    onUpdate(composedBook.x, composedBook.y, composedBook.scale, newRotation)
                }
        )
        let drag = DragGesture()
            .onChanged { value in
                guard abs(magnifyBy - 1) < 0.04 else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                defer { dragOffset = .zero }
                guard abs(magnifyBy - 1) < 0.04 else { return }
                var newDisplay = CGPoint(
                    x: displayedOrigin.x + value.translation.width,
                    y: displayedOrigin.y + value.translation.height
                )
                if snapToGridEnabled {
                    newDisplay.x = snapped(newDisplay.x)
                    newDisplay.y = snapped(newDisplay.y)
                }
                let stored = tableLayout.clampedStored(fromDisplay: newDisplay)
                onUpdate(stored.x, stored.y, composedBook.scale, composedBook.rotation)
            }
        return magnifyRotate.exclusively(before: drag)
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
            .scaleEffect(composedBook.scale * magnifyBy * tableLayout.itemScale)
            .rotationEffect(.degrees(composedBook.rotation + rotateBy.degrees))
            .position(x: displayedOrigin.x + dragOffset.width, y: displayedOrigin.y + dragOffset.height)
            .gesture(dragMagnifyRotateGesture)
        } else {
            coverContent
                .scaleEffect(composedBook.scale * tableLayout.itemScale)
                .rotationEffect(.degrees(composedBook.rotation))
                .position(x: displayedOrigin.x, y: displayedOrigin.y)
        }
    }
}
