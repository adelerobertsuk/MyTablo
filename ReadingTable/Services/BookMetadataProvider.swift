import Foundation
import UIKit

protocol BookMetadataProvider {
    func fetchMetadata(for isbn: String) async throws -> BookMetadata
    func fetchCoverImage(for isbn: String) async throws -> Data?
    func fetchCoverImage(title: String, author: String) async -> Data?
    func lookupEdition(isbn: String) async throws -> (BookMetadata, Data?)
    func searchBooks(query: String) async throws -> [BookSearchHit]
}

extension BookMetadataProvider {
    func fetchCoverImage(title: String, author: String) async -> Data? { nil }

    func lookupEdition(isbn: String) async throws -> (BookMetadata, Data?) {
        let metadata = try await fetchMetadata(for: isbn)
        if let cover = try await fetchCoverImage(for: isbn) {
            return (metadata, cover)
        }
        if let cover = await fetchCoverImage(title: metadata.title, author: metadata.author) {
            return (metadata, cover)
        }
        return (metadata, nil)
    }

    func searchBooks(query: String) async throws -> [BookSearchHit] {
        throw BookMetadataError.notFound
    }
}

struct BookSearchHit: Sendable {
    var isbn: String
    var title: String
    var author: String
    var coverURL: URL?
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
            return "We couldn't find that book. Try a shorter title, the author's name, or add a photo of the cover."
        case .lookupFailed:
            return "We couldn't look that up just now. Add a photo of the cover instead."
        }
    }
}

// MARK: - Mock Implementation

final class MockBookMetadataService: BookMetadataProvider {
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

// MARK: - Composite (race several catalogues)

/// Open Library has been timing out from UK networks, so ISBN add cannot
/// depend on it alone. We ask Google Books (Atom feed, no API key) and
/// iTunes at the same time, and keep Open Library as a fallback.
final class CompositeBookMetadataService: BookMetadataProvider {
    private let providers: [any BookMetadataProvider]

    init(providers: [any BookMetadataProvider]? = nil) {
        self.providers = providers ?? [
            OpenLibraryMetadataService(),
            GoogleBooksAtomMetadataService(),
            ITunesBookMetadataService(),
            GoogleBooksJSONMetadataService()
        ]
    }

    func fetchMetadata(for isbn: String) async throws -> BookMetadata {
        let outcome = await firstSuccess(from: providers) { provider in
            try await provider.fetchMetadata(for: isbn)
        }
        switch outcome {
        case .success(let metadata):
            return metadata
        case .failure(let error):
            throw error
        }
    }

    func fetchCoverImage(for isbn: String) async throws -> Data? {
        if let byISBN = try? await firstSuccess(from: providers, perform: { provider in
            guard let data = try await provider.fetchCoverImage(for: isbn) else {
                throw BookMetadataError.notFound
            }
            return data
        }).get() {
            return byISBN
        }
        return nil
    }

    func fetchCoverImage(title: String, author: String) async -> Data? {
        let outcome = await firstSuccess(from: providers) { provider in
            guard let data = await provider.fetchCoverImage(title: title, author: author) else {
                throw BookMetadataError.notFound
            }
            return data
        }
        return try? outcome.get()
    }

    func searchBooks(query: String) async throws -> [BookSearchHit] {
        let outcome = await firstSuccess(from: providers) { provider in
            let hits = try await provider.searchBooks(query: query)
            guard !hits.isEmpty else { throw BookMetadataError.notFound }
            return hits
        }
        switch outcome {
        case .success(let hits):
            return hits
        case .failure(let error):
            throw error
        }
    }

    private func firstSuccess<T: Sendable>(
        from providers: [any BookMetadataProvider],
        perform: @escaping (any BookMetadataProvider) async throws -> T
    ) async -> Result<T, Error> {
        await withTaskGroup(of: Result<T, Error>.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return .success(try await perform(provider))
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var sawNotFound = false
            var sawLookupFailed = false

            for await result in group {
                switch result {
                case .success(let value):
                    group.cancelAll()
                    return .success(value)
                case .failure(let error):
                    if let bookError = error as? BookMetadataError {
                        switch bookError {
                        case .notFound:
                            sawNotFound = true
                        case .lookupFailed:
                            sawLookupFailed = true
                        }
                    } else {
                        sawLookupFailed = true
                    }
                }
            }

            if sawNotFound && !sawLookupFailed {
                return .failure(BookMetadataError.notFound)
            }
            return .failure(BookMetadataError.lookupFailed)
        }
    }
}

// MARK: - Google Books Atom feed (no API key, no daily quota)

/// The JSON Books API (`www.googleapis.com/books/v1`) shares a public quota
/// that is often exhausted. This older Atom feed still returns title, author,
/// and a cover URL without a key.
final class GoogleBooksAtomMetadataService: BookMetadataProvider {
    private let session: URLSession

