import Foundation
import CoreLocation
import Combine

class LocationSearchService: ObservableObject {
    @Published var searchResults: [LocationResult] = []
    @Published var isSearching = false
    @Published var searchError: String?
    
    private let geocoder = CLGeocoder()
    private var searchCancellable: AnyCancellable?
    // Preferred country derived from device settings to bias and scope results
    private let preferredRegionCode: String = {
        if #available(iOS 16.0, *) {
            return Locale.current.region?.identifier ?? ""
        } else {
            return Locale.current.regionCode ?? ""
        }
    }()
    private var preferredCountryName: String {
        guard !preferredRegionCode.isEmpty else { return "" }
        return Locale.current.localizedString(forRegionCode: preferredRegionCode) ?? ""
    }
    
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
        let rawQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try scoping to user's country first (e.g., "Clarev, Australia")
        let countryScopedQuery: String? = preferredCountryName.isEmpty ? nil : "\(rawQuery), \(preferredCountryName)"

        func handleResponse(_ usedQuery: String, placemarks: [CLPlacemark]?, error: Error?) {
            DispatchQueue.main.async {
                self.isSearching = false
                if let error = error {
                    print("Geocoding error for query=\(usedQuery): \(error.localizedDescription)")
                    self.searchError = "Location search failed: \(error.localizedDescription)"
                    self.searchResults = []
                    return
                }
                let returned = placemarks ?? []
                print("Geocoder returned \(returned.count) placemarks for query=\(usedQuery)")
                guard !returned.isEmpty else {
                    self.searchResults = []
                    return
                }
                let filteredResults = self.filterAndRankResults(returned, for: rawQuery)
                self.searchResults = filteredResults
                print("Final filtered count=\(filteredResults.count)")
                for r in filteredResults { print("Result: \(r.displayName) [score=\(r.searchScore)]") }
            }
        }

        if let scoped = countryScopedQuery {
            print("Searching (scoped): \(scoped)")
            geocoder.geocodeAddressString(scoped) { [weak self] placemarks, error in
                // If nothing found with scoped search, fall back to raw
                if (placemarks?.isEmpty ?? true) {
                    print("Scoped search returned no results; falling back to raw query: \(rawQuery)")
                    self?.geocoder.geocodeAddressString(rawQuery) { placemarks2, error2 in
                        handleResponse(rawQuery, placemarks: placemarks2, error: error2)
                    }
                } else {
                    handleResponse(scoped, placemarks: placemarks, error: error)
                }
            }
        } else {
            print("Searching (raw): \(rawQuery)")
            geocoder.geocodeAddressString(rawQuery) { placemarks, error in
                handleResponse(rawQuery, placemarks: placemarks, error: error)
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

            // Keep placemark if any relevant field contains the query
            let fields: [String] = [
                placemark.subLocality,
                placemark.locality,
                placemark.name, // still considered, but scored lower
                placemark.administrativeArea,
                placemark.country
            ].compactMap { $0?.lowercased() }
            guard fields.contains(where: { $0.contains(queryLower) }) else { return nil }

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

        // Bias to user's country strongly at the end as a tie-breaker
        let preferredName = preferredCountryName.lowercased()
        if !preferredName.isEmpty {
            results.sort { (lhs, rhs) in
                let lPref = lhs.country.lowercased() == preferredName
                let rPref = rhs.country.lowercased() == preferredName
                if lPref != rPref { return lPref && !rPref }
                return lhs.searchScore > rhs.searchScore
            }
        }

        // Sort by score descending within country bias and limit
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
        scoreTotal += Int(Double(score(placemark.subLocality)) * 1.6)
        scoreTotal += Int(Double(score(placemark.locality)) * 1.3)
        // Include name but with a small weight so "Curl Curl" helps, but roads/POIs don't dominate
        scoreTotal += Int(Double(score(placemark.name)) * 0.3)
        scoreTotal += Int(Double(score(placemark.administrativeArea)) * 0.6)
        scoreTotal += Int(Double(score(placemark.country)) * 0.2)

        // Strong country bias to user's region
        if let code = placemark.isoCountryCode?.uppercased(), !preferredRegionCode.isEmpty, code == preferredRegionCode {
            scoreTotal += 200
        } else if let c = placemark.country?.lowercased(), !preferredCountryName.isEmpty, c == preferredCountryName.lowercased() {
            scoreTotal += 200
        }

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
