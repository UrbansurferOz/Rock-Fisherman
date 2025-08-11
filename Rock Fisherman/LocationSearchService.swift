import Foundation
import CoreLocation
import MapKit
import Combine

class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchResults: [LocationResult] = []
    @Published var isSearching = false
    @Published var searchError: String?
    
    private let geocoder = CLGeocoder()
    private let completer = MKLocalSearchCompleter()
    private var searchCancellable: AnyCancellable?
    private var lastQuery: String = ""
    // Track and cancel in-flight searches to avoid stale results flashing in
    private var currentSearchGeneration: Int = 0
    private var activeMKSearches: [MKLocalSearch] = []
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
    // App primary audience: Australia. Use as strong default/bias.
    private let primaryCountryCode = "AU"
    private let primaryCountryName = "Australia"
    private let australiaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751),
        span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 35)
    )
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address]
    }

    func searchLocations(query: String, near coordinate: CLLocationCoordinate2D? = nil) {
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
                guard let self else { return }
                // Bump generation and cancel any prior in-flight work
                self.currentSearchGeneration += 1
                let generation = self.currentSearchGeneration
                self.cancelActiveSearches()
                self.geocoder.cancelGeocode()
                // Configure completer region for better local suggestions
                if let c = coordinate {
                    self.completer.region = MKCoordinateRegion(
                        center: c,
                        span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
                    )
                } else {
                    // Force AU as default region for this app regardless of simulator locale
                    self.completer.region = self.australiaRegion
                }
                self.lastQuery = searchQuery
                self.completer.queryFragment = searchQuery
                // Also run our search fallback path
                self.performSearch(query: searchQuery, near: coordinate, generation: generation)
            }
    }
    
    private func performSearch(query: String, near coordinate: CLLocationCoordinate2D?, generation: Int) {
        let rawQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First try MapKit local search for richer place data with regional bias
        let mkRequest = MKLocalSearch.Request()
        mkRequest.naturalLanguageQuery = rawQuery
        mkRequest.resultTypes = [.address]
        if let c = coordinate {
            mkRequest.region = MKCoordinateRegion(
                center: c,
                span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
            )
        } else {
            // Force AU region as default
            mkRequest.region = australiaRegion
        }

        let mkSearch = MKLocalSearch(request: mkRequest)
        register(search: mkSearch)
        mkSearch.start { [weak self] response, error in
            defer { self?.unregister(search: mkSearch) }
            guard let self else { return }
            guard generation == self.currentSearchGeneration, rawQuery == self.lastQuery else { return }
            if let response = response, !response.mapItems.isEmpty {
                var placemarks: [CLPlacemark] = response.mapItems.compactMap { $0.placemark }
                // If none of the results are in Australia, try an AU-scoped search as a second pass
                let hasAU = placemarks.contains { $0.isoCountryCode?.uppercased() == self.primaryCountryCode }
                if !hasAU {
                    let auReq = MKLocalSearch.Request()
                    auReq.naturalLanguageQuery = rawQuery
                    auReq.resultTypes = [.address]
                    auReq.region = self.australiaRegion
                    let auSearch = MKLocalSearch(request: auReq)
                    self.register(search: auSearch)
                    auSearch.start { [weak self] auResp, _ in
                        guard let self else { return }
                        defer { self.unregister(search: auSearch) }
                        guard generation == self.currentSearchGeneration, rawQuery == self.lastQuery else { return }
                        if let items = auResp?.mapItems {
                            placemarks.append(contentsOf: items.compactMap { $0.placemark })
                        }
                        // If still no AU results, try explicit country-constrained query via MKLocalSearch
                        let stillNoAU = !placemarks.contains { $0.isoCountryCode?.uppercased() == self.primaryCountryCode }
                        if stillNoAU {
                            let auTextReq = MKLocalSearch.Request()
                            auTextReq.naturalLanguageQuery = "\(rawQuery) Australia"
                            auTextReq.resultTypes = [.address]
                            auTextReq.region = self.australiaRegion
                            let auTextSearch = MKLocalSearch(request: auTextReq)
                            self.register(search: auTextSearch)
                            auTextSearch.start { [weak self] auTextResp, _ in
                                guard let self else { return }
                                defer { self.unregister(search: auTextSearch) }
                                guard generation == self.currentSearchGeneration, rawQuery == self.lastQuery else { return }
                                if let items2 = auTextResp?.mapItems {
                                    placemarks.append(contentsOf: items2.compactMap { $0.placemark })
                                }
                                // As a final fallback, call geocoder scoped to AU
                                let hasNowAU = placemarks.contains { $0.isoCountryCode?.uppercased() == self.primaryCountryCode }
                                if hasNowAU {
                                    self.handlePlacemarkResults(from: "MKLocalSearch+AUText", query: rawQuery, placemarks: placemarks)
                                } else {
                                    self.performCLGeocoderSearch(rawQuery: rawQuery)
                                }
                            }
                        } else {
                            self.handlePlacemarkResults(from: "MKLocalSearch+AU", query: rawQuery, placemarks: placemarks)
                        }
                    }
                } else {
                    self.handlePlacemarkResults(from: "MKLocalSearch", query: rawQuery, placemarks: placemarks)
                }
                return
            }
            // Fallback to CLGeocoder with country scoping
            self.performCLGeocoderSearch(rawQuery: rawQuery)
        }
    }

    private func handlePlacemarkResults(from source: String, query: String, placemarks: [CLPlacemark]) {
        DispatchQueue.main.async {
            self.isSearching = false
            print("\(source) returned \(placemarks.count) placemarks for query=\(query)")
            let filteredResults = self.filterAndRankResults(placemarks, for: query)
            if !filteredResults.isEmpty {
                self.searchResults = filteredResults
            } else {
                // Keep previous non-empty results to avoid flicker/disappearing suggestions
                print("Filtered results empty for query=\(query); preserving previous results (count=\(self.searchResults.count))")
            }
            print("Final filtered count=\(filteredResults.count)")
            for r in filteredResults { print("Result: \(r.displayName) [score=\(r.searchScore)]") }
        }
    }

    private func performCLGeocoderSearch(rawQuery: String) {
        // Try scoping to user's country first (e.g., "Clarev, Australia")
        // Try Australia first (primary audience), then user's country, then raw
        let auScopedQuery = "\(rawQuery), \(primaryCountryName)"
        let userScopedQuery: String? = preferredCountryName.isEmpty ? nil : "\(rawQuery), \(preferredCountryName)"

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
                    // Do not clear; preserve existing results to prevent disappearing list while typing
                    return
                }
                let filteredResults = self.filterAndRankResults(returned, for: rawQuery)
                if !filteredResults.isEmpty {
                    self.searchResults = filteredResults
                } else {
                    print("Geocoder filtered to 0; preserving previous results (count=\(self.searchResults.count))")
                }
                print("Final filtered count=\(filteredResults.count)")
                for r in filteredResults { print("Result: \(r.displayName) [score=\(r.searchScore)]") }
            }
        }

        print("Searching (scoped AU): \(auScopedQuery)")
        geocoder.geocodeAddressString(auScopedQuery) { [weak self] auPlacemarks, auError in
            if let auPlacemarks, !auPlacemarks.isEmpty {
                handleResponse(auScopedQuery, placemarks: auPlacemarks, error: auError)
                return
            }
            if let userScoped = userScopedQuery {
                print("Searching (scoped user country): \(userScoped)")
                self?.geocoder.geocodeAddressString(userScoped) { userPlacemarks, userError in
                    if let userPlacemarks, !userPlacemarks.isEmpty {
                        handleResponse(userScoped, placemarks: userPlacemarks, error: userError)
                        return
                    }
                    print("Searching (raw): \(rawQuery)")
                    self?.geocoder.geocodeAddressString(rawQuery) { placemarks, error in
                        handleResponse(rawQuery, placemarks: placemarks, error: error)
                    }
                }
            } else {
                print("Searching (raw): \(rawQuery)")
                self?.geocoder.geocodeAddressString(rawQuery) { placemarks, error in
                    handleResponse(rawQuery, placemarks: placemarks, error: error)
                }
            }
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let currentFragment = completer.queryFragment
        let generation = currentSearchGeneration
        // Avoid acting on stale results
        guard !currentFragment.isEmpty, currentFragment == lastQuery else { return }

        // Prefer AU completions by filtering if possible
        let rawCompletions = Array(completer.results.prefix(12))
        let auCompletions = rawCompletions.filter { comp in
            let lc = comp.subtitle.lowercased()
            return lc.contains("australia") || lc.contains("nsw") || lc.contains("new south wales") || lc.contains("qld") || lc.contains("vic") || lc.contains("wa") || lc.contains("sa") || lc.contains("tas") || lc.contains("act") || lc.contains("nt")
        }
        let completions = auCompletions.isEmpty ? Array(rawCompletions.prefix(6)) : Array(auCompletions.prefix(6))
        if completions.isEmpty { return }

        print("Completer returned \(completions.count) suggestions for query=\(currentFragment)")

        let group = DispatchGroup()
        var placemarks: [CLPlacemark] = []
        for c in completions {
            group.enter()
            let req = MKLocalSearch.Request(completion: c)
            let search = MKLocalSearch(request: req)
            register(search: search)
            search.start { [weak self] resp, _ in
                defer { self?.unregister(search: search) }
                if let items = resp?.mapItems {
                    placemarks.append(contentsOf: items.compactMap { $0.placemark })
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard generation == self.currentSearchGeneration, currentFragment == self.lastQuery else { return }
            var results = self.filterAndRankResults(placemarks, for: currentFragment)
            // If no AU results from completer-derived searches, run an AU-scoped direct search
            let hasAU = results.contains { $0.country.caseInsensitiveCompare(self.primaryCountryName) == .orderedSame }
            if !hasAU {
                let req = MKLocalSearch.Request()
                req.naturalLanguageQuery = currentFragment
                req.resultTypes = [.address]
                req.region = self.australiaRegion
                let direct = MKLocalSearch(request: req)
                self.register(search: direct)
                direct.start { [weak self] resp, _ in
                    guard let self else { return }
                    defer { self.unregister(search: direct) }
                    guard generation == self.currentSearchGeneration, currentFragment == self.lastQuery else { return }
                    var merged = placemarks
                    if let items = resp?.mapItems {
                        merged.append(contentsOf: items.compactMap { $0.placemark })
                    }
                    let finalResults = self.filterAndRankResults(merged, for: currentFragment)
                    if !finalResults.isEmpty {
                        self.isSearching = false
                        self.searchResults = finalResults
                        print("Completer+AU resolved to \(finalResults.count) results")
                    }
                }
            } else {
                if !results.isEmpty {
                    self.isSearching = false
                    self.searchResults = results
                    print("Completer resolved to \(results.count) results")
                }
            }
        }
    }

    // MARK: - Active search management
    private func register(search: MKLocalSearch) {
        activeMKSearches.append(search)
    }
    private func unregister(search: MKLocalSearch) {
        if let idx = activeMKSearches.firstIndex(where: { $0 === search }) {
            activeMKSearches.remove(at: idx)
        }
    }
    private func cancelActiveSearches() {
        activeMKSearches.forEach { $0.cancel() }
        activeMKSearches.removeAll()
    }
    
    private func filterAndRankResults(_ placemarks: [CLPlacemark], for query: String) -> [LocationResult] {
        let queryLower = query.lowercased()
        let isShortQuery = queryLower.count <= 4 && !queryLower.contains(" ")

        // Build scored results and drop unrelated ones entirely
        var results: [LocationResult] = placemarks.compactMap { placemark in
            guard let location = placemark.location else {
                print("Placemark has no location: \(placemark)")
                return nil
            }

            // Matching rules:
            // - Short queries (<=4 chars, single word): only allow prefix matches on suburb/city
            // - Longer queries: allow substring matches on suburb/city/state/country; include name for contains but not for short queries
            if isShortQuery {
                let sl = placemark.subLocality?.lowercased() ?? ""
                let loc = placemark.locality?.lowercased() ?? ""
                let admin = placemark.administrativeArea?.lowercased() ?? ""
                guard sl.hasPrefix(queryLower) || loc.hasPrefix(queryLower) || admin.hasPrefix(queryLower) else {
                    return nil
                }
            } else {
                var fields: [String] = [
                    placemark.subLocality,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country
                ].compactMap { $0?.lowercased() }
                // Only include name for longer/compound queries to avoid POIs like "Curl Rd" in unrelated countries
                if queryLower.count >= 5 || queryLower.contains(" ") {
                    if let nameLower = placemark.name?.lowercased() { fields.append(nameLower) }
                }
                guard fields.contains(where: { $0.contains(queryLower) }) else { return nil }
            }

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

        // If any AU results exist, keep only AU
        let auOnly = results.filter { $0.country.caseInsensitiveCompare(primaryCountryName) == .orderedSame }
        if !auOnly.isEmpty {
            print("Pruning to AU-only results: kept=\(auOnly.count), dropped=\(results.count - auOnly.count)")
            results = auOnly
        } else if !preferredCountryName.isEmpty {
            let preferredOnly = results.filter { $0.country.caseInsensitiveCompare(preferredCountryName) == .orderedSame }
            if !preferredOnly.isEmpty {
                print("Pruning to preferred-country-only results: kept=\(preferredOnly.count), dropped=\(results.count - preferredOnly.count)")
                results = preferredOnly
            }
        }

        // Bias to primary country (AU) first, then user's country
        let primaryName = primaryCountryName.lowercased()
        let preferredName = preferredCountryName.lowercased()
        results.sort { (lhs, rhs) in
            let lPrimary = lhs.country.lowercased() == primaryName
            let rPrimary = rhs.country.lowercased() == primaryName
            if lPrimary != rPrimary { return lPrimary && !rPrimary }
            let lPref = !preferredName.isEmpty && lhs.country.lowercased() == preferredName
            let rPref = !preferredName.isEmpty && rhs.country.lowercased() == preferredName
            if lPref != rPref { return lPref && !rPref }
            return lhs.searchScore > rhs.searchScore
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

        // Very strong bias to AU as primary, then user's region
        if placemark.isoCountryCode?.uppercased() == primaryCountryCode {
            scoreTotal += 300
        }
        if let code = placemark.isoCountryCode?.uppercased(), !preferredRegionCode.isEmpty, code == preferredRegionCode {
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
