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

    func loadCompositions() {
        do {
            let descriptor = FetchDescriptor<CoffeeTableComposition>(
                sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
            )
            self.compositions = try modelContext.fetch(descriptor)
            if let first = compositions.first {
                self.currentComposition = first
            }
        } catch {
            self.errorMessage = "Failed to load compositions: \(error.localizedDescription)"
        }
    }
    
    func createDefaultComposition() {
        let composition = CoffeeTableComposition(name: "My Table")
        modelContext.insert(composition)
        try? modelContext.save()
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
        try? modelContext.save()
        currentComposition = composition
    }

    func addExistingBook(_ book: Book) {
        guard let composition = currentComposition else { return }

        let composedBook = ComposedBook(book: book, x: 150, y: 200, rotation: Double.random(in: -8...8), scale: 1.0, zIndex: nextZIndex(in: composition))
        composition.items.append(composedBook)
        try? modelContext.save()
        currentComposition = composition
    }

    func updateBook(_ book: ComposedBook, offsetX: Double, offsetY: Double, scale: Double, rotation: Double) {
        guard let composition = currentComposition else { return }

        if let index = composition.items.firstIndex(where: { $0.id == book.id }) {
            composition.items[index].x = offsetX
            composition.items[index].y = offsetY
            composition.items[index].rotation = rotation
            composition.items[index].scale = scale

            try? modelContext.save()
            currentComposition = composition
        }
    }

    func removeBook(_ book: ComposedBook) {
        guard let composition = currentComposition else { return }

        composition.items.removeAll { $0.id == book.id }
        try? modelContext.save()
        currentComposition = composition
        selectedBook = nil
    }

    func bringToFront(_ book: ComposedBook) {
        guard let composition = currentComposition else { return }

        if let index = composition.items.firstIndex(where: { $0.id == book.id }) {
            composition.items[index].zIndex = nextZIndex(in: composition)
        }

        try? modelContext.save()
        currentComposition = composition
    }

    func setSurface(_ name: String) {
        guard let composition = currentComposition else { return }

        composition.surfaceImageName = name
        try? modelContext.save()
        currentComposition = composition
    }

    func addDecoration(imageName: String) {
        guard let composition = currentComposition else { return }

        let decoration = Decoration(imageName: imageName, x: 150, y: 200, rotation: Double.random(in: -8...8), scale: 1.0, zIndex: nextZIndex(in: composition))
        composition.decorations.append(decoration)
        try? modelContext.save()
        currentComposition = composition
    }

    func updateDecoration(_ decoration: Decoration, offsetX: Double, offsetY: Double, scale: Double, rotation: Double) {
        guard let composition = currentComposition else { return }

        if let index = composition.decorations.firstIndex(where: { $0.id == decoration.id }) {
            composition.decorations[index].x = offsetX
            composition.decorations[index].y = offsetY
            composition.decorations[index].rotation = rotation
            composition.decorations[index].scale = scale

            try? modelContext.save()
            currentComposition = composition
        }
    }

    func removeDecoration(_ decoration: Decoration) {
        guard let composition = currentComposition else { return }

        composition.decorations.removeAll { $0.id == decoration.id }
        try? modelContext.save()
        currentComposition = composition
        selectedDecoration = nil
    }

    func bringDecorationToFront(_ decoration: Decoration) {
        guard let composition = currentComposition else { return }

        if let index = composition.decorations.firstIndex(where: { $0.id == decoration.id }) {
            composition.decorations[index].zIndex = nextZIndex(in: composition)
        }

        try? modelContext.save()
        currentComposition = composition
    }
}
