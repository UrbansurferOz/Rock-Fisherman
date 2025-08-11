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

        geocoder.geocodeAddressString(searchQuery) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSearching = false

                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    self.searchError = "Location search failed: \(error.localizedDescription)"
                    self.searchResults = []
                    return
                }

                guard let placemarks = placemarks, !placemarks.isEmpty else {
                    print("No placemarks returned for query: \(searchQuery)")
                    self.searchResults = []
                    return
                }

                print("Found \(placemarks.count) placemarks for query: \(searchQuery)")

                // Filter and rank the results for better accuracy
                let filteredResults = self.filterAndRankResults(placemarks, for: searchQuery)

                self.searchResults = filteredResults
                print("Final filtered results count: \(filteredResults.count)")
            }
        }
    }
    
    private func filterAndRankResults(_ placemarks: [CLPlacemark], for query: String) -> [LocationResult] {
        let queryLower = query.lowercased()

        // Build scored results and drop unrelated ones entirely
        var results: [LocationResult] = placemarks.compactMap { placemark in
            guard let location = placemark.location else {
                print("Placemark has no location: \(placemark)")
                return nil
            }

            // Prefer places (suburb/city/state) over street-level name matches.
            let sub = placemark.subLocality?.lowercased() ?? ""
            let loc = placemark.locality?.lowercased() ?? ""
            let admin = placemark.administrativeArea?.lowercased() ?? ""

            let matchesSub = !sub.isEmpty && (sub.hasPrefix(queryLower) || sub.contains(queryLower))
            let matchesLoc = !loc.isEmpty && (loc.hasPrefix(queryLower) || loc.contains(queryLower))
            let matchesAdminPrefix = !admin.isEmpty && admin.hasPrefix(queryLower)

            // Filter out results that only match a street/POI name (e.g., "Curl Rd" in Pomeroy)
            guard matchesSub || matchesLoc || matchesAdminPrefix else { return nil }

            let name = formatLocationName(placemark)
            let country = placemark.country ?? ""
            let state = placemark.administrativeArea ?? ""
            let city = placemark.locality ?? ""
            let subLocality = placemark.subLocality ?? ""

            let score = calculateSearchScore(placemark, query: queryLower)

            let result = LocationResult(
                name: name,
                city: city,
                state: state,
                country: country,
                subLocality: subLocality,
                coordinate: location.coordinate,
                searchScore: score
            )

            print("Created result: \(result.name) score=\(result.searchScore)")
            return result
        }

        // Prefer Australian results if any exist
        let australian = results.filter { $0.country.lowercased() == "australia" }
        if !australian.isEmpty {
            results = australian + results.filter { $0.country.lowercased() != "australia" }
        }

        // Sort by score descending and limit
        results.sort { $0.searchScore > $1.searchScore }
        return Array(results.prefix(10))
    }
    
    private func calculateSearchScore(_ placemark: CLPlacemark, query: String) -> Int {
        let q = query.lowercased()

        func score(_ text: String?) -> Int {
            guard let t = text?.lowercased() else { return 0 }
            var s = 0
            if t.hasPrefix(q) { s += 120 }
            if t.contains(q) { s += 60 }
            return s
        }

        var scoreTotal = 0
        // Strongest signal: suburb/neighbourhood (subLocality) and city (locality)
        scoreTotal += Int(Double(score(placemark.subLocality)) * 1.5)
        scoreTotal += Int(Double(score(placemark.locality)) * 1.2)
        // We deliberately do NOT score placemark.name to avoid roads like "Curl Rd" dominating
        scoreTotal += Int(Double(score(placemark.administrativeArea)) * 0.6)
        scoreTotal += Int(Double(score(placemark.country)) * 0.2)

        // Bias to Australia
        if placemark.country?.lowercased() == "australia" { scoreTotal += 40 }

        // Coastal keywords boost
        if let locality = placemark.locality?.lowercased() {
            let coastalKeywords = ["beach", "bay", "harbour", "port", "cove", "creek", "river", "lake"]
            if coastalKeywords.contains(where: { locality.contains($0) }) { scoreTotal += 15 }
        }

        return scoreTotal
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
