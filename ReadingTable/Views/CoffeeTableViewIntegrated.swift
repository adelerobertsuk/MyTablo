import SwiftUI
import SwiftData

struct StyleView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject var compositionViewModel: CoffeeTableCompositionViewModel
    var onDismiss: () -> Void = {}

    @State private var showLibraryPicker = false
    @State private var showStickerPicker = false
    @State private var snapToGridEnabled = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let surfaceOptions: [(name: String, label: String)] = [
        ("Kate-table-AntiqueWood", "Antique Wood"),
        ("Kate-table-Wood", "Wood"),
        ("Kate-table-BedLinen", "Bed Linen"),
        ("Kate-table-Concrete", "Concrete"),
        ("Kate-table-Marble", "Marble"),
        ("Kate-table-WhitePlaster", "White Plaster")
    ]

    private var currentSurfaceLabel: String {
        let name = compositionViewModel.currentComposition?.surfaceImageName ?? "Kate-table-WhitePlaster"
        return surfaceOptions.first(where: { $0.name == name })?.label ?? "Table"
    }

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
                                }
                            )
                            .zIndex(decoration.zIndex)
                        }
                    }

                    VStack {
                        HStack(spacing: 12) {
                            Button(action: { showLibraryPicker = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Book")
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                                .cornerRadius(8)
                            }

                            Button(action: { showStickerPicker = true }) {
                                Image(systemName: "leaf.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                                    .clipShape(Circle())
                            }

                            Button(action: { snapToGridEnabled.toggle() }) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.subheadline)
                                    .foregroundColor(snapToGridEnabled ? .white : .primary)
                                    .padding(10)
                                    .background(snapToGridEnabled ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color(.systemGray6))
                                    .clipShape(Circle())
                            }

                            Spacer()

                            Menu {
                                ForEach(surfaceOptions, id: \.name) { option in
                                    Button(option.label) {
                                        compositionViewModel.setSurface(option.name)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(currentSurfaceLabel)
                                    Image(systemName: "chevron.down")
                                }
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                            }
                        }
                        .padding()

                        Spacer()
                    }
                }
            }
            .navigationTitle("Style")
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
            NavigationStack {
                LibraryView(viewModel: libraryViewModel) { selectedBook in
                    compositionViewModel.addExistingBook(selectedBook)
                    showLibraryPicker = false
                }
            }
        }
        .sheet(isPresented: $showStickerPicker) {
            StickerPickerView { imageName in
                compositionViewModel.addDecoration(imageName: imageName)
            }
        }
        .alert("Couldn't Save", isPresented: Binding(
            get: { compositionViewModel.errorMessage != nil },
            set: { if !$0 { compositionViewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(compositionViewModel.errorMessage ?? "")
        }
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
                    .gesture(dragMagnifyRotateGesture)
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
        } else {
            coverContent
                .scaleEffect(composedBook.scale)
                .rotationEffect(.degrees(composedBook.rotation))
                .position(x: composedBook.x, y: composedBook.y)
        }
    }
}
