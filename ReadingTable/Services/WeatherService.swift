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

    private let locationManager = CLLocationManager()
    private let weatherKitService = WeatherKit.WeatherService.shared

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocationAndFetchWeather() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            accessDenied = false
            locationManager.requestLocation()
        case .denied, .restricted:
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
        } catch {
            condition = "Weather unavailable"
            print("WeatherKit fetch failed: \(error)")
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
        // Best-effort decoration; leave the last-known state on screen rather than showing an error.
    }
}
