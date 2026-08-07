import SwiftUI
import SwiftData

@main
struct ReadingTableApp: App {
    let container: ModelContainer
    
    @StateObject private var libraryViewModel: LibraryViewModel
    @StateObject private var compositionViewModel: CoffeeTableCompositionViewModel

    init() {
        do {
            let schema = Schema([Book.self, CoffeeTableComposition.self, ComposedBook.self, Decoration.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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
            TabloView(
                libraryViewModel: libraryViewModel,
                compositionViewModel: compositionViewModel
            )
        }
        .modelContainer(container)
    }
}