    init(session: URLSession = BookLookupSession.make(timeout: 12)) {
        self.session = session
    }

    func fetchMetadata(for isbn: String) async throws -> BookMetadata {
        let parsed = try await lookup(isbn: isbn)
        return BookMetadata(title: parsed.title, author: parsed.author, isbn: isbn)
    }

    func fetchCoverImage(for isbn: String) async throws -> Data? {
        let parsed = try? await lookup(isbn: isbn)
        if let parsed, let data = await downloadUsableCover(for: parsed) {
            return data
        }
        if let parsed, let data = await searchCover(title: parsed.title, author: parsed.author) {
            return data
        }
        return nil
    }

    private func lookup(isbn: String) async throws -> AtomBook {
        var components = URLComponents(string: "https://books.google.com/books/feeds/volumes")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(isbn)"),
            URLQueryItem(name: "max-results", value: "1")
        ]
        guard let url = components?.url else { throw BookMetadataError.lookupFailed }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw BookMetadataError.lookupFailed
            }
            guard let parsed = AtomBookParser.parse(data) else {
                throw BookMetadataError.notFound
            }
            return parsed
        } catch let error as BookMetadataError {
            throw error
        } catch {
            throw BookMetadataError.lookupFailed
        }
    }

    private func downloadUsableCover(for book: AtomBook) async -> Data? {
        var urls: [URL] = []
        if let volumeID = book.volumeID {
            urls.append(contentsOf: [
                URL(string: "https://books.google.com/books/content?id=\(volumeID)&printsec=frontcover&img=1&zoom=2")
            ].compactMap { $0 })
        }
        if let coverURL = book.coverURL {
            urls.append(coverURL)
        }
        for url in urls {
            if let data = await BookLookupSession.downloadCover(from: url, session: session) {
                return data
            }
        }
        return nil
    }

    func fetchCoverImage(title: String, author: String) async -> Data? {
        await searchCover(title: title, author: author)
    }

    func searchBooks(query: String) async throws -> [BookSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw BookMetadataError.notFound }

        var components = URLComponents(string: "https://books.google.com/books/feeds/volumes")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "max-results", value: "8")
        ]
        guard let url = components?.url else { throw BookMetadataError.lookupFailed }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw BookMetadataError.lookupFailed
            }
            let books = AtomBookParser.parseAll(data)
            guard !books.isEmpty else { throw BookMetadataError.notFound }
            return books.enumerated().map { index, book in
                BookSearchHit(
                    isbn: book.volumeID.map { "gb-\($0)" } ?? "gb-\(index)-\(book.title.hashValue)",
                    title: book.title,
                    author: book.author,
                    coverURL: book.coverURL
                )
            }
        } catch let error as BookMetadataError {
            throw error
        } catch {
            throw BookMetadataError.lookupFailed
        }
    }

    private func searchCover(title: String, author: String) async -> Data? {
        var components = URLComponents(string: "https://books.google.com/books/feeds/volumes")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(title) \(author)"),
            URLQueryItem(name: "max-results", value: "5")
        ]
        guard let url = components?.url else { return nil }
        guard let data = try? await session.data(from: url).0 else { return nil }
        for volumeID in AtomBookParser.volumeIDs(in: data).prefix(5) {
            if let coverURL = URL(string: "https://books.google.com/books/content?id=\(volumeID)&printsec=frontcover&img=1&zoom=2"),
               let cover = await BookLookupSession.downloadCover(from: coverURL, session: session) {
                return cover
            }
        }
        return nil
    }
}

private struct AtomBook {
    let title: String
    let author: String
    let coverURL: URL?
    let volumeID: String?
}

private final class AtomBookParser: NSObject, XMLParserDelegate {
    private var inEntry = false
    private var currentElement = ""
    private var currentText = ""
    private var currentAttributes: [String: String] = [:]
    private var title: String?
    private var author: String?
    private var volumeID: String?
    private var thumbnail: String?
    private let limit: Int
    private var collected: [AtomBook] = []

