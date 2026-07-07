import CoreLocation

struct ResolvedLocation: Equatable {
    let latitude: Double
    let longitude: Double
    let placeName: String?
}

@MainActor
protocol LocationProviding {
    func currentLocation() async -> ResolvedLocation?
}

@MainActor
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var authContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async -> ResolvedLocation? {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }

        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }

        let location: CLLocation? = await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
        guard let location else { return nil }

        return ResolvedLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            placeName: await Self.reverseGeocode(location)
        )
    }

    static func reverseGeocode(_ location: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else { return nil }
        if let landmark = placemark.areasOfInterest?.first { return landmark }
        let parts = [placemark.subLocality, placemark.locality].compactMap { $0 }
        if !parts.isEmpty { return parts.joined(separator: ", ") }
        return placemark.locality
            ?? placemark.administrativeArea
            ?? placemark.name
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        Task { @MainActor in
            authContinuation?.resume()
            authContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.last)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}
