import Combine
import CoreLocation
import Foundation
import WeatherKit

@MainActor
final class WeatherService: NSObject, ObservableObject {
    @Published var temperature: String = "--°"
    @Published var condition: String = ""
    @Published var symbolName: String = "cloud.fill"
    @Published var accessDenied = false
    @Published var isLoading = true
    @Published var fetchFailed = false

    private let locationManager = CLLocationManager()
    private let weatherKitService = WeatherKit.WeatherService.shared

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocationAndFetchWeather() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            isLoading = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            accessDenied = false
            isLoading = true
            fetchFailed = false
            locationManager.requestLocation()
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
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.accessDenied = false
                manager.requestLocation()
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
