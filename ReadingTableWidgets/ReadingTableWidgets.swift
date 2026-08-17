import WidgetKit
import SwiftUI
import UIKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tableImage: WidgetSnapshot.loadImage())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), tableImage: WidgetSnapshot.loadImage()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = SimpleEntry(date: Date(), tableImage: WidgetSnapshot.loadImage())
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tableImage: UIImage?
}

struct ReadingTableWidgetsEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        TableWidgetView(tableImage: entry.tableImage)
    }
}

struct ReadingTableWidgets: Widget {
    /// New kind so iOS cannot keep showing the old cropped preview.
    let kind: String = "MyTabloYourTable"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReadingTableWidgetsEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Palette.light.bg
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Your table")
        .description("A mini picture of your table.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
