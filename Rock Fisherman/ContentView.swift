//
//  ContentView.swift
//  Rock Fisherman
//
//  Created by Steven White on 11/08/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationManager = LocationManager()
    @StateObject private var weatherService = WeatherService()
    @State private var selectedTab = 0
    @State private var showingLocationSelection = false
    @State private var hasShownInitialLocationSelection = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Current Weather Tab
            NavigationView {
                CurrentWeatherView(
                    locationManager: locationManager,
                    weatherService: weatherService,
                    showingLocationSelection: $showingLocationSelection
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
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
                Text("Conditions")
            }
            .tag(0)
            
            // Hourly Forecast Tab
            NavigationView {
                HourlyForecastView(weatherService: weatherService)
                    .navigationTitle("Hourly Forecast")
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
                Image(systemName: "clock")
                Text("Hourly")
            }
            .tag(1)
            
            // Daily Forecast Tab
            NavigationView {
                DailyForecastView(weatherService: weatherService)
                    .navigationTitle("7-Day Forecast")
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
                Image(systemName: "calendar")
                Text("Daily")
            }
            .tag(2)
            
            // Fishing News Tab
            NavigationView {
                FishingNewsView(locationManager: locationManager)
                    .navigationTitle("Fishing News")
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
                Image(systemName: "newspaper")
                Text("News")
            }
            .tag(3)
        }
        .onAppear {
            // Let the manager handle authorization flow; avoids synchronous status checks on main
            locationManager.requestLocation()

            // Show selection sheet if no location has been chosen yet
            if !hasShownInitialLocationSelection && !locationManager.hasSelectedLocation {
                showingLocationSelection = true
                hasShownInitialLocationSelection = true
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            case .denied, .restricted:
                showingLocationSelection = true
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Request a fresh location fix when returning to foreground
                locationManager.requestLocation()
                // Weather refresh will occur when location updates; avoid extra synchronous checks
            }
        }
        .onChange(of: locationManager.hasSelectedLocation) { oldValue, hasSelected in
            if hasSelected {
                // Location has been selected, close the selection view
                showingLocationSelection = false
            }
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            if let location = newLocation, locationManager.hasSelectedLocation {
                // When location changes, ensure location selection is closed
                showingLocationSelection = false
                
                Task {
                    await weatherService.fetchWeather(for: location)
                }
            }
        }
        .sheet(isPresented: $showingLocationSelection) {
            LocationSelectionView(
                locationManager: locationManager,
                weatherService: weatherService
            )
            .onDisappear {
                // Ensure the sheet is properly dismissed
                if locationManager.hasSelectedLocation {
                    showingLocationSelection = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
