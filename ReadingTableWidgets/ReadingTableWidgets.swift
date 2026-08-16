import WidgetKit
import SwiftUI
import SwiftData

/// Must match `readingTableAppGroupID` in the main app's ReadingTableApp.swift —
/// each target defines its own copy since App Extension targets can't share
/// the app's entry-point file.
private let appGroupID = "group.com.adeleroberts.ReadingTable"

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), book: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), book: Self.fetchCurrentRead() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = SimpleEntry(date: Date(), book: Self.fetchCurrentRead() ?? .sample)
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    /// Prefers the book the user has explicitly flagged as "currently reading";
    /// falls back to the most recently added book if none is flagged.
    private static func fetchCurrentRead() -> CurrentReadPreview? {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let storeURL = groupURL.appendingPathComponent("ReadingTable.store")

        // Don't let the widget be the one to create the shared store — if
        // the main app hasn't migrated the real data there yet, opening a
        // missing store here would create an empty one and block that
        // migration from ever copying the real data in.
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }

        do {
            let schema = Schema([Book.self, CoffeeTableComposition.self, ComposedBook.self, Decoration.self])
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            var currentlyReadingDescriptor = FetchDescriptor<Book>(
                predicate: #Predicate { $0.isCurrentlyReading },
                sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
            )
            currentlyReadingDescriptor.fetchLimit = 1

            var mostRecentDescriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.addedDate, order: .reverse)])
            mostRecentDescriptor.fetchLimit = 1

            let book = try context.fetch(currentlyReadingDescriptor).first ?? (try context.fetch(mostRecentDescriptor).first)
            guard let book else { return nil }

            let coverImage = book.coverImageData.flatMap { UIImage(data: $0) }
            return CurrentReadPreview(title: book.title, author: book.author, coverImage: coverImage)
        } catch {
            return nil
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let book: CurrentReadPreview
}

struct ReadingTableWidgetsEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        SmallWidgetView(book: entry.book)
    }
}

struct ReadingTableWidgets: Widget {
    let kind: String = "ReadingTableWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReadingTableWidgetsEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Current read")
        .description("The book on your table.")
        .supportedFamilies([.systemSmall])
    }
}