    init(limit: Int = 1) {
        self.limit = limit
        super.init()
    }

    static func parse(_ data: Data) -> AtomBook? {
        parseAll(data, limit: 1).first
    }

    static func parseAll(_ data: Data, limit: Int = 8) -> [AtomBook] {
        let parser = XMLParser(data: data)
        let delegate = AtomBookParser(limit: limit)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.parse()
        return delegate.collected
    }

    private var book: AtomBook? {
        guard let title, !title.isEmpty else { return nil }
        return AtomBook(title: title, author: author ?? "Unknown Author", coverURL: coverURL, volumeID: volumeID)
    }

    private var coverURL: URL? {
        if let volumeID, !volumeID.isEmpty {
            return URL(string: "https://books.google.com/books/content?id=\(volumeID)&printsec=frontcover&img=1&zoom=2")
        }
        guard var thumbnail else { return nil }
        thumbnail = thumbnail.replacingOccurrences(of: "http://", with: "https://")
        thumbnail = thumbnail.replacingOccurrences(of: "zoom=5", with: "zoom=2")
        thumbnail = thumbnail.replacingOccurrences(of: "zoom=1", with: "zoom=2")
        return URL(string: thumbnail)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        currentAttributes = attributeDict
        if elementName == "entry" {
            inEntry = true
        }
        if inEntry, elementName == "link",
           attributeDict["rel"]?.contains("thumbnail") == true {
            thumbnail = attributeDict["href"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if inEntry {
            if elementName == "title", title == nil, !text.isEmpty {
                title = text
            }
            if elementName == "creator", author == nil, !text.isEmpty {
                author = text
            }
            if elementName == "id", volumeID == nil, !text.isEmpty {
                volumeID = text.split(separator: "/").last.map(String.init)
            }
        }
        if elementName == "entry" {
            if let finished = book {
                collected.append(finished)
            }
            title = nil
            author = nil
            volumeID = nil
            thumbnail = nil
            inEntry = false
            if collected.count >= limit {
                parser.abortParsing()
            }
        }
    }

    static func volumeIDs(in data: Data) -> [String] {
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        guard let regex = try? NSRegularExpression(pattern: #"feeds/volumes/([A-Za-z0-9_-]+)"#) else { return [] }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        var seen = Set<String>()
        var ids: [String] = []
        regex.enumerateMatches(in: xml, range: range) { match, _, _ in
            guard let match, let idRange = Range(match.range(at: 1), in: xml) else { return }
            let id = String(xml[idRange])
            if seen.insert(id).inserted {
                ids.append(id)
            }
        }
        return ids
    }
}

// MARK: - Google Books JSON (works on device IPs; may 429 on shared networks)

final class GoogleBooksJSONMetadataService: BookMetadataProvider {
    private let session: URLSession

    init(session: URLSession = BookLookupSession.make(timeout: 10)) {
        self.session = session
    }

    func fetchMetadata(for isbn: String) async throws -> BookMetadata {
        let parsed = try await lookup(isbn: isbn)
        return BookMetadata(title: parsed.title, author: parsed.author, isbn: isbn)
    }

    func fetchCoverImage(for isbn: String) async throws -> Data? {
        guard let url = try? await lookup(isbn: isbn).coverURL else { return nil }
        return await BookLookupSession.downloadCover(from: url, session: session)
    }

    func searchBooks(query: String) async throws -> [BookSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw BookMetadataError.notFound }

        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "maxResults", value: "8")
        ]
        guard let url = components?.url else { throw BookMetadataError.lookupFailed }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw BookMetadataError.lookupFailed
            }
            if http.statusCode == 429 {
                throw BookMetadataError.lookupFailed
            }
            guard (200...299).contains(http.statusCode) else {
                throw BookMetadataError.lookupFailed
            }
            let decoded = try JSONDecoder().decode(GoogleBooksVolumeList.self, from: data)
            let hits = (decoded.items ?? []).compactMap(\.searchHit)
            guard !hits.isEmpty else { throw BookMetadataError.notFound }
            return hits
        } catch let error as BookMetadataError {
            throw error
        } catch {
            throw BookMetadataError.lookupFailed
        }
    }

    private func lookup(isbn: String) async throws -> AtomBook {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(isbn)"),
            URLQueryItem(name: "maxResults", value: "1")
        ]
        guard let url = components?.url else { throw BookMetadataError.lookupFailed }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw BookMetadataError.lookupFailed
            }
            if http.statusCode == 429 {
                throw BookMetadataError.lookupFailed
            }
            guard (200...299).contains(http.statusCode) else {
                throw BookMetadataError.lookupFailed
            }

            let decoded = try JSONDecoder().decode(GoogleBooksVolumeList.self, from: data)
            guard let info = decoded.items?.first?.volumeInfo, let title = info.title, !title.isEmpty else {
                throw BookMetadataError.notFound
            }
            let author = info.authors?.first ?? "Unknown Author"
            var cover: URL?
            if var thumbnail = info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail {
                thumbnail = thumbnail.replacingOccurrences(of: "http://", with: "https://")
                cover = URL(string: thumbnail)
            }
            return AtomBook(title: title, author: author, coverURL: cover, volumeID: decoded.items?.first?.id)
        } catch let error as BookMetadataError {
            throw error
        } catch {
            throw BookMetadataError.lookupFailed
        }
    }
}

