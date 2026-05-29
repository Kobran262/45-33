import CoreLocation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func refreshLocation() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.requestLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorization = manager.authorizationStatus
            if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            currentLocation = loc.coordinate
            errorMessage = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
        }
    }
}
