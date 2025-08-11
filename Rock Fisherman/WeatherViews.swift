import SwiftUI

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
                
                if let currentWeather = weatherService.currentWeather {
                    // Current Weather Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(Int(round(currentWeather.temperature)))°")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text(currentWeather.weatherDescription)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Image(systemName: weatherIcon(for: currentWeather.weatherCode))
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Weather Details
                        HStack(spacing: 20) {
                            WeatherDetailView(
                                icon: "thermometer",
                                title: "Feels Like",
                                value: "\(Int(round(currentWeather.apparentTemperature)))°"
                            )
                            
                            WeatherDetailView(
                                icon: "humidity",
                                title: "Humidity",
                                value: "\(currentWeather.relativeHumidity)%"
                            )
                            
                            WeatherDetailView(
                                icon: "wind",
                                title: "Wind",
                                value: "\(Int(round(currentWeather.windSpeed))) km/h"
                            )
                        }
                        
                        // Wave Information
                        WaveInfoView(weatherService: weatherService)
                        
                        // Fishing Conditions
                        FishingConditionsView(currentWeather: currentWeather)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                } else if weatherService.isLoading {
                    ProgressView("Loading weather...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = weatherService.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Weather Error")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
    }
    
    private func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.rain.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Location Status View
struct LocationStatusView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingLocationSelection: Bool
    
    var body: some View {
        VStack(spacing: 12) {
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
            } else {
                HStack {
                    Image(systemName: "location.slash")
                        .foregroundColor(.orange)
                    
                    Text("Location not set")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Set Location") {
                        showingLocationSelection = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    
                    Text("Location access denied")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Weather Detail View
struct WeatherDetailView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fishing Conditions View
struct FishingConditionsView: View {
    let currentWeather: CurrentWeather
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "fish")
                    .foregroundColor(.blue)
                
                Text("Fishing Conditions")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: currentWeather.isGoodFishing ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(currentWeather.isGoodFishing ? .green : .red)
            }
            
            if currentWeather.isGoodFishing {
                Text("Good conditions for fishing!")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("Conditions may not be ideal for fishing")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Hourly Forecast View
struct HourlyForecastView: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Compact header with smaller fonts
            VStack(alignment: .leading, spacing: 4) {
                Text("Next 12 Hours")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Hourly Forecast")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            if weatherService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if weatherService.hourlyForecast.isEmpty {
                Text("No hourly forecast available")
                    .foregroundColor(.secondary)
            } else {
                // Compact header row with smaller fonts
                HStack(spacing: 12) {
                    Text("Time")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 90, alignment: .leading)
                    
                    Text("")
                        .frame(width: 25)
                    
                    Text("Temp")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .leading)
                    
                    Text("Wind")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    
                    Text("Rain")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .leading)
                    
                    Text("Fish")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
                
                // Compact forecast rows with reduced spacing
                LazyVStack(spacing: 6) {
                    ForEach(next12HoursForecast, id: \.id) { forecast in
                        HourlyForecastRow(forecast: forecast)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var next12HoursForecast: [HourlyForecast] {
        let now = Date()
        
        return weatherService.hourlyForecast
            .filter { forecast in
                guard let forecastDate = parseForecastTime(forecast.time) else { return false }
                return forecastDate > now
            }
            .prefix(12)
            .map { $0 }
    }
    
    private func parseForecastTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: timeString)
    }
}

// MARK: - Hourly Forecast Row
struct HourlyForecastRow: View {
    let forecast: HourlyForecast
    
    var body: some View {
        HStack(spacing: 12) {
            // Time column - compact layout
            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.formattedTime)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(forecast.formattedRelativeTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 90, alignment: .leading)
            
            // Weather icon
            Image(systemName: weatherIcon(for: forecast.weatherCode))
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 25)
            
            // Temperature
            Text("\(Int(round(forecast.temperature)))°")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 45, alignment: .leading)
            
            // Wind
            HStack(spacing: 2) {
                Image(systemName: "wind")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("\(Int(round(forecast.windSpeed)))")
                    .font(.caption2)
            }
            .frame(width: 50, alignment: .leading)
            
            // Precipitation
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text("\(Int(round(forecast.precipitation)))")
                    .font(.caption2)
            }
            .frame(width: 45, alignment: .leading)
            
            // Fishing indicator
            Image(systemName: forecast.isGoodFishing ? "fish.fill" : "fish")
                .font(.caption2)
                .foregroundColor(forecast.isGoodFishing ? .green : .gray)
                .frame(width: 25)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
    
    private func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.rain.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Daily Forecast View
