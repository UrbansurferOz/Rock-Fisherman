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
        // Create a more specific search query
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First try to search with more specific parameters
        geocoder.geocodeAddressString(searchQuery) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    self?.searchError = "Location search failed: \(error.localizedDescription)"
                    self?.searchResults = []
                    return
                }
                
                guard let placemarks = placemarks else {
                    print("No placemarks returned for query: \(searchQuery)")
                    self?.searchResults = []
                    return
                }
                
                print("Found \(placemarks.count) placemarks for query: \(searchQuery)")
                
                // Filter and rank the results for better accuracy
                let filteredResults = self?.filterAndRankResults(placemarks, for: searchQuery) ?? []
                
                self?.searchResults = filteredResults
                print("Final filtered results count: \(filteredResults.count)")
            }
        }
    }
    
    private func filterAndRankResults(_ placemarks: [CLPlacemark], for query: String) -> [LocationResult] {
        let queryLower = query.lowercased()
        
        return placemarks.compactMap { placemark in
            guard let location = placemark.location else { 
                print("Placemark has no location: \(placemark)")
                return nil 
            }
            
            let name = formatLocationName(placemark)
            let country = placemark.country ?? ""
            let state = placemark.administrativeArea ?? ""
            let city = placemark.locality ?? ""
            let subLocality = placemark.subLocality ?? ""
            
            // Create result with additional metadata for ranking
            let result = LocationResult(
                name: name,
                city: city,
                state: state,
                country: country,
                subLocality: subLocality,
                coordinate: location.coordinate,
                searchScore: calculateSearchScore(placemark, query: queryLower)
            )
            
            print("Created result: \(result.name) at (\(result.coordinate.latitude), \(result.coordinate.longitude)) with score: \(result.searchScore)")
            return result
        }
        .sorted { $0.searchScore > $1.searchScore } // Sort by relevance score
        .prefix(10) // Limit to top 10 results
        .map { $0 }
    }
    
    private func calculateSearchScore(_ placemark: CLPlacemark, query: String) -> Int {
        var score = 0
        let queryLower = query.lowercased()
        
        // Exact name match gets highest score
        if let name = placemark.name?.lowercased(), name.contains(queryLower) {
            score += 100
        }
        
        // Locality (city) match
        if let locality = placemark.locality?.lowercased(), locality.contains(queryLower) {
            score += 80
        }
        
        // Sub-locality match (suburb, neighborhood)
        if let subLocality = placemark.subLocality?.lowercased(), subLocality.contains(queryLower) {
            score += 70
        }
        
        // Administrative area (state) match
        if let adminArea = placemark.administrativeArea?.lowercased(), adminArea.contains(queryLower) {
            score += 50
        }
        
        // Country match
        if let country = placemark.country?.lowercased(), country.contains(queryLower) {
            score += 30
        }
        
        // Bonus for Australian locations (assuming this is for Australian fishing)
        if let country = placemark.country, country.lowercased() == "australia" {
            score += 20
        }
        
        // Bonus for coastal locations (better for fishing)
        if let locality = placemark.locality {
            let coastalKeywords = ["beach", "bay", "harbour", "port", "cove", "creek", "river", "lake"]
            if coastalKeywords.contains(where: { locality.lowercased().contains($0) }) {
                score += 15
            }
        }
        
        return score
    }
    
    private func formatLocationName(_ placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        // Try to get the most specific name first
        if let subLocality = placemark.subLocality, !subLocality.isEmpty {
            components.append(subLocality)
        } else if let locality = placemark.locality, !locality.isEmpty {
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
    let subLocality: String
    let coordinate: CLLocationCoordinate2D
    let searchScore: Int
    
    var displayName: String {
        var components: [String] = []
        
        // Show sub-locality if available (more specific)
        if !subLocality.isEmpty { components.append(subLocality) }
        if !city.isEmpty { components.append(city) }
        if !state.isEmpty { components.append(state) }
        if !country.isEmpty { components.append(country) }
        
        // If we have multiple components, join them
        if components.count > 1 {
            return components.joined(separator: ", ")
        } else if components.count == 1 {
            return components[0]
        } else {
            return name
        }
    }
    
    static func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
