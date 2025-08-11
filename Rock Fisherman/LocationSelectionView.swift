import SwiftUI
import CoreLocation

struct LocationSelectionView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var locationSearchService = LocationSearchService()
    
    @State private var showingLocationSearch = false
    @State private var searchText = ""
    @State private var isFirstLaunch = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Choose Your Location")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Select your fishing location to get weather conditions and fishing tips")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Location Options
                VStack(spacing: 20) {
                    Button {
                        requestCurrentLocation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.title2)
                            Text("Use Current Location")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        showingLocationSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                            Text("Search for Location")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingLocationSearch) {
            LocationSearchView(
                locationSearchService: locationSearchService,
                weatherService: weatherService,
                locationManager: locationManager,
                isPresented: $showingLocationSearch
            )
        }
        .onAppear {
            if locationManager.authorizationStatus != .notDetermined {
                isFirstLaunch = false
            }
        }
        .onDisappear {
            locationSearchService.clearSearch()
        }
    }
    
    private func requestCurrentLocation() {
        locationManager.requestLocation()
    }
}

// MARK: - Location Search View
struct LocationSearchView: View {
    @ObservedObject var locationSearchService: LocationSearchService
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var locationManager: LocationManager
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var showingSearchResults = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search for a city, town, or area...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: searchText) { oldValue, newValue in
                                locationSearchService.searchLocations(query: newValue)
                                showingSearchResults = !newValue.isEmpty
                            }
                            .onSubmit {
                                if !searchText.isEmpty {
                                    locationSearchService.searchLocations(query: searchText)
                                    showingSearchResults = true
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                locationSearchService.clearSearch()
                                showingSearchResults = false
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Search suggestions
                    if searchText.isEmpty && !showingSearchResults {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Try searching for:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(["Sydney", "Melbourne", "Brisbane", "Perth", "Newcastle"], id: \.self) { suggestion in
                                    Button(suggestion) {
                                        searchText = suggestion
                                        locationSearchService.searchLocations(query: suggestion)
                                        showingSearchResults = true
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if locationSearchService.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                
                // Search Results
                if showingSearchResults {
                    if locationSearchService.searchResults.isEmpty && !searchText.isEmpty && !locationSearchService.isSearching {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No locations found")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Try searching for a different city or area")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6))
                    } else {
                        List(locationSearchService.searchResults) { result in
                            Button {
                                selectLocation(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.displayName)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            if !result.subLocality.isEmpty && result.subLocality != result.city {
                                                Text(result.subLocality)
                                                    .font(.subheadline)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Show search relevance indicator
                                        if result.searchScore > 80 {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                        }
                                    }
                                    
                                    HStack {
                                        Text(result.city.isEmpty ? result.state : result.city)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if !result.city.isEmpty && !result.state.isEmpty {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(result.state)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if !result.country.isEmpty {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(result.country)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Debug info (remove in production)
                                        Text("Score: \(result.searchScore)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    // Recent or Popular Locations
                    VStack(spacing: 20) {
                        Text("Popular Fishing Locations")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(popularLocations, id: \.name) { location in
                                Button {
                                    selectLocation(location)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "fish.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                        
                                        Text(location.name)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func selectLocation(_ location: LocationResult) {
        print("Selecting location: \(location.name) at (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        
        let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        locationManager.setLocation(clLocation, name: location.displayName)
        
        print("Location set in manager. hasSelectedLocation: \(locationManager.hasSelectedLocation)")
        
        Task {
            await weatherService.fetchWeather(for: clLocation)
        }
        
        isPresented = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("Closing location selection view")
        }
    }
    
    private var popularLocations: [LocationResult] {
        [
            LocationResult(name: "Clareville", city: "Sydney", state: "NSW", country: "Australia", subLocality: "Clareville", coordinate: CLLocationCoordinate2D(latitude: -33.6333, longitude: 151.3333), searchScore: 100),
            LocationResult(name: "Palm Beach", city: "Sydney", state: "NSW", country: "Australia", subLocality: "Palm Beach", coordinate: CLLocationCoordinate2D(latitude: -33.5967, longitude: 151.3233), searchScore: 100),
            LocationResult(name: "Manly", city: "Sydney", state: "NSW", country: "Australia", subLocality: "Manly", coordinate: CLLocationCoordinate2D(latitude: -33.7967, longitude: 151.2850), searchScore: 100),
            LocationResult(name: "Bondi Beach", city: "Sydney", state: "NSW", country: "Australia", subLocality: "Bondi", coordinate: CLLocationCoordinate2D(latitude: -33.8914, longitude: 151.2767), searchScore: 100),
            LocationResult(name: "Cronulla", city: "Sydney", state: "NSW", country: "Australia", subLocality: "Cronulla", coordinate: CLLocationCoordinate2D(latitude: -34.0550, longitude: 151.1567), searchScore: 100),
            LocationResult(name: "Newport", city: "Sydney", state: "NSW", country: "Australia", subLocality: "Newport", coordinate: CLLocationCoordinate2D(latitude: -33.6683, longitude: 151.3017), searchScore: 100),
            LocationResult(name: "Terrigal", city: "Central Coast", state: "NSW", country: "Australia", subLocality: "Terrigal", coordinate: CLLocationCoordinate2D(latitude: -33.4483, longitude: 151.4483), searchScore: 100),
            LocationResult(name: "Port Stephens", city: "Port Stephens", state: "NSW", country: "Australia", subLocality: "Port Stephens", coordinate: CLLocationCoordinate2D(latitude: -32.7167, longitude: 152.0667), searchScore: 100)
        ]
    }
}