private struct GoogleBooksVolumeList: Decodable {
    let items: [Item]?

    struct Item: Decodable {
        let id: String?
        let volumeInfo: VolumeInfo

        var searchHit: BookSearchHit? {
            guard let title = volumeInfo.title, !title.isEmpty else { return nil }
            return BookSearchHit(
                isbn: volumeInfo.preferredISBN ?? id.map { "gb-\($0)" } ?? "gb-\(title.hashValue)",
                title: title,
                author: volumeInfo.authors?.first ?? "Unknown Author",
                coverURL: volumeInfo.coverURL
            )
        }
    }

    struct VolumeInfo: Decodable {
        let title: String?
        let authors: [String]?
        let imageLinks: ImageLinks?
        let industryIdentifiers: [IndustryIdentifier]?

        var preferredISBN: String? {
            let identifiers = industryIdentifiers ?? []
            if let isbn13 = identifiers.first(where: { $0.type == "ISBN_13" })?.identifier {
                return isbn13
            }
            return identifiers.first(where: { $0.type == "ISBN_10" })?.identifier
        }

        var coverURL: URL? {
            guard var thumbnail = imageLinks?.thumbnail ?? imageLinks?.smallThumbnail else { return nil }
            thumbnail = thumbnail.replacingOccurrences(of: "http://", with: "https://")
            thumbnail = thumbnail.replacingOccurrences(of: "zoom=1", with: "zoom=2")
            return URL(string: thumbnail)
        }
    }

    struct IndustryIdentifier: Decodable {
        let type: String
        let identifier: String
    }

    struct ImageLinks: Decodable {
        let thumbnail: String?
        let smallThumbnail: String?
    }
}

// MARK: - iTunes Search (fast, no key; misses some print-only editions)

final class ITunesBookMetadataService: BookMetadataProvider {
    private let session: URLSession

    init(session: URLSession = BookLookupSession.make(timeout: 10)) {
        self.session = session
    }

    func fetchMetadata(for isbn: String) async throws -> BookMetadata {
        let parsed = try await lookup(isbn: isbn)
        return BookMetadata(title: parsed.title, author: parsed.author, isbn: isbn)
    }

    func fetchCoverImage(for isbn: String) async throws -> Data? {
        guard let url = try? await lookup(isbn: isbn).coverURL else { return nil }
        return await BookLookupSession.downloadCover(from: url, session: session)
    }

