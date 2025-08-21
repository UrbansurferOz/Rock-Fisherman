import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastLocationTimestamp: Date?
    private let locDebug: Bool = ProcessInfo.processInfo.environment["LOC_DEBUG"] == "1"
    // Track when the user explicitly requested current location so we can
    // request a fix after permission is granted
    private var pendingRequestAfterAuth = false
    // Force accept next location update regardless of accuracy when user explicitly requests
    private var forceAcceptNextLocationUpdate = false
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var hasSelectedLocation = false
    @Published var selectedLocationName: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Do not poll authorization synchronously; rely on delegate callbacks to sync state
    }
    
    func requestLocation() {
        // Update UI state on main
        DispatchQueue.main.async { self.isLoading = true }

        guard CLLocationManager.locationServicesEnabled() else {
            if locDebug { print("[Loc] location services disabled") }
            DispatchQueue.main.async { self.isLoading = false }
            return
        }

        // Avoid querying manager.authorizationStatus on the main thread; use our stored value
        let status: CLAuthorizationStatus = self.authorizationStatus
        if locDebug { print("[Loc] requestLocation status=\(status.rawValue) hasSelected=\(self.hasSelectedLocation)") }

        switch status {
        case .notDetermined:
            // Remember that the user explicitly asked for a location so we can
            // request it once permission changes to authorized
            pendingRequestAfterAuth = true
            if locDebug { print("[Loc] requesting when-in-use authorization") }
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Immediately reuse a recent cached location (<2 minutes) for faster perceived response
            if let lastTs = self.lastLocationTimestamp, let current = self.location {
                if Date().timeIntervalSince(lastTs) < 120 {
                    if locDebug { print("[Loc] reusing cached fix age=\(Int(Date().timeIntervalSince(lastTs)))s, triggering UI refresh") }
                    DispatchQueue.main.async {
                        // setLocation copies and re-publishes to trigger observers
                        self.setLocation(current, name: self.selectedLocationName)
                    }
                }
            }
            forceAcceptNextLocationUpdate = true
            if locDebug { print("[Loc] requesting one-shot location fix (off-main)") }
            DispatchQueue.global(qos: .userInitiated).async {
                self.locationManager.requestLocation()
            }
        case .denied, .restricted:
            if locDebug { print("[Loc] authorization denied/restricted") }
            DispatchQueue.main.async { self.isLoading = false }
        @unknown default:
            if locDebug { print("[Loc] unknown authorization status") }
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
    
    func setLocation(_ location: CLLocation, name: String? = nil) {
        if locDebug {
            print("[Loc] setLocation lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude), acc=\(location.horizontalAccuracy)")
        }
        
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
            if self.forceAcceptNextLocationUpdate || self.location == nil || location.horizontalAccuracy <= (self.location?.horizontalAccuracy ?? .greatestFiniteMagnitude) {
                if self.locDebug { print("[Loc] didUpdateLocations lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude), acc=\(location.horizontalAccuracy)") }
                self.location = location
                self.lastLocationTimestamp = Date()
                self.hasSelectedLocation = true
                self.forceAcceptNextLocationUpdate = false

                // Reverse geocode to show a meaningful place name instead of a generic label
                self.geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                    DispatchQueue.main.async {
                        if let p = placemarks?.first {
                            let locality = [p.subLocality, p.locality].compactMap { $0 }.first
                            let admin = p.administrativeArea
                            let country = p.country
                            let parts = [locality, admin, country].compactMap { $0 }.filter { !$0.isEmpty }
                            self.selectedLocationName = parts.isEmpty ? "Current Location" : parts.joined(separator: ", ")
                            if self.locDebug { print("[Loc] reverse geocoded name=\(self.selectedLocationName ?? "-")") }
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
            if self.locDebug { print("[Loc] didFailWithError: \(error.localizedDescription)") }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Deprecated in favor of locationManagerDidChangeAuthorization on iOS 14+; keep for completeness
        handleAuthorizationChange(currentStatus: status)
    }

    // iOS 14+ preferred callback
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus = manager.authorizationStatus
        handleAuthorizationChange(currentStatus: status)
    }

    private func handleAuthorizationChange(currentStatus status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            if self.locDebug { print("[Loc] authorization changed -> \(status.rawValue)") }
            self.authorizationStatus = status

            guard CLLocationManager.locationServicesEnabled() else {
                // Debug logs removed
                self.isLoading = false
                return
            }

            // If the user explicitly tapped "Use Current Location" while notDetermined,
            // request a fresh fix now that we are authorized.
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && self.pendingRequestAfterAuth {
                self.pendingRequestAfterAuth = false
                self.forceAcceptNextLocationUpdate = true
                if self.locDebug { print("[Loc] post-auth requesting location (off-main)") }
                DispatchQueue.global(qos: .userInitiated).async {
                    self.locationManager.requestLocation()
                }
            }
        }
    }
}
