import Combine
import EventKit
import Foundation

@MainActor
final class CalendarService: ObservableObject {
    struct EventSummary: Identifiable {
        let id: String
        let title: String
    }

    @Published var todaysEvents: [EventSummary] = []
    @Published var accessDenied = false

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?

    init() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchTodaysEvents()
            }
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func requestAccessAndFetchTodaysEvents() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            accessDenied = !granted
            if granted {
                fetchTodaysEvents()
            }
        } catch {
            accessDenied = true
        }
    }

    private func fetchTodaysEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        todaysEvents = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { EventSummary(id: $0.eventIdentifier, title: $0.title) }
    }
}
