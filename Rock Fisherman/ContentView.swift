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
            // Check if this is the first launch or no location has been selected
            if !locationManager.hasSelectedLocation && locationManager.authorizationStatus != .notDetermined {
                showingLocationSelection = true
            } else {
                locationManager.requestLocation()
            }
        }
        .onChange(of: locationManager.hasSelectedLocation) { oldValue, hasSelected in
            if hasSelected {
                // Location has been selected, close the selection view
                showingLocationSelection = false
            }
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            if let location = newLocation {
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
