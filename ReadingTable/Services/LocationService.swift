import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var placeName: String = "Locating…"
    @Published var accessDenied = false

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocationAndFetchPlace() {
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

    private func fetchPlaceName(for location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                placeName = placemark.locality ?? placemark.administrativeArea ?? placemark.country ?? "Unknown location"
            } else {
                placeName = "Unknown location"
            }
        } catch {
            placeName = "Location unavailable"
            print("Reverse geocoding failed: \(error)")
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
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
            await self.fetchPlaceName(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Best-effort decoration; leave the last-known state on screen rather than showing an error.
    }
}
