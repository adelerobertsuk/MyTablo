import Foundation
import SwiftData
import Combine


@MainActor
class CoffeeTableCompositionViewModel: ObservableObject {
    @Published var compositions: [CoffeeTableComposition] = []
    @Published var currentComposition: CoffeeTableComposition?
    @Published var selectedBook: ComposedBook?
    @Published var selectedDecoration: Decoration?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCompositions()
        
        // Create default composition if none exist
        if compositions.isEmpty {
            createDefaultComposition()
        }
    }
    
    private func nextZIndex(in composition: CoffeeTableComposition) -> Double {
        let maxItemZ = composition.items.map { $0.zIndex }.max() ?? 0
        let maxDecorationZ = composition.decorations.map { $0.zIndex }.max() ?? 0
        return max(maxItemZ, maxDecorationZ) + 1
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save your table: \(error.localizedDescription)"
        }
    }

    /// Locks the composition to the first real canvas it sees. Later rotates
    /// keep these numbers and scale on screen instead of dropping items off the edge.
    func ensureLayoutSize(matching canvas: CGSize) {
        guard let composition = currentComposition else { return }
        guard composition.layoutWidth < 1 || composition.layoutHeight < 1 else { return }
        guard canvas.width > 1, canvas.height > 1 else { return }

        var maxX = canvas.width
        var maxY = canvas.height
        for item in composition.items {
            maxX = max(maxX, item.x)
            maxY = max(maxY, item.y)
        }
        for decoration in composition.decorations {
            maxX = max(maxX, decoration.x)
            maxY = max(maxY, decoration.y)
        }
        let extra: Double = 80
        composition.layoutWidth = maxX > canvas.width ? maxX + extra : canvas.width
        composition.layoutHeight = maxY > canvas.height ? maxY + extra : canvas.height
        save()
        currentComposition = composition
    }

    func resolvedLayoutSize(for canvas: CGSize) -> CGSize {
        let width = currentComposition?.layoutWidth ?? 0
        let height = currentComposition?.layoutHeight ?? 0
        return CGSize(
            width: width >= 1 ? width : canvas.width,
            height: height >= 1 ? height : canvas.height
        )
    }

    func loadCompositions() {
        do {
            let descriptor = FetchDescriptor<CoffeeTableComposition>(
                sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
            )
            self.compositions = try modelContext.fetch(descriptor)
            repairDanglingBookReferences()
            if let first = compositions.first {
                self.currentComposition = first
            }
        } catch {
            self.errorMessage = "Failed to load compositions: \(error.localizedDescription)"
        }
    }

    /// Composition items saved before `ComposedBook` had cleanup-on-delete could be left
    /// pointing at a book row that's since been deleted — reading any property off that
    /// stale reference (e.g. `coverImageData`) crashes with "This model instance was
    /// invalidated." Strip those out, comparing by identity so we never touch the stale
    /// object's own properties.
    private func repairDanglingBookReferences() {
        guard let validBooks = try? modelContext.fetch(FetchDescriptor<Book>()) else { return }
        let validBookIDs = Set(validBooks.map(\.persistentModelID))
        var didRepair = false
        for composition in compositions {
            let before = composition.items.count
            composition.items.removeAll { composedBook in
                guard let book = composedBook.book else { return false }
                return !validBookIDs.contains(book.persistentModelID)
            }
            if composition.items.count != before {
                didRepair = true
            }
        }
        if didRepair {
            save()
        }
    }
    
    func createDefaultComposition() {
        let composition = CoffeeTableComposition(name: "My Table")
        modelContext.insert(composition)
        save()
        loadCompositions()
    }
    
    func addBook(
        isbn: String,
        title: String,
        author: String,
        coverData: Data?
    ) {
        guard let composition = currentComposition else { return }
        
        let newBook = Book(isbn: isbn, title: title, author: author, coverImageData: coverData)
        let composedBook = ComposedBook()
        composedBook.book = newBook
        composedBook.x = Double.random(in: -100...100)
        composedBook.y = Double.random(in: -100...100)
        composedBook.rotation = Double.random(in: -15...15)
        composedBook.zIndex = nextZIndex(in: composition)

        composition.items.append(composedBook)
        save()
        currentComposition = composition
    }

    func addExistingBook(_ book: Book, at position: CGPoint = CGPoint(x: 150, y: 200)) {
        guard let composition = currentComposition else { return }

        let composedBook = ComposedBook(book: book, x: position.x, y: position.y, rotation: Double.random(in: -8...8), scale: 1.0, zIndex: nextZIndex(in: composition))
        composition.items.append(composedBook)
        save()
        currentComposition = composition
    }

    func updateBook(_ book: ComposedBook, offsetX: Double, offsetY: Double, scale: Double, rotation: Double) {
        guard let composition = currentComposition else { return }

        if let index = composition.items.firstIndex(where: { $0.id == book.id }) {
            composition.items[index].x = offsetX
            composition.items[index].y = offsetY
            composition.items[index].rotation = rotation
            composition.items[index].scale = scale

            save()
            currentComposition = composition
        }
    }

    func removeBook(_ book: ComposedBook) {
        guard let composition = currentComposition else { return }

        composition.items.removeAll { $0.id == book.id }
        save()
        currentComposition = composition
        selectedBook = nil
    }

    func bringToFront(_ book: ComposedBook) {
        guard let composition = currentComposition else { return }

        if let index = composition.items.firstIndex(where: { $0.id == book.id }) {
            composition.items[index].zIndex = nextZIndex(in: composition)
        }

        save()
        currentComposition = composition
    }

    func setSurface(_ name: String) {
        guard let composition = currentComposition else { return }

        composition.surfaceImageName = name
        save()
        currentComposition = composition
    }

    func addDecoration(imageName: String, at position: CGPoint = CGPoint(x: 150, y: 200)) {
        guard let composition = currentComposition else { return }

        let decoration = Decoration(imageName: imageName, x: position.x, y: position.y, rotation: Double.random(in: -8...8), scale: 1.0, zIndex: nextZIndex(in: composition))
        composition.decorations.append(decoration)
        save()
        currentComposition = composition
    }

    func addStickyNote(text: String, color: StickyNoteColor, at position: CGPoint = CGPoint(x: 150, y: 200)) {
        guard let composition = currentComposition else { return }

        let note = Decoration(
            imageName: Decoration.stickyNoteImageName,
            x: position.x,
            y: position.y,
            rotation: Double.random(in: -8...8),
            scale: 1.0,
            zIndex: nextZIndex(in: composition),
            noteText: text,
            noteColorName: color.rawValue
        )
        composition.decorations.append(note)
        save()
        currentComposition = composition
    }

    func updateStickyNoteText(_ decoration: Decoration, text: String, color: StickyNoteColor) {
        guard let composition = currentComposition else { return }

        if let index = composition.decorations.firstIndex(where: { $0.id == decoration.id }) {
            composition.decorations[index].noteText = text
            composition.decorations[index].noteColorName = color.rawValue
            save()
            currentComposition = composition
        }
    }

    func toggleClockStyle(_ decoration: Decoration) {
        guard let composition = currentComposition else { return }

        if let index = composition.decorations.firstIndex(where: { $0.id == decoration.id }) {
            composition.decorations[index].clockStyleName = decoration.isAnalogClock ? nil : "analog"
            save()
            currentComposition = composition
        }
    }

    func addPhotoDecoration(imageData: Data, at position: CGPoint = CGPoint(x: 150, y: 200)) {
        guard let composition = currentComposition else { return }

        let photo = Decoration(
            imageName: Decoration.photoFrameImageName,
            x: position.x,
            y: position.y,
            rotation: Double.random(in: -8...8),
            scale: 1.0,
            zIndex: nextZIndex(in: composition),
            photoImageData: imageData
        )
        composition.decorations.append(photo)
        save()
        currentComposition = composition
    }

    func updatePhotoDecorationImage(_ decoration: Decoration, imageData: Data) {
        guard let composition = currentComposition else { return }

        if let index = composition.decorations.firstIndex(where: { $0.id == decoration.id }) {
            composition.decorations[index].photoImageData = imageData
            save()
            currentComposition = composition
        }
    }

    func updateDecoration(_ decoration: Decoration, offsetX: Double, offsetY: Double, scale: Double, rotation: Double) {
        guard let composition = currentComposition else { return }

        if let index = composition.decorations.firstIndex(where: { $0.id == decoration.id }) {
            composition.decorations[index].x = offsetX
            composition.decorations[index].y = offsetY
            composition.decorations[index].rotation = rotation
            composition.decorations[index].scale = scale

            save()
            currentComposition = composition
        }
    }

    func removeDecoration(_ decoration: Decoration) {
        guard let composition = currentComposition else { return }

        composition.decorations.removeAll { $0.id == decoration.id }
        save()
        currentComposition = composition
        selectedDecoration = nil
    }

    func bringDecorationToFront(_ decoration: Decoration) {
        guard let composition = currentComposition else { return }

        if let index = composition.decorations.firstIndex(where: { $0.id == decoration.id }) {
            composition.decorations[index].zIndex = nextZIndex(in: composition)
        }

        save()
        currentComposition = composition
    }
}