struct DailyForecastView: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-Day Forecast")
                .font(.title2)
                .fontWeight(.bold)
            
            if weatherService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if weatherService.dailyForecast.isEmpty {
                Text("No daily forecast available")
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(weatherService.dailyForecast) { forecast in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(forecast.formattedDate)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(Int(round(forecast.minTemp)))° - \(Int(round(forecast.maxTemp)))°")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: "drop.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("\(Int(round(forecast.precipitation)))mm")
                                        .font(.caption)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "wind")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(Int(round(forecast.maxWindSpeed))) km/h")
                                        .font(.caption)
                                }
                            }
                            
                            Image(systemName: forecast.isGoodFishing ? "fish.fill" : "fish")
                                .font(.title3)
                                .foregroundColor(forecast.isGoodFishing ? .green : .gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Fishing Tips View
struct FishingTipsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fishing Tips")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    FishingTipCard(
                        title: "Best Time to Fish",
                        description: "Early morning and late afternoon are typically the best times for fishing. Fish are more active during these periods.",
                        icon: "clock.fill"
                    )
                    
                    FishingTipCard(
                        title: "Weather Conditions",
                        description: "Overcast days with light rain can be excellent for fishing. Fish are more likely to be near the surface.",
                        icon: "cloud.rain.fill"
                    )
                    
                    FishingTipCard(
                        title: "Wind Considerations",
                        description: "Light to moderate winds can help by creating ripples that make fish less wary. Strong winds can make fishing difficult.",
                        icon: "wind"
                    )
                    
                    FishingTipCard(
                        title: "Temperature Tips",
                        description: "Fish are most active when water temperatures are between 10-25°C. Extreme temperatures can slow down fish activity.",
                        icon: "thermometer"
                    )
                    
                    FishingTipCard(
                        title: "Tide and Current",
                        description: "Fish often feed more actively during tide changes. Understanding local tide patterns can improve your success.",
                        icon: "water.waves"
                    )
                }
            }
        }
        .padding()
    }
}

// MARK: - Fishing Tip Card
struct FishingTipCard: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Wave Info View
struct WaveInfoView: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "water.waves")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Wave Conditions")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            if weatherService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let waveData = weatherService.waveData {
                // Wave data available
                VStack(spacing: 16) {
                    // Current wave conditions
                    HStack(spacing: 20) {
                        WaveDataCard(
                            title: "Height",
                            value: waveData.waveHeightFormatted,
                            icon: "arrow.up.and.down",
                            color: .blue
                        )
                        
                        WaveDataCard(
                            title: "Direction",
                            value: waveData.waveDirectionFormatted,
                            icon: "location.north",
                            color: .green
                        )
                        
                        WaveDataCard(
                            title: "Period",
                            value: waveData.wavePeriodFormatted,
                            icon: "clock",
                            color: .orange
                        )
                    }
                    
                    // Fishing condition indicator
                    HStack {
                        Text("Fishing Condition:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(waveData.fishingConditionColor)
                                .frame(width: 12, height: 12)
                            
                            Text(waveData.fishingCondition)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(waveData.fishingConditionColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            } else {
                // No wave data available
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        
                        Text("Wave data not available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let nearestLocation = weatherService.nearestWaveLocation {
                        Text(nearestLocation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Wave Data Card
struct WaveDataCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
