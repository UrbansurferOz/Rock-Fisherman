import Foundation
import CoreLocation
import Combine

class LocationSearchService: ObservableObject {
    @Published var searchResults: [LocationResult] = []
    @Published var isSearching = false
    @Published var searchError: String?
    
    private let geocoder = CLGeocoder()
    private var searchCancellable: AnyCancellable?
    
    func searchLocations(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        // Cancel any previous search
        searchCancellable?.cancel()
        
        // Debounce the search to avoid too many API calls
        searchCancellable = Just(query)
            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] searchQuery in
                self?.performSearch(query: searchQuery)
            }
    }
    
    private func performSearch(query: String) {
        geocoder.geocodeAddressString(query) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    self?.searchError = "Location search failed: \(error.localizedDescription)"
                    self?.searchResults = []
                    return
                }
                
                guard let placemarks = placemarks else {
                    print("No placemarks returned for query: \(query)")
                    self?.searchResults = []
                    return
                }
                
                print("Found \(placemarks.count) placemarks for query: \(query)")
                
                self?.searchResults = placemarks.compactMap { placemark in
                    guard let location = placemark.location else { 
                        print("Placemark has no location: \(placemark)")
                        return nil 
                    }
                    
                    let name = self?.formatLocationName(placemark) ?? "Unknown Location"
                    let country = placemark.country ?? ""
                    let state = placemark.administrativeArea ?? ""
                    let city = placemark.locality ?? ""
                    
                    let result = LocationResult(
                        name: name,
                        city: city,
                        state: state,
                        country: country,
                        coordinate: location.coordinate
                    )
                    
                    print("Created result: \(result.name) at (\(result.coordinate.latitude), \(result.coordinate.longitude))")
                    return result
                }
                
                print("Final search results count: \(self?.searchResults.count ?? 0)")
            }
        }
    }
    
    private func formatLocationName(_ placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        // Try to get the most specific name first
        if let locality = placemark.locality, !locality.isEmpty {
            components.append(locality)
        } else if let name = placemark.name, !name.isEmpty {
            components.append(name)
        }
        
        if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
            components.append(administrativeArea)
        }
        
        if let country = placemark.country, !country.isEmpty {
            components.append(country)
        }
        
        // If we still don't have a name, use the coordinate as fallback
        if components.isEmpty {
            let lat = String(format: "%.4f", placemark.location?.coordinate.latitude ?? 0)
            let lon = String(format: "%.4f", placemark.location?.coordinate.longitude ?? 0)
            components.append("Location (\(lat), \(lon))")
        }
        
        return components.joined(separator: ", ")
    }
    
    func clearSearch() {
        searchResults = []
        searchError = nil
        isSearching = false
    }
}

// MARK: - Location Result Model
struct LocationResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let city: String
    let state: String
    let country: String
    let coordinate: CLLocationCoordinate2D
    
    var displayName: String {
        if city.isEmpty && state.isEmpty && country.isEmpty {
            return name
        }
        
        var components: [String] = []
        if !city.isEmpty { components.append(city) }
        if !state.isEmpty { components.append(state) }
        if !country.isEmpty { components.append(country) }
        
        return components.joined(separator: ", ")
    }
    
    static func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
