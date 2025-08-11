import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
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
                print("LocationManager: Authorized, requesting one-shot location")
                // If we already have a recent location (last few minutes), reuse it to speed up UX
                if let cached = self.locationManager.location, Date().timeIntervalSince(cached.timestamp) < 180 {
                    print("LocationManager: Using cached location (age < 3 min)")
                    self.location = cached
                    self.hasSelectedLocation = true
                    self.selectedLocationName = "Current Location"
                    self.isLoading = false
                } else {
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
                self.hasSelectedLocation = true
                self.selectedLocationName = "Current Location"
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

            // Only request location if we don't already have a manually selected location
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && !self.hasSelectedLocation {
                print("LocationManager: Requesting location due to authorization change")
                self.locationManager.requestLocation()
            } else {
                print("LocationManager: Skipping location request (hasSelectedLocation: \(self.hasSelectedLocation))")
            }
        }
    }
}
