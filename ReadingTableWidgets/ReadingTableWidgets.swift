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

    /// Placeholder "current read" logic: just the most recently added book.
    /// There's no real currently-reading flag on `Book` yet.
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

            var descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.addedDate, order: .reverse)])
            descriptor.fetchLimit = 1
            guard let latestBook = try context.fetch(descriptor).first else { return nil }

            let coverImage = latestBook.coverImageData.flatMap { UIImage(data: $0) }
            return CurrentReadPreview(title: latestBook.title, author: latestBook.author, coverImage: coverImage)
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Current Read")
        .description("Shows the book you're currently reading.")
        .supportedFamilies([.systemSmall])
    }
}
