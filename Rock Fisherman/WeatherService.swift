import Foundation
import CoreLocation
import SwiftUI

// MARK: - Weather Service
class WeatherService: ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var waveData: WaveData?
    @Published var nearestWaveLocation: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://api.open-meteo.com/v1"
    private let marineBaseURL = "https://marine-api.open-meteo.com/v1"
    
    func fetchWeather(for location: CLLocation) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Fetch weather data
        await fetchWeatherData(for: location)
        
        // Fetch wave data
        await fetchWaveData(for: location)
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func fetchWeatherData(for location: CLLocation) async {
        let urlString = "\(baseURL)/forecast?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,precipitation,wind_speed_10m,wind_direction_10m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code&timezone=auto"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "Invalid URL"
            }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    errorMessage = "HTTP error: \(response)"
                }
                return
            }
            
            let decoder = JSONDecoder()
            let weatherResponse = try decoder.decode(WeatherResponse.self, from: data)
            
            await MainActor.run {
                self.currentWeather = weatherResponse.current
                self.hourlyForecast = weatherResponse.hourly.toHourlyForecasts()
                self.dailyForecast = weatherResponse.daily.toDailyForecasts()
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Weather data parsing failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func fetchWaveData(for location: CLLocation) async {
        let urlString = "\(marineBaseURL)/marine?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current=wave_height,wave_direction,wave_period&hourly=wave_height,wave_direction,wave_period&timezone=auto"
        
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // Try to find nearest location with wave data
                await findNearestWaveLocation(for: location)
                return
            }
            
            let decoder = JSONDecoder()
            let waveResponse = try decoder.decode(WaveResponse.self, from: data)
            
            await MainActor.run {
                self.waveData = waveResponse.current
                self.nearestWaveLocation = nil
            }
            
        } catch {
            // Try to find nearest location with wave data
            await findNearestWaveLocation(for: location)
        }
    }
    
    private func findNearestWaveLocation(for location: CLLocation) async {
        // Try some common coastal locations around Australia
        let coastalLocations = [
            ("Sydney", CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
            ("Bondi", CLLocationCoordinate2D(latitude: -33.8915, longitude: 151.2767)),
            ("Manly", CLLocationCoordinate2D(latitude: -33.7967, longitude: 151.2850)),
            ("Palm Beach", CLLocationCoordinate2D(latitude: -33.5967, longitude: 151.3233)),
            ("Clareville", CLLocationCoordinate2D(latitude: -33.6333, longitude: 151.3333)),
            ("Newcastle", CLLocationCoordinate2D(latitude: -32.9283, longitude: 151.7817)),
            ("Gold Coast", CLLocationCoordinate2D(latitude: -28.0167, longitude: 153.4000)),
            ("Brisbane", CLLocationCoordinate2D(latitude: -27.4698, longitude: 153.0251)),
            ("Melbourne", CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)),
            ("Adelaide", CLLocationCoordinate2D(latitude: -34.9285, longitude: 138.6007)),
            ("Perth", CLLocationCoordinate2D(latitude: -31.9505, longitude: 115.8605))
        ]
        
        for (name, coordinate) in coastalLocations {
            let urlString = "\(marineBaseURL)/marine?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current=wave_height,wave_direction,wave_period&timezone=auto"
            
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }
                
                let decoder = JSONDecoder()
                let waveResponse = try decoder.decode(WaveResponse.self, from: data)
                
                await MainActor.run {
                    self.waveData = waveResponse.current
                    self.nearestWaveLocation = "Using wave data from \(name) (nearest available location)"
                }
                return
                
            } catch {
                continue
            }
        }
        
        // If no wave data found anywhere, set to nil
        await MainActor.run {
            self.waveData = nil
            self.nearestWaveLocation = "No wave data available for this location"
        }
    }
    
    private func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Missing field '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Type mismatch for field '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))': expected \(type)"
        case .valueNotFound(let type, let context):
            return "Value not found for type \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        @unknown default:
            return "Unknown decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Weather Response Models
struct WeatherResponse: Codable {
    let current: CurrentWeather
    let hourly: HourlyResponse
    let daily: DailyResponse
}

// MARK: - Hourly Response Models
struct HourlyResponse: Codable {
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
    
    func toHourlyForecasts() -> [HourlyForecast] {
        return zip(time, zip(temperature2m, zip(precipitation, zip(windSpeed10m, zip(windDirection10m, weatherCode)))))
            .map { time, data in
                let (temp, (precip, (windSpeed, (windDir, weather)))) = data
                return HourlyForecast(
                    time: time,
                    temperature: temp,
                    precipitation: precip,
                    windSpeed: windSpeed,
                    windDirection: windDir,
                    weatherCode: weather
                )
            }
    }
}

