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
                Text("Conditions")
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
                    .navigationTitle("7-Day Forecast")
                    .navigationBarTitleDisplayMode(.large)
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
            }
            .tabItem {
                Image(systemName: "newspaper")
                Text("News")
            }
            .tag(3)
        }
        .onAppear {
            // First run: require an explicit user selection
            // Subsequent runs: use the last selected location (persisted by LocationManager)
            if !hasShownInitialLocationSelection && !locationManager.hasSelectedLocation {
                showingLocationSelection = true
                hasShownInitialLocationSelection = true
                return
            }
            if let location = locationManager.location {
                Task { await weatherService.fetchWeather(for: location) }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Request a fresh location fix when returning to foreground
                locationManager.requestLocation()
                // Also refresh immediately using the last known location
                if let location = locationManager.location {
                    Task { await weatherService.fetchWeather(for: location) }
                }
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
