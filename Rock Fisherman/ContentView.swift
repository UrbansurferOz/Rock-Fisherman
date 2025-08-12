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
            // First run: require an explicit user selection
            // Subsequent runs: use the last selected location (persisted by LocationManager)
            if !hasShownInitialLocationSelection && !locationManager.hasSelectedLocation {
                print("ContentView.onAppear: Showing location selection (require explicit selection)")
                showingLocationSelection = true
                hasShownInitialLocationSelection = true
                return
            }
            if let location = locationManager.location {
                print("ContentView.onAppear: Using previously selected location; fetching weather")
                Task { await weatherService.fetchWeather(for: location) }
            }
        }
        .onChange(of: locationManager.hasSelectedLocation) { oldValue, hasSelected in
            print("ContentView.onChange hasSelectedLocation: \(oldValue) -> \(hasSelected)")
            if hasSelected {
                // Location has been selected, close the selection view
                print("ContentView: Closing location selection (hasSelectedLocation changed)")
                showingLocationSelection = false
            }
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            print("ContentView.onChange location: \(oldLocation?.coordinate.latitude ?? 0) -> \(newLocation?.coordinate.latitude ?? 0)")
            if let location = newLocation, locationManager.hasSelectedLocation {
                // When location changes, ensure location selection is closed
                print("ContentView: Closing location selection (location changed)")
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