// MARK: - Daily Response Models
struct DailyResponse: Codable {
    let time: [String]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationSum: [Double]
    let windSpeed10mMax: [Double]
    let weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationSum = "precipitation_sum"
        case windSpeed10mMax = "wind_speed_10m_max"
        case weatherCode = "weather_code"
    }
    
    func toDailyForecasts() -> [DailyForecast] {
        return zip(time, zip(temperature2mMax, zip(temperature2mMin, zip(precipitationSum, zip(windSpeed10mMax, weatherCode)))))
            .map { date, data in
                let (maxTemp, (minTemp, (precip, (windSpeed, weather)))) = data
                return DailyForecast(
                    date: date,
                    maxTemp: maxTemp,
                    minTemp: minTemp,
                    precipitation: precip,
                    maxWindSpeed: windSpeed,
                    weatherCode: weather
                )
            }
    }
}

struct CurrentWeather: Codable {
    let time: String
    let temperature: Double
    let relativeHumidity: Int
    let apparentTemperature: Double
    let precipitation: Double
    let weatherCode: Int
    let windSpeed: Double
    let windDirection: Int
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return time
    }
    
    var formattedRelativeTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let forecastDate = formatter.date(from: time) else { return "" }
        
        let now = Date()
        let timeDifference = forecastDate.timeIntervalSince(now)
        let hours = Int(timeDifference / 3600)
        let minutes = Int((timeDifference.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "in \(hours) hour\(hours == 1 ? "" : "s")"
        } else if minutes > 0 {
            return "in \(minutes) min\(minutes == 1 ? "" : "s")"
        } else {
            return "now"
        }
    }
    
    var weatherDescription: String {
        switch weatherCode {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
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
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case relativeHumidity = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitation, weatherCode = "weather_code"
        case windSpeed = "wind_speed_10m"
        case windDirection = "wind_direction_10m"
    }
}

// MARK: - Forecast Models
struct HourlyForecast: Identifiable, Codable {
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
    
    var formattedRelativeTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let forecastDate = formatter.date(from: time) else { return "" }
        
        let now = Date()
        let timeDifference = forecastDate.timeIntervalSince(now)
        let hours = Int(timeDifference / 3600)
        let minutes = Int((timeDifference.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "in \(hours) hour\(hours == 1 ? "" : "s")"
        } else if minutes > 0 {
            return "in \(minutes) min\(minutes == 1 ? "" : "s")"
        } else {
            return "now"
        }
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

struct DailyForecast: Identifiable, Codable {
    let id = UUID()
    let date: String
    let maxTemp: Double
    let minTemp: Double
    let precipitation: Double
    let maxWindSpeed: Double
    let weatherCode: Int
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: self.date) {
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
        return date
    }
    
    var weatherDescription: String {
        switch weatherCode {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
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

// MARK: - Wave Data Models
struct WaveResponse: Codable {
    let current: WaveData
}

struct WaveData: Codable {
    let time: String
    let interval: Int
    let waveHeight: Double
    let waveDirection: Int
    let wavePeriod: Double
    
    enum CodingKeys: String, CodingKey {
        case time, interval
        case waveHeight = "wave_height"
        case waveDirection = "wave_direction"
        case wavePeriod = "wave_period"
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return time
    }
    
    var waveHeightFormatted: String {
        return String(format: "%.1fm", waveHeight)
    }
    
    var waveDirectionFormatted: String {
        return "\(waveDirection)°"
    }
    
    var wavePeriodFormatted: String {
        return String(format: "%.1fs", wavePeriod)
    }
    
    var isGoodFishing: Bool {
        // Good fishing conditions: moderate wave height (0.5m - 2.5m) and reasonable period
        let heightRange: ClosedRange<Double> = 0.5...2.5
        let periodRange: ClosedRange<Double> = 5.0...12.0
        
        return heightRange.contains(waveHeight) && periodRange.contains(wavePeriod)
    }
    
    var fishingCondition: String {
        if isGoodFishing {
            return "Good"
        } else if waveHeight < 0.5 {
            return "Too Calm"
        } else if waveHeight > 2.5 {
            return "Too Rough"
        } else if wavePeriod < 5.0 {
            return "Poor"
        } else {
            return "Fair"
        }
    }
    
    var fishingConditionColor: Color {
        switch fishingCondition {
        case "Good": return .green
        case "Fair": return .orange
        case "Poor": return .red
        case "Too Calm": return .blue
        case "Too Rough": return .red
        default: return .gray
        }
    }
}