    func fetchCoverImage(title: String, author: String) async -> Data? {
        let query = "\(title) \(author)".trimmingCharacters(in: .whitespaces)
        guard query.count >= 4 else { return nil }
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "ebook"),
            URLQueryItem(name: "limit", value: "5")
        ]
        guard let url = components?.url,
              let data = try? await session.data(from: url).0,
              let decoded = try? JSONDecoder().decode(ITunesLookup.self, from: data) else {
            return nil
        }
        for item in decoded.results {
            guard let artwork = item.artworkUrl100 else { continue }
            let large = artwork.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            guard let coverURL = URL(string: large),
                  let cover = await BookLookupSession.downloadCover(from: coverURL, session: session) else {
                continue
            }
            return cover
        }
        return nil
    }

    func searchBooks(query: String) async throws -> [BookSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw BookMetadataError.notFound }
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: "ebook"),
            URLQueryItem(name: "limit", value: "8")
        ]
        guard let url = components?.url else { throw BookMetadataError.lookupFailed }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw BookMetadataError.lookupFailed
            }
            let decoded = try JSONDecoder().decode(ITunesLookup.self, from: data)
            let hits: [BookSearchHit] = decoded.results.compactMap { item in
                let title = item.trackName ?? item.collectionName
                guard let title, !title.isEmpty else { return nil }
                var cover: URL?
                if let artwork = item.artworkUrl100 {
                    cover = URL(string: artwork.replacingOccurrences(of: "100x100bb", with: "600x600bb"))
                }
                let isbn = item.trackId.map { "itunes-\($0)" } ?? "itunes-\(title.hashValue)"
                return BookSearchHit(
                    isbn: isbn,
                    title: title,
                    author: item.artistName ?? "Unknown Author",
                    coverURL: cover
                )
            }
            guard !hits.isEmpty else { throw BookMetadataError.notFound }
            return hits
        } catch let error as BookMetadataError {
            throw error
        } catch {
            throw BookMetadataError.lookupFailed
        }
    }

    private func lookup(isbn: String) async throws -> AtomBook {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [URLQueryItem(name: "isbn", value: isbn)]
        guard let url = components?.url else { throw BookMetadataError.lookupFailed }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw BookMetadataError.lookupFailed
            }
            let decoded = try JSONDecoder().decode(ITunesLookup.self, from: data)
            guard let item = decoded.results.first else {
                throw BookMetadataError.notFound
            }
            let title = item.trackName ?? item.collectionName
            guard let title, !title.isEmpty else {
                throw BookMetadataError.notFound
            }
            var cover: URL?
            if let artwork = item.artworkUrl100 {
                let large = artwork.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                cover = URL(string: large)
            }
            return AtomBook(
                title: title,
                author: item.artistName ?? "Unknown Author",
                coverURL: cover,
                volumeID: nil
            )
        } catch let error as BookMetadataError {
            throw error
        } catch {
            throw BookMetadataError.lookupFailed
        }
    }
}

private struct ITunesLookup: Decodable {
    let results: [Item]

    struct Item: Decodable {
        let trackId: Int?
        let trackName: String?
        let collectionName: String?
        let artistName: String?
        let artworkUrl100: String?
    }
}

// MARK: - Open Library

final class OpenLibraryMetadataService: BookMetadataProvider {
    private let session: URLSession

    init(session: URLSession = BookLookupSession.make(timeout: 12)) {
        self.session = session
    }

    func fetchMetadata(for isbn: String) async throws -> BookMetadata {
        if let search = try? await search(isbn: isbn) {
            return BookMetadata(title: search.title, author: search.author, isbn: isbn)
        }
        return try await fetchBibkeys(isbn: isbn)
    }

    func fetchCoverImage(for isbn: String) async throws -> Data? {
        if let search = try? await search(isbn: isbn),
           let coverID = search.coverID,
           let url = URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg"),
           let data = await BookLookupSession.downloadCover(from: url, session: session) {
            return data
        }
        let isbnURL = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg")
        if let isbnURL, let data = await BookLookupSession.downloadCover(from: isbnURL, session: session) {
            return data
        }
        return nil
    }

