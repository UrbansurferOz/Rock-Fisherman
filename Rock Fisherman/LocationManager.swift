import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastLocationTimestamp: Date?
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var hasSelectedLocation = false
    @Published var selectedLocationName: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Initialize with the current authorization to avoid stale state
        if #available(iOS 14.0, *) {
            self.authorizationStatus = locationManager.authorizationStatus
        } else {
            self.authorizationStatus = CLLocationManager.authorizationStatus()
        }
    }
    
    func requestLocation() {
        DispatchQueue.main.async {
            self.isLoading = true

            guard CLLocationManager.locationServicesEnabled() else {
                print("LocationManager: Location services are disabled")
                self.isLoading = false
                return
            }

            let status: CLAuthorizationStatus
            if #available(iOS 14.0, *) {
                status = self.locationManager.authorizationStatus
            } else {
                status = CLLocationManager.authorizationStatus()
            }

            // Keep our published status in sync with the system value
            self.authorizationStatus = status

            switch status {
            case .notDetermined:
                print("LocationManager: Requesting WhenInUse authorization")
                self.locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                // If we have a recent cached location (<3 min), reuse it immediately for speed
                if let loc = self.location, let ts = self.lastLocationTimestamp, Date().timeIntervalSince(ts) < 180 {
                    print("LocationManager: Using cached location (<3m old)")
                    self.setLocation(loc, name: "Current Location")
                } else {
                    print("LocationManager: Authorized — requesting one-shot location due to user action")
                    self.locationManager.requestLocation()
                }
            case .denied, .restricted:
                print("LocationManager: Permission denied/restricted")
                self.isLoading = false
            @unknown default:
                print("LocationManager: Unknown authorization status")
                self.isLoading = false
            }
        }
    }
    
    func setLocation(_ location: CLLocation, name: String? = nil) {
        print("LocationManager.setLocation called with: \(name ?? "unnamed") at (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("LocationManager.setLocation: Previous state - hasSelectedLocation: \(hasSelectedLocation), selectedLocationName: \(selectedLocationName ?? "nil")")
        
        self.location = location
        self.hasSelectedLocation = true
        self.selectedLocationName = name
        self.isLoading = false
        
        print("LocationManager.setLocation: New state - hasSelectedLocation: \(hasSelectedLocation), selectedLocationName: \(selectedLocationName ?? "nil")")
        print("LocationManager.setLocation: Location set successfully")
    }
    
    func clearLocation() {
        self.location = nil
        self.hasSelectedLocation = false
        self.selectedLocationName = nil
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            // Prefer high-accuracy/recency, but accept first update quickly to improve perceived speed
            if self.location == nil || location.horizontalAccuracy <= (self.location?.horizontalAccuracy ?? .greatestFiniteMagnitude) {
                self.location = location
                self.lastLocationTimestamp = Date()
                self.hasSelectedLocation = true

                // Reverse geocode to show a meaningful place name instead of a generic label
                self.geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                    DispatchQueue.main.async {
                        if let p = placemarks?.first {
                            let locality = [p.subLocality, p.locality].compactMap { $0 }.first
                            let admin = p.administrativeArea
                            let country = p.country
                            let parts = [locality, admin, country].compactMap { $0 }.filter { !$0.isEmpty }
                            self.selectedLocationName = parts.isEmpty ? "Current Location" : parts.joined(separator: ", ")
                        } else {
                            self.selectedLocationName = "Current Location"
                        }
                    }
                }
            }
            self.isLoading = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            print("Location error: \(error.localizedDescription)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Keep for backward compatibility; iOS 14+ will also call locationManagerDidChangeAuthorization
        handleAuthorizationChange(currentStatus: status)
    }

    // iOS 14+ preferred callback
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        handleAuthorizationChange(currentStatus: status)
    }

    private func handleAuthorizationChange(currentStatus status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            print("LocationManager: Authorization status changed from \(self.authorizationStatus) to \(status)")
            self.authorizationStatus = status

            guard CLLocationManager.locationServicesEnabled() else {
                print("LocationManager: Location services disabled")
                self.isLoading = false
                return
            }

            // Do not auto-request; wait until user explicitly selects current location
            print("LocationManager: Authorization change handled (no auto location request)")
        }
    }
}
