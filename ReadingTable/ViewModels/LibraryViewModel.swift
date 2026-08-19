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
                title: BookText.displayName(metadata.title),
                author: BookText.displayName(metadata.author),
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

    struct LookedUpBook: Identifiable {
        var isbn: String
        var title: String
        var author: String
        var coverImageData: Data?

        var id: String { isbn }
    }

    func lookupBook(isbn rawIsbn: String) async -> LookedUpBook? {
        let isbn = Self.sanitizeISBN(rawIsbn)
        guard isbn.count >= 10 else {
            errorMessage = "That doesn't look like a full ISBN yet."
            return nil
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (metadata, cover) = try await metadataService.lookupEdition(isbn: isbn)
            return LookedUpBook(
                isbn: isbn,
                title: BookText.displayName(metadata.title),
                author: BookText.displayName(metadata.author),
                coverImageData: cover
            )
        } catch let error as BookMetadataError {
            errorMessage = error.errorDescription
            return nil
        } catch {
            errorMessage = "We couldn't look that up just now. Add a photo of the cover instead."
            return nil
        }
    }

    func searchBooks(query raw: String) async -> [LookedUpBook] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            errorMessage = "Type a title or an author."
            return []
        }

        if Self.looksLikeISBN(query) {
            if let book = await lookupBook(isbn: query) {
                return [book]
            }
            return []
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let hits = try await metadataService.searchBooks(query: query)
            guard !hits.isEmpty else {
                errorMessage = "We couldn't find that book. Try a shorter title, the author's name, or add a photo of the cover."
                return []
            }

            return await withTaskGroup(of: (Int, LookedUpBook).self) { group in
                let service = metadataService
                for (index, hit) in hits.prefix(8).enumerated() {
                    group.addTask {
                        var cover: Data?
                        if let url = hit.coverURL {
                            cover = await BookLookupSession.downloadCover(
                                from: url,
                                session: BookLookupSession.make(timeout: 10)
                            )
                        }
                        if cover == nil {
                            cover = await service.fetchCoverImage(title: hit.title, author: hit.author)
                        }
                        return (
                            index,
                            LookedUpBook(
                                isbn: hit.isbn,
                                title: BookText.displayName(hit.title),
                                author: BookText.displayName(hit.author),
                                coverImageData: cover
                            )
                        )
                    }
                }
                var mapped: [(Int, LookedUpBook)] = []
                for await item in group {
                    mapped.append(item)
                }
                return mapped.sorted { $0.0 < $1.0 }.map(\.1)
            }
        } catch let error as BookMetadataError {
            errorMessage = error.errorDescription
            return []
        } catch {
            errorMessage = "We couldn't look that up just now. Add a photo of the cover instead."
            return []
        }
    }

    func saveBook(isbn: String, title: String, author: String, coverImageData: Data?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title cannot be empty"
            return
        }
        errorMessage = nil

        let resolvedISBN = isbn.isEmpty ? "manual-\(UUID().uuidString)" : isbn
        let newBook = Book(
            isbn: resolvedISBN,
            title: BookText.displayName(trimmedTitle),
            author: BookText.displayName(author),
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
        isbnInput = ""
        WidgetCenter.shared.reloadAllTimelines()
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
            title: BookText.displayName(trimmedTitle),
            author: BookText.displayName(author),
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
    /// True when the user typed a barcode number, not a title.
    static func looksLikeISBN(_ raw: String) -> Bool {
        let isbn = sanitizeISBN(raw)
        guard isbn.count == 10 || isbn.count == 13 else { return false }
        let compact = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        return compact == isbn
    }

    static func sanitizeISBN(_ raw: String) -> String {
        raw.uppercased().filter { $0.isNumber || $0 == "X" }
    }

    func updateBook(_ book: Book, title: String, author: String, coverImageData: Data?) {
        book.title = BookText.displayName(title)
        book.author = BookText.displayName(author)
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

enum BookText {
    /// Title Case for cover OCR and ALL CAPS catalogue titles. Mixed-case
    /// names from Google Books are left as they arrived.
    static func displayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let letters = trimmed.filter(\.isLetter)
        let uppercaseCount = letters.filter(\.isUppercase).count
        let mostlyCaps = !letters.isEmpty && uppercaseCount * 4 >= letters.count * 3
        guard mostlyCaps else { return trimmed }

        return trimmed.lowercased().split(whereSeparator: \.isWhitespace).map { word in
            guard let first = word.first else { return "" }
            return String(first).uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }
}
