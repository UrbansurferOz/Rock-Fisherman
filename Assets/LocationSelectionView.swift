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
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Choose Your Location")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Get personalized weather and fishing conditions for your area")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Location Options
                VStack(spacing: 20) {
                    // Current Location Button
                    Button {
                        requestCurrentLocation()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Use Current Location")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Get weather for where you are now")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            if locationManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                    .disabled(locationManager.isLoading)
                    
                    // Search Location Button
                    Button {
                        showingLocationSearch = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Search for Location")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Find weather for any city or area")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Text("Powered by Open Meteo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Free weather data for the world")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
            // Check if this is the first launch
            if locationManager.authorizationStatus != .notDetermined {
                isFirstLaunch = false
            }
        }
        .onDisappear {
            // Clear search results when view disappears
            locationSearchService.clearSearch()
        }
    }
    
    private func requestCurrentLocation() {
        locationManager.requestLocation()
        // The location will be set automatically when the location manager updates
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
                // Search Bar
                VStack(spacing: 16) {
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(result.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
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
        
        // Create a CLLocation from the selected coordinates
        let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // Set the location in the location manager
        locationManager.setLocation(clLocation, name: location.displayName)
        
        print("Location set in manager. hasSelectedLocation: \(locationManager.hasSelectedLocation)")
        
        // Fetch weather for the selected location
        Task {
            await weatherService.fetchWeather(for: clLocation)
        }
        
        // Close the search view
        isPresented = false
        
        // Also close the parent location selection view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Small delay to ensure the location is properly set
            print("Closing location selection view")
        }
    }
    
    private var popularLocations: [LocationResult] {
        [
            LocationResult(name: "Sydney", city: "Sydney", state: "NSW", country: "Australia", coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
            LocationResult(name: "Melbourne", city: "Melbourne", state: "VIC", country: "Australia", coordinate: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)),
            LocationResult(name: "Brisbane", city: "Brisbane", state: "QLD", country: "Australia", coordinate: CLLocationCoordinate2D(latitude: -27.4698, longitude: 153.0251)),
            LocationResult(name: "Perth", city: "Perth", state: "WA", country: "Australia", coordinate: CLLocationCoordinate2D(latitude: -31.9505, longitude: 115.8605)),
            LocationResult(name: "Gold Coast", city: "Gold Coast", state: "QLD", country: "Australia", coordinate: CLLocationCoordinate2D(latitude: -28.0167, longitude: 153.4000)),
            LocationResult(name: "Newcastle", city: "Newcastle", state: "NSW", country: "Australia", coordinate: CLLocationCoordinate2D(latitude: -32.9283, longitude: 151.7817)),
            LocationResult(name: "Wollongong", city: "Wollongong", state: "NSW", country: "Australia", coordinate: CLLocationCoordinate2D(latitude: -34.4331, longitude: 150.8831)),
            LocationResult(name: "Cairns", city: "Cairns", state: "QLD", country: "Australia", coordinate: CLLocationCoordinate2D(latitude: -16.9186, longitude: 145.7781))
        ]
    }
}

#Preview {
    LocationSelectionView(
        locationManager: LocationManager(),
        weatherService: WeatherService()
    )
}
