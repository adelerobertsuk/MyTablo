import Foundation

protocol BookMetadataProvider {
    func fetchMetadata(for isbn: String) async throws -> BookMetadata
    func fetchCoverImage(for isbn: String) async throws -> Data?
}

struct BookMetadata {
    let title: String
    let author: String
    let isbn: String
}

enum BookMetadataError: LocalizedError {
    case notFound
    case lookupFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "We couldn't find a book with that ISBN. Double-check the number, or add the book's details yourself."
        case .lookupFailed:
            return "Something went wrong looking up that book. Please check your connection and try again."
        }
    }
}

// MARK: - Mock Implementation

actor MockBookMetadataService: BookMetadataProvider {
    private let mockBooks: [String: BookMetadata] = [
        "9780262033848": BookMetadata(
            title: "Structure and Interpretation of Computer Programs",
            author: "Abelson & Sussman",
            isbn: "9780262033848"
        ),
        "9780134685991": BookMetadata(
            title: "Effective Java",
            author: "Joshua Bloch",
            isbn: "9780134685991"
        ),
        "9780596007127": BookMetadata(
            title: "Head First Design Patterns",
            author: "Freeman & Freeman",
            isbn: "9780596007127"
        ),
        "9780201633610": BookMetadata(
            title: "Design Patterns",
            author: "Gang of Four",
            isbn: "9780201633610"
        ),
    ]
    
    func fetchMetadata(for isbn: String) async throws -> BookMetadata {
        try await Task.sleep(nanoseconds: 500_000_000)

        guard let book = mockBooks[isbn] else {
            throw BookMetadataError.notFound
        }
        return book
    }
    
    func fetchCoverImage(for isbn: String) async throws -> Data? {
        try await Task.sleep(nanoseconds: 300_000_000)
        return nil
    }
}

// MARK: - Real OpenLibrary Implementation

actor OpenLibraryMetadataService: BookMetadataProvider {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchMetadata(for isbn: String) async throws -> BookMetadata {
        let urlString = "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data"
        guard let url = URL(string: urlString) else {
            throw BookMetadataError.lookupFailed
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BookMetadataError.lookupFailed
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let bookData = json["ISBN:\(isbn)"] as? [String: Any],
           let title = bookData["title"] as? String {

            var author = "Unknown Author"
            if let authors = bookData["authors"] as? [[String: Any]],
               let firstAuthor = authors.first?["name"] as? String {
                author = firstAuthor
            }

            return BookMetadata(title: title, author: author, isbn: isbn)
        }

        throw BookMetadataError.notFound
    }
    
    func fetchCoverImage(for isbn: String) async throws -> Data? {
        let urlString = "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg"
        guard let url = URL(string: urlString) else { return nil }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        // When OpenLibrary has no cover for an ISBN it still returns HTTP 200,
        // but with a tiny 1x1 placeholder GIF (~43 bytes) instead of a real photo.
        guard data.count > 1_000 else { return nil }
        return data
    }
}
