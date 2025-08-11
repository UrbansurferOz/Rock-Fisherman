import Foundation
import CoreLocation

// MARK: - Weather Data Models
struct WeatherResponse: Codable {
    let current: CurrentWeather
    let hourly: HourlyWeather
    let daily: DailyWeather
}

struct CurrentWeather: Codable {
    let temperature2m: Double
    let relativeHumidity2m: Int
    let apparentTemperature: Double
    let precipitation: Double
    let windSpeed10m: Double
    let windDirection10m: Int
    let weatherCode: Int
    
    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitation
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case weatherCode = "weather_code"
    }
}

struct HourlyWeather: Codable {
    let time: [String]
    let temperature2m: [Double]
    let precipitation: [Double]
    let windSpeed10m: [Double]
    let windDirection10m: [Int]
    let weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case precipitation
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case weatherCode = "weather_code"
    }
}

struct DailyWeather: Codable {
    let time: [String]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationSum: [Double]
    let windSpeed10mMax: [Double]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationSum = "precipitation_sum"
        case windSpeed10mMax = "wind_speed_10m_max"
    }
}

// MARK: - Weather Service
class WeatherService: ObservableObject {
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchWeather(for location: CLLocation) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let urlString = "\(baseURL)?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,wind_speed_10m,wind_direction_10m,weather_code&hourly=temperature_2m,precipitation,wind_speed_10m,wind_direction_10m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max&timezone=auto"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
            
            await MainActor.run {
                self.currentWeather = weatherResponse.current
                self.hourlyForecast = self.processHourlyData(weatherResponse.hourly)
                self.dailyForecast = self.processDailyData(weatherResponse.daily)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func processHourlyData(_ hourly: HourlyWeather) -> [HourlyForecast] {
        var forecasts: [HourlyForecast] = []
        
        for i in 0..<min(hourly.time.count, 24) { // Get next 24 hours
            let forecast = HourlyForecast(
                time: hourly.time[i],
                temperature: hourly.temperature2m[i],
                precipitation: hourly.precipitation[i],
                windSpeed: hourly.windSpeed10m[i],
                windDirection: hourly.windDirection10m[i],
                weatherCode: hourly.weatherCode[i]
            )
            forecasts.append(forecast)
        }
        
        return forecasts
    }
    
    private func processDailyData(_ daily: DailyWeather) -> [DailyForecast] {
        var forecasts: [DailyForecast] = []
        
        for i in 0..<min(daily.time.count, 7) { // Get next 7 days
            let forecast = DailyForecast(
                date: daily.time[i],
                maxTemp: daily.temperature2mMax[i],
                minTemp: daily.temperature2mMin[i],
                precipitation: daily.precipitationSum[i],
                maxWindSpeed: daily.windSpeed10mMax[i]
            )
            forecasts.append(forecast)
        }
        
        return forecasts
    }
}

// MARK: - Forecast Models
struct HourlyForecast: Identifiable {
    let id = UUID()
    let time: String
    let temperature: Double
    let precipitation: Double
    let windSpeed: Double
    let windDirection: Int
    let weatherCode: Int
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return time
    }
    
    var isGoodFishing: Bool {
        // Fishing is generally better in moderate conditions
        let tempRange: ClosedRange<Double> = 10.0...25.0 // Celsius
        let windRange: ClosedRange<Double> = 0.0...20.0 // km/h
        let precipitationRange: ClosedRange<Double> = 0.0...5.0 // mm
        
        return tempRange.contains(temperature) &&
               windRange.contains(windSpeed) &&
               precipitationRange.contains(precipitation)
    }
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: String
    let maxTemp: Double
    let minTemp: Double
    let precipitation: Double
    let maxWindSpeed: Double
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: self.date) {
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
        return date
    }
    
    var isGoodFishing: Bool {
        let tempRange: ClosedRange<Double> = 10.0...25.0
        let windRange: ClosedRange<Double> = 0.0...20.0
        let precipitationRange: ClosedRange<Double> = 0.0...10.0
        
        let avgTemp = (maxTemp + minTemp) / 2
        return tempRange.contains(avgTemp) &&
               windRange.contains(maxWindSpeed) &&
               precipitationRange.contains(precipitation)
    }
}