    func fetchCoverImage(title: String, author: String) async -> Data? {
        let query = "\(title) \(author)".trimmingCharacters(in: .whitespaces)
        guard query.count >= 4 else { return nil }
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "title,author_name,cover_i"),
            URLQueryItem(name: "limit", value: "5")
        ]
        guard let url = components?.url,
              let data = try? await session.data(from: url).0,
              let decoded = try? JSONDecoder().decode(OpenLibrarySearch.self, from: data) else {
            return nil
        }
        for doc in decoded.docs {
            guard let coverID = doc.cover_i,
                  let coverURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg"),
                  let cover = await BookLookupSession.downloadCover(from: coverURL, session: session) else {
                continue
            }
            return cover
        }
        return nil
    }

    func searchBooks(query: String) async throws -> [BookSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw BookMetadataError.notFound }
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "fields", value: "key,title,subtitle,author_name,cover_i,isbn"),
            URLQueryItem(name: "limit", value: "8")
        ]
        guard let url = components?.url else { throw BookMetadataError.lookupFailed }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw BookMetadataError.lookupFailed
            }
            let decoded = try JSONDecoder().decode(OpenLibrarySearch.self, from: data)
            let hits: [BookSearchHit] = decoded.docs.compactMap { doc in
                guard let title = doc.title, !title.isEmpty else { return nil }
                let displayTitle: String
                if let subtitle = doc.subtitle, !subtitle.isEmpty {
                    displayTitle = "\(title): \(subtitle)"
                } else {
                    displayTitle = title
                }
                let isbn = doc.isbn?.first(where: { $0.count == 13 })
                    ?? doc.isbn?.first
                    ?? doc.key.map { "ol-\($0.replacingOccurrences(of: "/", with: "-"))" }
                    ?? "ol-\(title.hashValue)"
                var cover: URL?
                if let coverID = doc.cover_i {
                    cover = URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
                }
                return BookSearchHit(
                    isbn: isbn,
                    title: displayTitle,
                    author: doc.author_name?.first ?? "Unknown Author",
                    coverURL: cover
                )
            }
            guard !hits.isEmpty else { throw BookMetadataError.notFound }
            return hits
        } catch let error as BookMetadataError {
            throw error
        } catch {
            throw BookMetadataError.lookupFailed
        }
    }

    private struct SearchHit {
        let title: String
        let author: String
        let coverID: Int?
    }

    private func search(isbn: String) async throws -> SearchHit? {
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [
            URLQueryItem(name: "isbn", value: isbn),
            URLQueryItem(name: "fields", value: "title,subtitle,author_name,cover_i")
        ]
        guard let url = components?.url else { throw BookMetadataError.lookupFailed }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BookMetadataError.lookupFailed
        }
        let decoded = try JSONDecoder().decode(OpenLibrarySearch.self, from: data)
        guard let doc = decoded.docs.first, let title = doc.title, !title.isEmpty else {
            return nil
        }
        let displayTitle: String
        if let subtitle = doc.subtitle, !subtitle.isEmpty {
            displayTitle = "\(title): \(subtitle)"
        } else {
            displayTitle = title
        }
        return SearchHit(
            title: displayTitle,
            author: doc.author_name?.first ?? "Unknown Author",
            coverID: doc.cover_i
        )
    }

    private func fetchBibkeys(isbn: String) async throws -> BookMetadata {
        let urlString = "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data"
        guard let url = URL(string: urlString) else {
            throw BookMetadataError.lookupFailed
        }

        do {
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
        } catch let error as BookMetadataError {
            throw error
        } catch {
            throw BookMetadataError.lookupFailed
        }
    }
}

private struct OpenLibrarySearch: Decodable {
    let docs: [Doc]

    struct Doc: Decodable {
        let key: String?
        let title: String?
        let subtitle: String?
        let author_name: [String]?
        let cover_i: Int?
        let isbn: [String]?
    }
}

enum BookLookupSession {
    static func make(timeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout + 4
        configuration.httpAdditionalHeaders = [
            "User-Agent": "MyTablo/1.0 (https://github.com/adelerobertsuk/MyTablo)"
        ]
        return URLSession(configuration: configuration)
    }

    static func downloadCover(from url: URL, session: URLSession) async -> Data? {
        guard let data = await downloadImage(from: url, session: session) else { return nil }
        guard isUsableCover(data) else { return nil }
        return data
    }

    /// Google Books returns a grey "image not available" card for missing artwork.
    static func isUsableCover(_ data: Data) -> Bool {
        guard data.count > 18_000 else { return false }
        guard let image = UIImage(data: data) else { return false }
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        guard min(width, height) >= 160 else { return false }
        if Int(width.rounded()) == 300, Int(height.rounded()) == 391 {
            return false
        }
        return !isFlatGreyPlaceholder(image)
    }

    private static func isFlatGreyPlaceholder(_ image: UIImage) -> Bool {
        let sample = CGSize(width: 12, height: 12)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: sample, format: format)
        let tiny = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: sample))
        }
        guard let cgImage = tiny.cgImage else { return false }

        var minLuma: CGFloat = 1
        var maxLuma: CGFloat = 0
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        guard let provider = cgImage.dataProvider, let data = provider.data else { return false }
        let ptr = CFDataGetBytePtr(data)
        let width = cgImage.width
        let height = cgImage.height
        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * bytesPerPixel
                let r = CGFloat(ptr![i]) / 255
                let g = CGFloat(ptr![i + 1]) / 255
                let b = CGFloat(ptr![i + 2]) / 255
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                minLuma = min(minLuma, luma)
                maxLuma = max(maxLuma, luma)
            }
        }
        return (maxLuma - minLuma) < 0.18
    }

    static func downloadImage(from url: URL, session: URLSession) async -> Data? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            guard data.count > 1_000 else { return nil }
            return data
        } catch {
            return nil
        }
    }
}
