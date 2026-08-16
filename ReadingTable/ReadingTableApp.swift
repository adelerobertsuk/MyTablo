import SwiftUI
import SwiftData

/// Shared App Group identifier so the widget extension can read the same
/// SwiftData store as the main app. Must be added under Signing &
/// Capabilities → App Groups for both the ReadingTable and
/// ReadingTableWidgets targets.
let readingTableAppGroupID = "group.com.adeleroberts.ReadingTable"

@main
struct ReadingTableApp: App {
    let container: ModelContainer

    @StateObject private var libraryViewModel: LibraryViewModel
    @StateObject private var compositionViewModel: CoffeeTableCompositionViewModel

    init() {
        do {
            let schema = Schema([Book.self, CoffeeTableComposition.self, ComposedBook.self, Decoration.self])

            guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: readingTableAppGroupID) else {
                fatalError("App Group '\(readingTableAppGroupID)' is not configured. Add it under Signing & Capabilities for this target.")
            }
            let sharedStoreURL = groupURL.appendingPathComponent("ReadingTable.store")
            Self.migrateExistingStoreIfNeeded(to: sharedStoreURL)

            let modelConfiguration = ModelConfiguration(schema: schema, url: sharedStoreURL)
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }

        let context = container.mainContext
        let metadataService = OpenLibraryMetadataService()
        
        _libraryViewModel = StateObject(wrappedValue: LibraryViewModel(modelContext: context, metadataService: metadataService))
        _compositionViewModel = StateObject(wrappedValue: CoffeeTableCompositionViewModel(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            PaletteProvider {
                TabloView(
                    libraryViewModel: libraryViewModel,
                    compositionViewModel: compositionViewModel
                )
            }
        }
        .modelContainer(container)
    }

    /// One-time move of the pre-widget SwiftData store (in the app's own
    /// Application Support folder) into the shared App Group container, so
    /// existing books survive the switch to a shared store location.
    ///
    /// Tracked with a flag in shared UserDefaults rather than "does the
    /// destination file exist" — the widget can open the shared store URL
    /// too, and SwiftData auto-creates an empty database on first open, so
    /// file-existence alone isn't a reliable signal that migration happened.
    private static func migrateExistingStoreIfNeeded(to destinationURL: URL) {
        let defaults = UserDefaults(suiteName: readingTableAppGroupID)
        guard defaults?.bool(forKey: "hasMigratedToSharedStore") != true else { return }

        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldStoreURL = appSupportURL.appendingPathComponent("default.store")
        guard FileManager.default.fileExists(atPath: oldStoreURL.path) else {
            // Nothing to migrate (fresh install) — safe to mark as done.
            defaults?.set(true, forKey: "hasMigratedToSharedStore")
            return
        }

        var migrationSucceeded = true
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: oldStoreURL.path + suffix)
            let destination = URL(fileURLWithPath: destinationURL.path + suffix)
            try? FileManager.default.removeItem(at: destination)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            do {
                try FileManager.default.copyItem(at: source, to: destination)
            } catch {
                migrationSucceeded = false
            }
        }

        // Only mark as done if every file that needed copying actually copied —
        // a failed attempt should retry on the next launch, not silently give up.
        if migrationSucceeded {
            defaults?.set(true, forKey: "hasMigratedToSharedStore")
        }
    }
}
