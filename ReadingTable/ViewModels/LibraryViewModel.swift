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
    
    func addBook(isbn: String, customCoverData: Data? = nil) async {
        guard !isbn.trimmingCharacters(in: .whitespaces).isEmpty else {
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
        } catch {
            errorMessage = "Failed to add book: \(error.localizedDescription)"
        }
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

    func deleteBook(_ book: Book) {
        modelContext.delete(book)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete book: \(error.localizedDescription)"
        }
        loadBooks()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
