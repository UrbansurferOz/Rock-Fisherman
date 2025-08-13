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
                // Debug logs removed
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
                // Debug logs removed
                self.locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                // If we have a recent cached location (<3 min), reuse it immediately for speed
                // Always request a fresh fix so the user sees an update even if location is unchanged.
                // We'll still use cached quickly if it arrives later via delegate.
                // Debug logs removed
                self.locationManager.requestLocation()
            case .denied, .restricted:
                // Debug logs removed
                self.isLoading = false
            @unknown default:
                // Debug logs removed
                self.isLoading = false
            }
        }
    }
    
    func setLocation(_ location: CLLocation, name: String? = nil) {
        // Debug logs removed
        
        // Force a new instance so SwiftUI change handlers fire even if coords are the same
        let copied = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        self.location = copied
        self.hasSelectedLocation = true
        self.selectedLocationName = name
        self.isLoading = false
        
        // Debug logs removed
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
            // Debug logs removed
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
            // Debug logs removed
            self.authorizationStatus = status

            guard CLLocationManager.locationServicesEnabled() else {
                // Debug logs removed
                self.isLoading = false
                return
            }

            // Do not auto-request; wait until user explicitly selects current location
            // Debug logs removed
        }
    }
}
