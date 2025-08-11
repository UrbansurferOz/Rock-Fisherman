import SwiftUI

// MARK: - Current Weather Card
struct CurrentWeatherCard: View {
    let weather: CurrentWeather
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Conditions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(weather.temperature2m))°")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Feels like")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(weather.apparentTemperature))°")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            
            HStack(spacing: 20) {
                WeatherInfoItem(
                    icon: "humidity",
                    value: "\(weather.relativeHumidity2m)%",
                    label: "Humidity"
                )
                
                WeatherInfoItem(
                    icon: "wind",
                    value: "\(Int(weather.windSpeed10m)) km/h",
                    label: "Wind"
                )
                
                WeatherInfoItem(
                    icon: "drop.fill",
                    value: "\(String(format: "%.1f", weather.precipitation)) mm",
                    label: "Rain"
                )
            }
            
            FishingConditionsIndicator(weather: weather)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Weather Info Item
struct WeatherInfoItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fishing Conditions Indicator
struct FishingConditionsIndicator: View {
    let weather: CurrentWeather
    
    private var fishingScore: Int {
        var score = 0
        
        // Temperature scoring (10-25°C is ideal)
        if (10...25).contains(weather.temperature2m) {
            score += 3
        } else if (5...30).contains(weather.temperature2m) {
            score += 1
        }
        
        // Wind scoring (0-20 km/h is ideal)
        if (0...20).contains(weather.windSpeed10m) {
            score += 2
        } else if (0...30).contains(weather.windSpeed10m) {
            score += 1
        }
        
        // Precipitation scoring (0-5 mm is ideal)
        if (0...5).contains(weather.precipitation) {
            score += 2
        } else if (0...10).contains(weather.precipitation) {
            score += 1
        }
        
        return min(score, 7)
    }
    
    private var fishingStatus: (text: String, color: Color) {
        switch fishingScore {
        case 6...7:
            return ("Excellent", .green)
        case 4...5:
            return ("Good", .blue)
        case 2...3:
            return ("Fair", .orange)
        default:
            return ("Poor", .red)
        }
    }
    
    var body: some View {
        HStack {
            Text("Fishing Conditions:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(fishingStatus.text)
                    .font(.headline)
                    .foregroundColor(fishingStatus.color)
                
                Image(systemName: "fish")
                    .foregroundColor(fishingStatus.color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(fishingStatus.color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Hourly Forecast Row
struct HourlyForecastRow: View {
    let forecast: HourlyForecast
    
    var body: some View {
        VStack(spacing: 8) {
            Text(forecast.formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Image(systemName: forecast.isGoodFishing ? "fish.fill" : "fish")
                .font(.title3)
                .foregroundColor(forecast.isGoodFishing ? .green : .gray)
            
            Text("\(Int(forecast.temperature))°")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("\(Int(forecast.windSpeed)) km/h")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background(forecast.isGoodFishing ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Daily Forecast Row
struct DailyForecastRow: View {
    let forecast: DailyForecast
    
    var body: some View {
        HStack {
            Text(forecast.formattedDate)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("\(Int(forecast.maxTemp))°")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text("\(Int(forecast.minTemp))°")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(forecast.maxWindSpeed)) km/h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", forecast.precipitation)) mm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: forecast.isGoodFishing ? "fish.fill" : "fish")
                .foregroundColor(forecast.isGoodFishing ? .green : .gray)
                .frame(width: 20)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(forecast.isGoodFishing ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading weather data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Oops!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
