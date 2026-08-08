import Foundation
import SwiftData

@Model
final class Book: Identifiable {
    @Attribute(.unique) var isbn: String
    var title: String
    var author: String
    var coverImageData: Data?
    var addedDate: Date
    var isCurrentlyReading: Bool = false

    init(
        isbn: String,
        title: String,
        author: String,
        coverImageData: Data? = nil,
        addedDate: Date = Date(),
        isCurrentlyReading: Bool = false
    ) {
        self.isbn = isbn
        self.title = title
        self.author = author
        self.coverImageData = coverImageData
        self.addedDate = addedDate
        self.isCurrentlyReading = isCurrentlyReading
    }
}

@Model
final class CoffeeTableComposition: Identifiable {
    var name: String
    var createdDate: Date
    var items: [ComposedBook]
    var decorations: [Decoration] = []
    var surfaceImageName: String = "Kate-table-WhitePlaster"

    init(name: String, items: [ComposedBook] = [], decorations: [Decoration] = [], createdDate: Date = Date(), surfaceImageName: String = "Kate-table-WhitePlaster") {
        self.name = name
        self.items = items
        self.decorations = decorations
        self.createdDate = createdDate
        self.surfaceImageName = surfaceImageName
    }
}

@Model
final class ComposedBook: Identifiable {
    var book: Book?
    var x: Double = 150
    var y: Double = 200
    var rotation: Double = 0
    var scale: Double = 1.0
    var zIndex: Double = 0

    init(book: Book? = nil, x: Double = 150, y: Double = 200, rotation: Double = 0, scale: Double = 1.0, zIndex: Double = 0) {
        self.book = book
        self.x = x
        self.y = y
        self.rotation = rotation
        self.scale = scale
        self.zIndex = zIndex
    }
}
