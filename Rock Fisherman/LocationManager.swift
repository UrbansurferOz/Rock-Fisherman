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
    }
    
    func requestLocation() {
        isLoading = true
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            isLoading = false
        @unknown default:
            isLoading = false
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
            self.location = location
            self.hasSelectedLocation = true
            self.selectedLocationName = "Current Location"
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
        DispatchQueue.main.async {
            print("LocationManager: Authorization status changed from \(self.authorizationStatus) to \(status)")
            self.authorizationStatus = status
            
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
