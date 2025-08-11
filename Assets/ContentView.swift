//
//  ContentView.swift
//  Rock Fisherman
//
//  Created by Steven White on 11/08/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var weatherService = WeatherService()
    @State private var selectedTab = 0
    @State private var showingLocationSelection = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Current Weather Tab
            NavigationView {
                CurrentWeatherView(
                    locationManager: locationManager,
                    weatherService: weatherService,
                    showingLocationSelection: $showingLocationSelection
                )
                .navigationTitle(locationManager.selectedLocationName ?? "Rock Fisherman")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingLocationSelection = true
                        } label: {
                            Image(systemName: "location.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .tabItem {
                Image(systemName: "thermometer")
                Text("Weather")
            }
            .tag(0)
            
            // Hourly Forecast Tab
            NavigationView {
                HourlyForecastView(weatherService: weatherService)
                    .navigationTitle("Hourly Forecast")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "clock")
                Text("Hourly")
            }
            .tag(1)
            
            // Daily Forecast Tab
            NavigationView {
                DailyForecastView(weatherService: weatherService)
                    .navigationTitle("Daily Forecast")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "calendar")
                Text("Daily")
            }
            .tag(2)
            
            // Fishing Tips Tab
            NavigationView {
                FishingTipsView()
                    .navigationTitle("Fishing Tips")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "fish")
                Text("Tips")
            }
            .tag(3)
        }
        .onAppear {
            // Check if this is the first launch or no location has been selected
            if !locationManager.hasSelectedLocation && locationManager.authorizationStatus != .notDetermined {
                showingLocationSelection = true
            } else {
                locationManager.requestLocation()
            }
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            if let location = newLocation {
                Task {
                    await weatherService.fetchWeather(for: location)
                }
            }
        }
        .onChange(of: locationManager.hasSelectedLocation) { oldValue, hasSelected in
            if hasSelected {
                // Location has been selected, close the selection view
                showingLocationSelection = false
            }
        }
        .sheet(isPresented: $showingLocationSelection) {
            LocationSelectionView(
                locationManager: locationManager,
                weatherService: weatherService
            )
        }
    }
}

// MARK: - Current Weather View
struct CurrentWeatherView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var weatherService: WeatherService
    @Binding var showingLocationSelection: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Location Status
                LocationStatusView(
                    locationManager: locationManager,
                    showingLocationSelection: $showingLocationSelection
                )
                
                // Current Weather
                if let currentWeather = weatherService.currentWeather {
                    CurrentWeatherCard(weather: currentWeather)
                }
                
                // Loading State
                if weatherService.isLoading {
                    LoadingView()
                }
                
                // Error State
                if let errorMessage = weatherService.errorMessage {
                    ErrorView(message: errorMessage) {
                        if let location = locationManager.location {
                            Task {
                                await weatherService.fetchWeather(for: location)
                            }
                        }
                    }
                }
                
                // Quick Actions
                QuickActionsView(
                    locationManager: locationManager,
                    weatherService: weatherService
                )
            }
            .padding()
        }
        .refreshable {
            if let location = locationManager.location {
                await weatherService.fetchWeather(for: location)
            }
        }
    }
}

// MARK: - Location Status View
struct LocationStatusView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingLocationSelection: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: locationStatusIcon)
                    .font(.title2)
                    .foregroundColor(locationStatusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationStatusTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(locationStatusSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if locationManager.authorizationStatus == .denied {
                    Button("Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Show selected location name if available
            if let locationName = locationManager.selectedLocationName {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text(locationName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Change") {
                        showingLocationSelection = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding(.top, 8)
            }
            
            if locationManager.authorizationStatus == .notDetermined {
                Button("Enable Location Access") {
                    locationManager.requestLocation()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var locationStatusIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "location.fill"
        case .denied, .restricted:
            return "location.slash"
        default:
            return "location"
        }
    }
    
    private var locationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }
    
    private var locationStatusTitle: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Location Active"
        case .denied, .restricted:
            return "Location Access Denied"
        default:
            return "Location Access Required"
        }
    }
    
    private var locationStatusSubtitle: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Weather data for your current location"
        case .denied, .restricted:
            return "Enable location access in Settings to get weather data"
        default:
            return "Tap to enable location access for personalized weather"
        }
    }
}

// MARK: - Quick Actions View
struct QuickActionsView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button {
                    locationManager.requestLocation()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "location.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        Text("Refresh Location")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Button {
                    if let location = locationManager.location {
                        Task {
                            await weatherService.fetchWeather(for: location)
                        }
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        Text("Refresh Weather")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Hourly Forecast View
struct HourlyForecastView: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if weatherService.hourlyForecast.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No hourly forecast available")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Check the Weather tab to load current conditions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(weatherService.hourlyForecast) { forecast in
                            HourlyForecastRow(forecast: forecast)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Daily Forecast View
struct DailyForecastView: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if weatherService.dailyForecast.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No daily forecast available")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Check the Weather tab to load current conditions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(weatherService.dailyForecast) { forecast in
                            DailyForecastRow(forecast: forecast)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Fishing Tips View
struct FishingTipsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                FishingTipCard(
                    title: "Temperature Matters",
                    description: "Fish are most active when water temperatures are between 10-25°C. Cold-blooded fish become sluggish in very cold or hot water.",
                    icon: "thermometer",
                    color: .red
                )
                
                FishingTipCard(
                    title: "Wind Conditions",
                    description: "Light to moderate winds (0-20 km/h) create ripples that help hide your line and attract fish. Strong winds can make fishing difficult.",
                    icon: "wind",
                    color: .blue
                )
                
                FishingTipCard(
                    title: "Precipitation",
                    description: "Light rain (0-5 mm) can improve fishing by washing insects into the water. Heavy rain may reduce visibility and make fish less active.",
                    icon: "drop.fill",
                    color: .cyan
                )
                
                FishingTipCard(
                    title: "Time of Day",
                    description: "Dawn and dusk are typically the best fishing times. Fish are more active during these low-light periods when they feel safer from predators.",
                    icon: "clock.fill",
                    color: .orange
                )
                
                FishingTipCard(
                    title: "Seasonal Patterns",
                    description: "Spring and fall often provide the best fishing conditions. Fish are more active during these transitional seasons when water temperatures are optimal.",
                    icon: "leaf.fill",
                    color: .green
                )
            }
            .padding()
        }
    }
}

// MARK: - Fishing Tip Card
struct FishingTipCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
}
