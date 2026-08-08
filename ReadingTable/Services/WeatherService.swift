import Combine
import CoreLocation
import Foundation
import WeatherKit

@MainActor
final class WeatherService: NSObject, ObservableObject {
    static let shared = WeatherService()

    @Published var temperature: String = "--°"
    @Published var condition: String = ""
    @Published var symbolName: String = "cloud.fill"
    @Published var accessDenied = false
    @Published var isLoading = true
    @Published var fetchFailed = false

    private let locationManager = CLLocationManager()
    private let weatherKitService = WeatherKit.WeatherService.shared
    private var lastAttemptDate: Date?
    private let minimumRetryInterval: TimeInterval = 30

    override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Called both on first appear and every time the app comes back to the foreground.
    /// Without a minimum interval, switching away from the app and back (e.g. to dictate a
    /// message) restarts the whole "Reading the sky…" → fetch cycle each time, which on a
    /// device that can't get a fast location fix looks like the object flickering/popping.
    func requestLocationAndFetchWeather() {
        if let lastAttemptDate, Date().timeIntervalSince(lastAttemptDate) < minimumRetryInterval, !isLoading {
            return
        }
        lastAttemptDate = Date()
        switch locationManager.authorizationStatus {
        case .notDetermined:
            isLoading = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            accessDenied = false
            isLoading = true
            fetchFailed = false
            locationManager.requestLocation()
            startTimeoutWatch()
        case .denied, .restricted:
            isLoading = false
            accessDenied = true
        @unknown default:
            break
        }
    }

    private func fetchWeather(for location: CLLocation) async {
        do {
            let weather = try await weatherKitService.weather(for: location)
            let current = weather.currentWeather
            temperature = current.temperature.formatted(
                .measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))
            )
            condition = current.condition.description
            symbolName = current.symbolName
            fetchFailed = false
        } catch {
            fetchFailed = true
            print("WeatherKit fetch failed: \(error)")
        }
        isLoading = false
    }

    /// `CLLocationManager.requestLocation()` can hang indefinitely with no callback at all when
    /// no fix is available (e.g. a Wi-Fi-only iPad indoors, with no GPS chip and no known network
    /// to triangulate from) — this turns that silent hang into the same honest "unavailable"
    /// message used for a real fetch failure, instead of "Reading the sky…" forever.
    private func startTimeoutWatch() {
        Task {
            try? await Task.sleep(for: .seconds(15))
            guard self.isLoading else { return }
            self.isLoading = false
            self.fetchFailed = true
        }
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.accessDenied = false
                self.isLoading = true
                self.fetchFailed = false
                manager.requestLocation()
                self.startTimeoutWatch()
            case .denied, .restricted:
                self.accessDenied = true
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await self.fetchWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
            self.fetchFailed = true
        }
    }
}
