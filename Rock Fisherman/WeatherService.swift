import Foundation
import CryptoKit
import CoreLocation
import SwiftUI
import os

// MARK: - Weather Service
class WeatherService: ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var waveData: WaveData?
    @Published var hourlyWaveData: [HourlyWaveData] = []
    @Published var dailyWaveData: [DailyWaveData] = []
    @Published var nearestWaveLocation: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    // Tide data
    @Published var hourlyTide: [TideHeight] = []
    @Published var dailyTideExtremes: [DailyTide] = []
    @Published var tideCopyright: String?
    @Published var isLoadingTides: Bool = false
    
    private let baseURL = "https://api.open-meteo.com/v1"
    private let marineBaseURL = "https://marine-api.open-meteo.com/v1"
    
    func fetchWeather(for location: CLLocation) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Fetch all providers in parallel to minimize total latency
        async let weatherTask: Void = fetchWeatherData(for: location)
        async let waveTask: Void = fetchWaveData(for: location)
        async let tideTask: Void = fetchTideData(for: location)
        _ = await (weatherTask, waveTask, tideTask)
        
        // Merge wave data with forecasts after both are fetched
        await MainActor.run {
            self.mergeWaveDataWithForecasts()
            self.mergeTideDataWithForecasts()
            self.isLoading = false
        }
    }
    
    private func fetchWeatherData(for location: CLLocation) async {
        let urlString = "\(baseURL)/forecast?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,precipitation,wind_speed_10m,wind_direction_10m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,wind_direction_10m_dominant,weather_code&timezone=auto"
        
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
                
                // Merge wave data with forecasts
                // self.mergeWaveDataWithForecasts() // This line is moved to fetchWeather
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Weather data parsing failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func fetchWaveData(for location: CLLocation) async {
        let urlString = "\(marineBaseURL)/marine?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current=wave_height,wave_direction,wave_period&hourly=wave_height,wave_direction,wave_period&daily=wave_height_max&timezone=auto"
        
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
                self.hourlyWaveData = waveResponse.hourly.toHourlyWaveData()
                self.dailyWaveData = waveResponse.daily.toDailyWaveData()
                self.nearestWaveLocation = nil
            }
            
        } catch {
            // Try to find nearest location with wave data
            await findNearestWaveLocation(for: location)
        }
    }

    // MARK: - Tide
    private func fetchTideData(for location: CLLocation) async {
        let tideService = TideService()
        // Pre-flight diagnostics: log whether env/plist key is visible to the process
        // Debug logs removed
        await MainActor.run { self.isLoadingTides = true }
        do {
            // Debug logs removed
            let (heights, extremes, notice) = try await tideService.fetchTides(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            await MainActor.run {
                self.hourlyTide = heights
                self.dailyTideExtremes = extremes
                self.tideCopyright = notice
                self.isLoadingTides = false
            }
        } catch {
            await MainActor.run {
                if let e = error as? TideServiceError {
                    switch e {
                    case .notAvailable:
                        let envKey = ProcessInfo.processInfo.environment["WORLDTIDES_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let plistKey = (Bundle.main.object(forInfoDictionaryKey: "WORLDTIDES_API_KEY") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        _ = envKey == nil ? "nil" : "len=\(envKey!.count)"
                        _ = plistKey == nil ? "nil" : "len=\(plistKey!.count)"
                        // Debug logs removed
                        self.nearestWaveLocation = "Tide data unavailable (missing API key). Add WORLDTIDES_API_KEY in Scheme or Info.plist."
                    case .http(let code):
                        // Debug logs removed
                        self.nearestWaveLocation = "Tide service HTTP \(code)"
                    case .decode(_):
                        // Debug logs removed
                        self.nearestWaveLocation = "Tide data format error"
                    }
                } else {
                    // Debug logs removed
                }
                self.hourlyTide = []
                self.dailyTideExtremes = []
                self.tideCopyright = nil
                self.isLoadingTides = false
            }
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
            let urlString = "\(marineBaseURL)/marine?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current=wave_height,wave_direction,wave_period&hourly=wave_height,wave_direction,wave_period&daily=wave_height_max&timezone=auto"
            
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }
                
                let decoder = JSONDecoder()
                let waveResponse = try decoder.decode(WaveResponse.self, from: data)
                
                await MainActor.run {
                    self.waveData = waveResponse.current
                    self.hourlyWaveData = waveResponse.hourly.toHourlyWaveData()
                    self.dailyWaveData = waveResponse.daily.toDailyWaveData()
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
            self.hourlyWaveData = []
            self.dailyWaveData = []
            self.nearestWaveLocation = "No wave data available for this location"
        }
    }
    
    private func mergeWaveDataWithForecasts() {
        // Merge hourly wave data
        for i in 0..<hourlyForecast.count {
            if i < hourlyWaveData.count {
                hourlyForecast[i].waveHeight = hourlyWaveData[i].waveHeight
                hourlyForecast[i].waveDirection = hourlyWaveData[i].waveDirection
                hourlyForecast[i].wavePeriod = hourlyWaveData[i].wavePeriod
            }
        }
        
        // Merge daily wave data
        for i in 0..<dailyForecast.count {
            if i < dailyWaveData.count {
                dailyForecast[i].waveHeight = dailyWaveData[i].maxWaveHeight
                dailyForecast[i].waveDirection = dailyWaveData[i].waveDirection // Will be nil
                dailyForecast[i].wavePeriod = dailyWaveData[i].maxWavePeriod   // Will be nil
            }
        }
    }

    private func mergeTideDataWithForecasts() {
        // Attach hourly tide height to hourly forecasts by matching timestamps
        guard !hourlyTide.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        // Build dictionary safely even if provider returns duplicate timestamps
        var tideDict: [String: Double] = [:]
        for sample in hourlyTide { tideDict[sample.time] = sample.height }
        for i in 0..<hourlyForecast.count {
            let key = hourlyForecast[i].time
            if let h = tideDict[key] {
                hourlyForecast[i].tideHeight = h
            }
        }

        // For each day, use extremes list to assign high/low heights and times
        var dayToExtremes: [String: DailyTide] = [:]
        for d in dailyTideExtremes { dayToExtremes[d.date] = d }
        for i in 0..<dailyForecast.count {
            let day = dailyForecast[i].date
            if let d = dayToExtremes[day] {
                if let maxHigh = d.highs.max(by: { $0.height < $1.height }) {
                    dailyForecast[i].highTideHeight = maxHigh.height
                    dailyForecast[i].highTideTime = formatTime(maxHigh.time)
                }
                if let minLow = d.lows.min(by: { $0.height < $1.height }) {
                    dailyForecast[i].lowTideHeight = minLow.height
                    dailyForecast[i].lowTideTime = formatTime(minLow.time)
                }
            }
        }
    }

    private func formatTime(_ iso: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = formatter.date(from: String(iso.prefix(16))) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return String(iso.suffix(5))
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

// MARK: - Tide Models and Service
struct TideHeight: Identifiable, Codable {
    let id = UUID()
    let time: String // yyyy-MM-dd'T'HH:mm
    let height: Double // meters

    enum CodingKeys: String, CodingKey {
        case time, height
    }
}

struct TideExtreme: Identifiable, Codable {
    let id = UUID()
    let time: String
    let height: Double

    enum CodingKeys: String, CodingKey {
        case time, height
    }
}

struct DailyTide: Identifiable, Codable {
    let id = UUID()
    let date: String // yyyy-MM-dd
    let highs: [TideExtreme]
    let lows: [TideExtreme]

    enum CodingKeys: String, CodingKey {
        case date, highs, lows
    }
}

enum TideServiceError: Error {
    case notAvailable
    case http(Int)
    case decode(String)
}

class TideService {
    // WorldTides API integration
    // Requires Info.plist key: WORLDTIDES_API_KEY
    // Simple in-memory caches with short TTL to improve perceived reliability after app resumes
    private static var cacheHeights: [String: (ts: Date, data: [TideHeight])] = [:]
    private static var cacheExtremes: [String: (ts: Date, data: [DailyTide])] = [:]
    private static let cacheTTL: TimeInterval = 10 * 60 // 10 minutes
    // Coalesce identical in-flight requests per lat/lon/day key
    private static var inflightTasks: [String: Task<([TideHeight], [DailyTide], String?), Error>] = [:]
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RockFisherman", category: "Tides")

    private static func cacheKey(latitude: Double, longitude: Double, day: String) -> String {
        let latStr = String(format: "%.3f", latitude) // ~100m precision
        let lonStr = String(format: "%.3f", longitude)
        return "lat=\(latStr)|lon=\(lonStr)|day=\(day)"
    }

    func fetchTides(latitude: Double, longitude: Double) async throws -> ([TideHeight], [DailyTide], String?) {
        let tideDebug = ProcessInfo.processInfo.environment["TIDE_DEBUG"] == "1"
        // Load from environment first, then Info.plist. Trim whitespace.
        let envKeyRaw = ProcessInfo.processInfo.environment["WORLDTIDES_API_KEY"]
        let plistKeyRaw = Bundle.main.object(forInfoDictionaryKey: "WORLDTIDES_API_KEY") as? String
        let combinedRaw = (envKeyRaw?.isEmpty == false ? envKeyRaw : plistKeyRaw) ?? ""
        let trimmed = combinedRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = TideService.sanitizeKey(trimmed)
        // Debug print of key (masked) + hash so the user can verify correctness
        if tideDebug {
            let keyHash: String = {
                guard !apiKey.isEmpty else { return "nil" }
                let digest = SHA256.hash(data: Data(apiKey.utf8))
                return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(12).description
            }()
            print("[Tides] API key present: \(!apiKey.isEmpty), sha256=\(keyHash)")
        }
        guard !apiKey.isEmpty else {
            TideService.logger.error("API key not available")
            throw TideServiceError.notAvailable
        }

        // Fetch hourly heights and extremes starting today (UTC is fine; API returns ISO strings with offset)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        let key = TideService.cacheKey(latitude: latitude, longitude: longitude, day: today)
        TideService.logger.info("fetch start lat=\(latitude, format: .fixed(precision: 3)) lon=\(longitude, format: .fixed(precision: 3)) day=\(today, privacy: .public)")

        // Serve fresh cache if not expired (both heights and extremes)
        if let h = TideService.cacheHeights[key], let e = TideService.cacheExtremes[key] {
            if Date().timeIntervalSince(h.ts) < TideService.cacheTTL && Date().timeIntervalSince(e.ts) < TideService.cacheTTL {
                if tideDebug { print("[Tides] cache hit heights=\(h.data.count) extremesDays=\(e.data.count)") }
                TideService.logger.info("cache hit heights=\(h.data.count) extremesDays=\(e.data.count)")
                return (h.data, e.data, nil)
            }
        }
        // Coalesce identical in-flight requests by key
        if let existing = TideService.inflightTasks[key] {
            if tideDebug { print("[Tides] coalesced with in-flight fetch for key=\(key)") }
            TideService.logger.info("coalesced with in-flight fetch for key=\(key, privacy: .public)")
            return try await existing.value
        }

        let task = Task { () -> ([TideHeight], [DailyTide], String?) in
            return try await self.fetchTidesNetwork(latitude: latitude, longitude: longitude, today: today, apiKey: apiKey, tideDebug: tideDebug, cacheKey: key)
        }
        TideService.inflightTasks[key] = task
        defer { TideService.inflightTasks[key] = nil }
        return try await task.value
    }

    // Execute the actual network and mapping work. Separated so multiple callers can await a single in-flight Task.
    private func fetchTidesNetwork(latitude: Double, longitude: Double, today: String, apiKey: String, tideDebug: Bool, cacheKey: String) async throws -> ([TideHeight], [DailyTide], String?) {
        // Helpers
        func buildURL(includeHeights: Bool, includeExtremes: Bool, days: Int) -> URL? {
            var c = URLComponents(string: "https://www.worldtides.info/api/v3")!
            var items: [URLQueryItem] = []
            if includeHeights { items.append(URLQueryItem(name: "heights", value: nil)) }
            if includeExtremes { items.append(URLQueryItem(name: "extremes", value: nil)) }
            items.append(contentsOf: [
                URLQueryItem(name: "lat", value: String(latitude)),
                URLQueryItem(name: "lon", value: String(longitude)),
                URLQueryItem(name: "date", value: today),
                URLQueryItem(name: "days", value: String(days)),
                URLQueryItem(name: "localtime", value: "true"),
                URLQueryItem(name: "datum", value: "LAT"),
                URLQueryItem(name: "units", value: "metric"),
                URLQueryItem(name: "key", value: apiKey)
            ])
            c.queryItems = items
            return c.url
        }

        func buildURLWithDate(_ startDate: String, includeHeights: Bool, includeExtremes: Bool, days: Int) -> URL? {
            var c = URLComponents(string: "https://www.worldtides.info/api/v3")!
            var items: [URLQueryItem] = []
            if includeHeights { items.append(URLQueryItem(name: "heights", value: nil)) }
            if includeExtremes { items.append(URLQueryItem(name: "extremes", value: nil)) }
            items.append(contentsOf: [
                URLQueryItem(name: "lat", value: String(latitude)),
                URLQueryItem(name: "lon", value: String(longitude)),
                URLQueryItem(name: "date", value: startDate),
                URLQueryItem(name: "days", value: String(days)),
                URLQueryItem(name: "localtime", value: "true"),
                URLQueryItem(name: "datum", value: "LAT"),
                URLQueryItem(name: "units", value: "metric"),
                URLQueryItem(name: "key", value: apiKey)
            ])
            c.queryItems = items
            return c.url
        }

        func request(_ url: URL) async throws -> (Data, HTTPURLResponse) {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 12
            config.timeoutIntervalForResource = 15
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: config)

            var attempt = 0
            var lastError: Error?
            while attempt < 3 {
                let start = Date()
                if tideDebug {
                    let masked = url.absoluteString.replacingOccurrences(of: apiKey, with: "***")
                    print("[Tides] GET (try=\(attempt+1)) \(masked)")
                }
                TideService.logger.debug("GET try=\(attempt+1) url=\(url.absoluteString, privacy: .public)")
                do {
                    let (d, r) = try await session.data(from: url)
                    let durMs = Int(Date().timeIntervalSince(start) * 1000)
                    guard let http = r as? HTTPURLResponse else { throw TideServiceError.http(-1) }
                    if tideDebug {
                        print("[Tides] <- status=\(http.statusCode) bytes=\(d.count) dur=\(durMs)ms")
                    }
                    TideService.logger.info("<- status=\(http.statusCode) bytes=\(d.count) durMs=\(durMs)")
                    return (d, http)
                } catch {
                    lastError = error
                    attempt += 1
                    if attempt < 3 {
                        let backoff = pow(2.0, Double(attempt - 1)) * 0.75
                        if tideDebug { print("[Tides] retry in \(String(format: "%.2f", backoff))s after error: \(error.localizedDescription)") }
                        TideService.logger.warning("retry #\(attempt) after error: \(String(describing: error), privacy: .public)")
                        try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                        continue
                    }
                }
            }
            TideService.logger.error("request failed after retries error=\(String(describing: lastError), privacy: .public)")
            throw lastError ?? TideServiceError.http(-1)
        }

        // Try combined; then fallback to chunked extremes and 3-day heights
        var decoded: WorldTidesCombined? = nil
        if let url = buildURL(includeHeights: true, includeExtremes: true, days: 7) {
            let (d, http) = try await request(url)
            if http.statusCode == 200 {
                decoded = try? JSONDecoder().decode(WorldTidesCombined.self, from: d)
                if tideDebug {
                    let hCount = (try? JSONDecoder().decode(WorldTidesCombined.self, from: d).heights.count) ?? -1
                    let eCount = (try? JSONDecoder().decode(WorldTidesCombined.self, from: d).extremes.count) ?? -1
                    print("[Tides] combined decode heights=\(hCount) extremes=\(eCount)")
                }
            } else if tideDebug {
                print("[Tides] combined request failed status=\(http.statusCode)")
            }
        }

        if decoded == nil {
            var extremes: [WorldTideExtreme] = []
            var heights: [WorldTideHeight] = []
            let dateFormatter = DateFormatter(); dateFormatter.dateFormat = "yyyy-MM-dd"
            let calendar = Calendar.current
            let baseDate = dateFormatter.date(from: today) ?? Date()
            var offsetDays = 0
            while offsetDays < 7 {
                let span = min(3, 7 - offsetDays)
                if let date = calendar.date(byAdding: .day, value: offsetDays, to: baseDate) {
                    let startStr = dateFormatter.string(from: date)
                    if let u = buildURLWithDate(startStr, includeHeights: false, includeExtremes: true, days: span) {
                        let (dChunk, httpChunk) = try await request(u)
                        if httpChunk.statusCode == 200 {
                            if let tmp = try? JSONDecoder().decode(WorldTidesCombined.self, from: dChunk) {
                                extremes.append(contentsOf: tmp.extremes)
                                if tideDebug { print("[Tides] extremes chunk start=\(startStr) days=\(span) decoded=\(tmp.extremes.count)") }
                            }
                        } else if tideDebug {
                            print("[Tides] extremes chunk failed status=\(httpChunk.statusCode) start=\(startStr) days=\(span)")
                        }
                        try? await Task.sleep(nanoseconds: 180_000_000)
                    }
                }
                offsetDays += span
            }

            if let u2 = buildURL(includeHeights: true, includeExtremes: false, days: 3) {
                let (d2, http2) = try await request(u2)
                if http2.statusCode == 200 {
                    if let tmp2 = try? JSONDecoder().decode(WorldTidesCombined.self, from: d2) { heights = tmp2.heights; if tideDebug { print("[Tides] heights decoded=\(heights.count)") } }
                } else if tideDebug {
                    print("[Tides] heights request failed status=\(http2.statusCode)")
                }
            }
            decoded = WorldTidesCombined(heights: heights, extremes: extremes, copyright: nil)
        }

        guard let decoded = decoded else {
            TideService.logger.error("decode failed: no data decoded")
            throw TideServiceError.notAvailable
        }

        let outHeights: [TideHeight] = decoded.heights.map { h in
            TideHeight(time: Self.normalizeISOMinute(h.date), height: h.height)
        }

        var byDay: [String: (highs: [TideExtreme], lows: [TideExtreme])] = [:]
        for e in decoded.extremes {
            let iso = Self.normalizeISOMinute(e.date)
            let day = String(iso.prefix(10))
            if e.type.lowercased() == "high" {
                byDay[day, default: ([], [])].highs.append(TideExtreme(time: iso, height: e.height))
            } else {
                byDay[day, default: ([], [])].lows.append(TideExtreme(time: iso, height: e.height))
            }
        }
        let outExtremes: [DailyTide] = byDay.keys.sorted().map { day in
            var highs = byDay[day]?.highs ?? []
            var lows = byDay[day]?.lows ?? []
            highs.sort { $0.height > $1.height }
            lows.sort { $0.height < $1.height }
            if highs.isEmpty { highs = [] }
            if lows.isEmpty { lows = [] }
            return DailyTide(date: day, highs: Array(highs.prefix(2)), lows: Array(lows.prefix(2)))
        }
        if tideDebug { print("[Tides] mapped heights=\(outHeights.count) daysWithExtremes=\(outExtremes.count)") }
        TideService.logger.info("mapped heights=\(outHeights.count) daysWithExtremes=\(outExtremes.count)")

        TideService.cacheHeights[cacheKey] = (ts: Date(), data: outHeights)
        TideService.cacheExtremes[cacheKey] = (ts: Date(), data: outExtremes)
        TideService.logger.info("fetch complete heights=\(outHeights.count) days=\(outExtremes.count)")
        return (outHeights, outExtremes, decoded.copyright)
    }

    private static func normalizeISOMinute(_ iso: String) -> String {
        // Trim timezone offset ONLY if it appears after the 'T'.
        // Example: 2025-04-06T12:30+10:00 → 2025-04-06T12:30
        if let tIdx = iso.firstIndex(of: "T") {
            let afterT = iso.index(after: tIdx)..<iso.endIndex
            let tail = iso[afterT]
            if let plus = tail.firstIndex(of: "+") ?? tail.firstIndex(of: "-") {
                let base = String(iso[..<plus])
                return String(base.prefix(16))
            }
        }
        return String(iso.prefix(16))
    }

    private static func sanitizeKey(_ raw: String) -> String {
        // Extract the first UUID-looking token. Many copy-paste issues add invisible chars; this recovers the key.
        let pattern = "[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: raw, options: [], range: NSRange(location: 0, length: raw.utf16.count)),
           let range = Range(match.range, in: raw) {
            return String(raw[range])
        }
        return raw
    }
}

// MARK: - WorldTides API DTOs
private struct WorldTidesCombined: Decodable {
    let heights: [WorldTideHeight]
    let extremes: [WorldTideExtreme]
    let copyright: String?
}

private struct WorldTideHeight: Decodable {
    let date: String // ISO with offset
    let height: Double
}

private struct WorldTideExtreme: Decodable {
    let date: String
    let height: Double
    let type: String // High / Low
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
                    weatherCode: weather,
                    waveHeight: nil, // Will be populated from wave data
                    waveDirection: nil,
                    wavePeriod: nil
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
    let windDirection10mDominant: [Int]
    let weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationSum = "precipitation_sum"
        case windSpeed10mMax = "wind_speed_10m_max"
        case windDirection10mDominant = "wind_direction_10m_dominant"
        case weatherCode = "weather_code"
    }
    
    func toDailyForecasts() -> [DailyForecast] {
        return zip(time, zip(temperature2mMax, zip(temperature2mMin, zip(precipitationSum, zip(windSpeed10mMax, zip(windDirection10mDominant, weatherCode))))))
            .map { date, data in
                let (maxTemp, (minTemp, (precip, (windSpeed, (windDir, weather))))) = data
                return DailyForecast(
                    date: date,
                    maxTemp: maxTemp,
                    minTemp: minTemp,
                    precipitation: precip,
                    maxWindSpeed: windSpeed,
                    windDirection: windDir,
                    weatherCode: weather,
                    waveHeight: nil, // Will be populated from wave data
                    waveDirection: nil,
                    wavePeriod: nil
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
    var waveHeight: Double?
    var waveDirection: Int?
    var wavePeriod: Double?
    var tideHeight: Double?
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature
        case precipitation
        case windSpeed
        case windDirection
        case weatherCode
        case waveHeight
        case waveDirection
        case wavePeriod
        case tideHeight
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
    let windDirection: Int
    let weatherCode: Int
    var waveHeight: Double?
    var waveDirection: Int?
    var wavePeriod: Double?
    var highTideHeight: Double?
    var lowTideHeight: Double?
    var highTideTime: String?
    var lowTideTime: String?
    
    enum CodingKeys: String, CodingKey {
        case date
        case maxTemp
        case minTemp
        case precipitation
        case maxWindSpeed
        case windDirection
        case weatherCode
        case waveHeight
        case waveDirection
        case wavePeriod
        case highTideHeight
        case lowTideHeight
        case highTideTime
        case lowTideTime
    }
    
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
    let hourly: HourlyWaveResponse
    let daily: DailyWaveResponse
}

struct HourlyWaveResponse: Codable {
    let time: [String]
    let waveHeight: [Double]
    let waveDirection: [Int]
    let wavePeriod: [Double]
    
    enum CodingKeys: String, CodingKey {
        case time
        case waveHeight = "wave_height"
        case waveDirection = "wave_direction"
        case wavePeriod = "wave_period"
    }
    
    func toHourlyWaveData() -> [HourlyWaveData] {
        return zip(time, zip(waveHeight, zip(waveDirection, wavePeriod)))
            .map { time, data in
                let (height, (direction, period)) = data
                return HourlyWaveData(
                    time: time,
                    waveHeight: height,
                    waveDirection: direction,
                    wavePeriod: period
                )
            }
    }
}

struct DailyWaveResponse: Codable {
    let time: [String]
    let waveHeightMax: [Double]
    
    enum CodingKeys: String, CodingKey {
        case time
        case waveHeightMax = "wave_height_max"
    }
    
    func toDailyWaveData() -> [DailyWaveData] {
        return zip(time, waveHeightMax)
            .map { time, height in
                return DailyWaveData(
                    date: time,
                    maxWaveHeight: height,
                    waveDirection: nil, // Not available in daily data
                    maxWavePeriod: nil  // Not available in daily data
                )
            }
    }
}

struct HourlyWaveData: Identifiable, Codable {
    let id = UUID()
    let time: String
    let waveHeight: Double
    let waveDirection: Int
    let wavePeriod: Double
    
    enum CodingKeys: String, CodingKey {
        case time
        case waveHeight
        case waveDirection
        case wavePeriod
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

struct DailyWaveData: Identifiable, Codable {
    let id = UUID()
    let date: String
    let maxWaveHeight: Double
    let waveDirection: Int?
    let maxWavePeriod: Double?
    
    enum CodingKeys: String, CodingKey {
        case date
        case maxWaveHeight
        case waveDirection
        case maxWavePeriod
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: self.date) {
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
        return date
    }
    
    var maxWaveHeightFormatted: String {
        return String(format: "%.1fm", maxWaveHeight)
    }
    
    var waveDirectionFormatted: String {
        return "\(waveDirection ?? 0)°" // Handle optional
    }
    
    var maxWavePeriodFormatted: String {
        return String(format: "%.1fs", maxWavePeriod ?? 0.0) // Handle optional
    }
    
    var isGoodFishing: Bool {
        let heightRange: ClosedRange<Double> = 0.5...2.5
        let periodRange: ClosedRange<Double> = 5.0...12.0
        return heightRange.contains(maxWaveHeight) && periodRange.contains(maxWavePeriod ?? 0.0) // Handle optional
    }
    
    var fishingCondition: String {
        if isGoodFishing {
            return "Good"
        } else if maxWaveHeight < 0.5 {
            return "Too Calm"
        } else if maxWaveHeight > 2.5 {
            return "Too Rough"
        } else if maxWavePeriod ?? 0.0 < 5.0 {
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
