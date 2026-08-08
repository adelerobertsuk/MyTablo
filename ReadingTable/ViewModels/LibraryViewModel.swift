import Foundation
import SwiftData
import Combine
import WidgetKit

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isbnInput: String = ""
    
    private let modelContext: ModelContext
    private let metadataService: BookMetadataProvider
    
    init(modelContext: ModelContext, metadataService: BookMetadataProvider) {
        self.modelContext = modelContext
        self.metadataService = metadataService
        loadBooks()
    }
    
    func loadBooks() {
        do {
            let descriptor = FetchDescriptor<Book>(
                sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
            )
            self.books = try modelContext.fetch(descriptor)
        } catch {
            self.errorMessage = "Failed to load books: \(error.localizedDescription)"
        }
    }
    
    func addBook(isbn rawIsbn: String, customCoverData: Data? = nil) async {
        let isbn = Self.sanitizeISBN(rawIsbn)
        guard !isbn.isEmpty else {
            errorMessage = "ISBN cannot be empty"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let metadata = try await metadataService.fetchMetadata(for: isbn)
            let coverData: Data?
            if let customCoverData {
                coverData = customCoverData
            } else {
                coverData = try await metadataService.fetchCoverImage(for: isbn)
            }

            let newBook = Book(
                isbn: isbn,
                title: metadata.title,
                author: metadata.author,
                coverImageData: coverData
            )
            
            modelContext.insert(newBook)
            try modelContext.save()

            loadBooks()
            isbnInput = ""
            WidgetCenter.shared.reloadAllTimelines()
        } catch let error as BookMetadataError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to add book: \(error.localizedDescription)"
        }
    }
    
    func addBookManually(title: String, author: String, coverImageData: Data?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title cannot be empty"
            return
        }
        errorMessage = nil

        let newBook = Book(
            isbn: "manual-\(UUID().uuidString)",
            title: trimmedTitle,
            author: author.trimmingCharacters(in: .whitespaces),
            coverImageData: coverImageData
        )

        modelContext.insert(newBook)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to add book: \(error.localizedDescription)"
            return
        }

        loadBooks()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Strips everything but digits (and the ISBN-10 "X" check digit) so pasted
    /// ISBNs with hyphens, spaces, or stray newlines from a copied web page still resolve.
    static func sanitizeISBN(_ raw: String) -> String {
        raw.uppercased().filter { $0.isNumber || $0 == "X" }
    }

    func updateBook(_ book: Book, title: String, author: String, coverImageData: Data?) {
        book.title = title
        book.author = author
        if let coverImageData {
            book.coverImageData = coverImageData
        }
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to update book: \(error.localizedDescription)"
        }
        loadBooks()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Only one book can be "currently reading" at a time — the widget has a single slot to show,
    /// so setting a new one clears the flag on whichever book had it before.
    func setCurrentlyReading(_ book: Book, isCurrentlyReading: Bool) {
        if isCurrentlyReading {
            for other in books where other !== book {
                other.isCurrentlyReading = false
            }
        }
        book.isCurrentlyReading = isCurrentlyReading
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to update book: \(error.localizedDescription)"
        }
        loadBooks()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteBook(_ book: Book) {
        removeBookFromCompositions(book)
        modelContext.delete(book)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete book: \(error.localizedDescription)"
        }
        loadBooks()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// `ComposedBook.book` has no inverse relationship back to `Book`, so SwiftData
    /// can't automatically clear a table placement when its book is deleted — leaving
    /// a dangling reference that crashes ("model instance was invalidated") the next
    /// time the Table view reads it. Strip the book off the table first.
    private func removeBookFromCompositions(_ book: Book) {
        guard let compositions = try? modelContext.fetch(FetchDescriptor<CoffeeTableComposition>()) else { return }
        for composition in compositions {
            composition.items.removeAll { $0.book === book }
        }
    }
}
