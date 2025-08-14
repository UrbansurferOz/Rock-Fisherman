import SwiftUI
import Combine
import CoreLocation

// Shared helper: map degrees (0-360) to 16-point compass without slashes (e.g., ENE)
func windDirectionString(degrees: Int) -> String {
    let dirs = [
        "N","NNE","NE","ENE",
        "E","ESE","SE","SSE",
        "S","SSW","SW","WSW",
        "W","WNW","NW","NNW"
    ]
    var d = Double((degrees % 360 + 360) % 360)
    d = fmod(d + 11.25, 360.0)
    let idx = Int(d / 22.5) % 16
    return dirs[idx]
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
                
                if let currentWeather = weatherService.currentWeather {
                    // Tide Chart
                    TideChartView(weatherService: weatherService)

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
                            
                            VStack(spacing: 8) {
                                Image(systemName: "wind")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("Wind")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                VStack(spacing: 0) {
                                    Text("\(Int(round(currentWeather.windSpeed))) km/h")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(windDirectionString(degrees: currentWeather.windDirection))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
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

// MARK: - Hourly Forecast View (aligned)
struct HourlyForecastView: View {
    @ObservedObject var weatherService: WeatherService

    // Single source of truth for column widths (reduced to fit iPhone screens)
    private let colTime: CGFloat = 70
    private let colIcon: CGFloat = 20
    private let colTemp: CGFloat = 35
    private let colTide: CGFloat = 45
    private let colWind: CGFloat = 40
    private let colRain: CGFloat = 35
    private let colWave: CGFloat = 45   // a touch wider for "0.0m"
    private let colFish: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next 12 Hours")
                .font(.headline).fontWeight(.semibold)

            // ONE grid for header + rows ➜ columns align perfectly
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {

                // Header
                GridRow {
                    Text("Time")
                        .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                        .frame(width: colTime, alignment: .leading)

                    // Weather spans cloud icon + temperature columns
                    Text("Weather")
                        .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                        .frame(width: colIcon + colTemp, alignment: .leading)
                        .gridCellColumns(2)

                    Text("Tide")
                        .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                        .frame(width: colTide, alignment: .leading)

                    Text("Wind")
                        .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                        .frame(width: colWind, alignment: .leading)

                    Text("Rain")
                        .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                        .frame(width: colRain, alignment: .leading)

                    Text("Wave")
                        .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                        .frame(width: colWave, alignment: .leading)

                    // We won't add a header for tide; show below Temp in row

                    Text("")
                        .frame(width: colFish, alignment: .leading)
                }
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(6)

                // Rows
                ForEach(next12HoursForecast, id: \.id) { f in
                    GridRow {
                        // Time
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.formattedTime)
                                .font(.caption).fontWeight(.medium)
                        }
                        .frame(width: colTime, alignment: .leading)

                        // Cloud Icon
                        Image(systemName: weatherIcon(for: f.weatherCode))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: colIcon)

                        // Temp
                        Text("\(Int(round(f.temperature)))°")
                            .font(.caption).fontWeight(.medium)
                            .monospacedDigit()
                            .frame(width: colTemp, alignment: .leading)

                        // High Tide (tide height)
                        if let tide = f.tideHeight {
                            Text(String(format: "%.1fm", tide))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: colTide, alignment: .leading)
                        } else {
                            Text("–")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: colTide, alignment: .leading)
                        }

                        // Wind direction (e.g., ENE)
                        Text(windDirectionString(degrees: f.windDirection))
                            .font(.caption2)
                            .frame(width: colWind, alignment: .leading)

                        // Rain
                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill").font(.caption2).foregroundColor(.blue)
                            Text("\(Int(round(f.precipitation)))")
                                .font(.caption2).monospacedDigit()
                        }
                        .frame(width: colRain, alignment: .leading)

                        // Wave
                        if let h = f.waveHeight {
                            VStack(spacing: 2) {
                                Text(String(format: "%.1fm", h))
                                    .font(.caption2).fontWeight(.medium).monospacedDigit()
                                if let d = f.waveDirection {
                                    Text("\(d)°")
                                        .font(.caption2).foregroundColor(.secondary).monospacedDigit()
                                }
                            }
                            .frame(width: colWave, alignment: .leading)
                        } else {
                            Text("N/A")
                                .font(.caption2).foregroundColor(.secondary)
                                .frame(width: colWave, alignment: .leading)
                        }

                        // Fish
                        Image(systemName: f.isGoodFishing ? "fish.fill" : "fish")
                            .font(.caption2)
                            .foregroundColor(f.isGoodFishing ? .green : .gray)
                            .frame(width: colFish, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var next12HoursForecast: [HourlyForecast] {
        let now = Date()
        return weatherService.hourlyForecast
            .filter { f in
                guard let dt = parseForecastTime(f.time) else { return false }
                return dt > now
            }
            .prefix(12)
            .map { $0 }
    }

    // removed duplicate windDirectionString; using the shared helper above
    private func parseForecastTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: timeString)
    }

    private func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1,2,3: return "cloud.sun.fill"
        case 45,48: return "cloud.fog.fill"
        case 51,53,55: return "cloud.drizzle.fill"
        case 61,63,65: return "cloud.rain.fill"
        case 71,73,75,77,85,86: return "cloud.snow.fill"
        case 80,81,82: return "cloud.heavyrain.fill"
        case 95,96,99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}



// MARK: - Daily Forecast View
struct DailyForecastView: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if weatherService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if weatherService.dailyForecast.isEmpty {
                    Text("No daily forecast available")
                        .foregroundColor(.secondary)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(weatherService.dailyForecast) { forecast in
                            DailyRowView(forecast: forecast)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
    }
}

private struct DailyRowView: View {
    let forecast: DailyForecast
    var body: some View {
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
                    Text("\(windDirectionString(degrees: forecast.windDirection)) \(Int(round(forecast.maxWindSpeed))) km/h")
                        .font(.caption)
                }
                if let waveHeight = forecast.waveHeight {
                    HStack(spacing: 8) {
                        Image(systemName: "water.waves")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.1fm", waveHeight))")
                            .font(.caption)
                        if let waveDirection = forecast.waveDirection {
                            Text("\(waveDirection)°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if let hi = forecast.highTideHeight, let lo = forecast.lowTideHeight {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.teal)
                        if let th = forecast.highTideTime {
                            Text("\(String(format: "%.1fm", hi)) \(th)")
                                .lineLimit(1)
                        } else {
                            Text("\(String(format: "%.1fm", hi))")
                                .lineLimit(1)
                        }
                        Text("  ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundColor(.teal)
                        if let tl = forecast.lowTideTime {
                            Text("\(String(format: "%.1fm", lo)) \(tl)")
                                .lineLimit(1)
                        } else {
                            Text("\(String(format: "%.1fm", lo))")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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

// MARK: - Fishing News Models
struct FishingArticle: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let url: String
    let publishedAt: Date
    let source: String

    init(id: UUID = UUID(), title: String, description: String, url: String, publishedAt: Date, source: String) {
        self.id = id
        self.title = title
        self.description = description
        self.url = url
        self.publishedAt = publishedAt
        self.source = source
    }
}

// MARK: - NewsAPI.org Models
private struct NewsAPIResponse: Codable {
    let articles: [NewsAPIArticle]
}

private struct NewsAPIArticle: Codable {
    let title: String?
    let description: String?
    let url: String?
    let publishedAt: String?
    let source: NewsAPISource?
}

private struct NewsAPISource: Codable { let name: String? }

private struct NewsAPIErrorResponse: Codable {
    let status: String
    let code: String?
    let message: String?
}

// MARK: - Fishing News ViewModel (with 1-hour cache)
class FishingNewsViewModel: ObservableObject {
    @Published var articles: [FishingArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let cachePrefix = "FishingNewsCacheV2"
    private let cacheExpiry: TimeInterval = 3600 // 1 hour
    private var cancellables = Set<AnyCancellable>()

    func fetchNews(for location: CLLocation?, placeName: String?) {
        let locationKey = makeLocationKey(location: location, placeName: placeName)

        // Serve cached if fresh
        if let cached = loadCache(for: locationKey), !isCacheExpired(for: locationKey) {
            self.articles = cached
            return
        }

        isLoading = true
        errorMessage = nil

        let last30 = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let isoFormatter = ISO8601DateFormatter()
        let date30DaysAgo = isoFormatter.string(from: last30)

		let placeTokens: [String] = makePlaceTokens(from: placeName, location: location)
		let limitedTokens = Array(placeTokens.prefix(12))
		let baseTerms = "(fishing OR angler OR fisherman OR \"fishing report\" OR \"catch report\" OR \"live report\" OR \"fishing competition\" OR \"bag limit\" OR \"NSW Fisheries\" OR snapper OR bream OR flathead OR whiting OR kingfish OR salmon)"

        // Strict locality tokens: city + country only (ignore state)
        let strictLocationTokensLower: [String] = {
            guard let name = placeName, !name.isEmpty else { return [] }
            let parts = name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            guard !parts.isEmpty else { return [] }
            let country = parts.last
            let cityOrTown = parts.first
            var out: [String] = []
            if let country { out.append(country) }
            if let cityOrTown { out.append(cityOrTown) }
            // Deduplicate while preserving order
            var seen = Set<String>()
            var unique: [String] = []
            for t in out where !t.isEmpty {
                if !seen.contains(t) { unique.append(t); seen.insert(t) }
            }
            return unique
        }()

		// Heuristic query to bias toward local results with built-in NSW fallbacks
		var localityClause = limitedTokens
		if isInNewSouthWales(location) {
			localityClause.append(contentsOf: [
				"Sydney","Northern Beaches","Pittwater","Manly","Dee Why","Narrabeen","Newport","Avalon",
				"Bilgola","Mona Vale","Palm Beach","Australia"
			])
		}
		if isInVictoria(location) || (placeName ?? "").localizedCaseInsensitiveContains("Melbourne") || (placeName ?? "").localizedCaseInsensitiveContains("Victoria") {
			localityClause.append(contentsOf: [
				"Melbourne","Victoria","VIC","Port Phillip Bay","Port Phillip","Western Port","St Kilda",
				"Mornington","Frankston","Mordialloc","Brighton","Queenscliff","Sorrento","Gippsland","Williamstown"
			])
		}
		// Build a query capped to NewsAPI's 500-character limit (use a small safety margin)
		let dedupedTokens: [String] = {
			var seen = Set<String>()
			var out: [String] = []
			for t in localityClause {
				let key = t.lowercased()
				if !seen.contains(key) {
					seen.insert(key)
					out.append(t)
				}
			}
			return out
		}()
		let query = buildCappedQuery(baseTerms: baseTerms, tokens: dedupedTokens, maxChars: 480)
		// Encoded query not needed explicitly; URLComponents handles encoding

        // NewsAPI.org configuration — load from environment first, then Info.plist
        let envKey = ProcessInfo.processInfo.environment["YOUR_NEWSAPI_API_KEY"]
        let plistKey = Bundle.main.object(forInfoDictionaryKey: "YOUR_NEWSAPI_API_KEY") as? String
        let rawKey = (envKey?.isEmpty == false ? envKey : plistKey) ?? ""
        let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
		// Debug logs removed
        guard !apiKey.isEmpty else {
            self.isLoading = false
            self.errorMessage = "Missing NewsAPI key. Add YOUR_NEWSAPI_API_KEY in the Scheme or Info.plist."
            return
        }
        let dateParam = String(date30DaysAgo.prefix(10)) // yyyy-MM-dd

		var comps = URLComponents(string: "https://newsapi.org/v2/everything")!
		comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "from", value: dateParam),
            URLQueryItem(name: "language", value: "en"),
            // Fetch by recency; we will re-rank by combined relevance + recency equally weighted
			URLQueryItem(name: "sortBy", value: "publishedAt"),
			URLQueryItem(name: "pageSize", value: "100"),
			URLQueryItem(name: "searchIn", value: "title,description,content")
        ]

		guard let url = comps.url else {
            self.isLoading = false
            self.errorMessage = "Invalid news URL"
            return
        }
		// Debug logs removed

		var request = URLRequest(url: url)
		request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
		// Debug logs removed

        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, _ -> [FishingArticle] in
                let isoDecoder = ISO8601DateFormatter()
                let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                let fishingTermsLower: [String] = [
                    "fishing","angler","fisherman","fishing report","catch report","live report",
                    "fishing competition","bag limit","nsw fisheries","snapper","bream","flathead",
                    "whiting","kingfish","salmon","rock fishing","reef","shore","lure","bait"
                ]

                func computeFinalScore(textLower: String, published: Date, strictLoc: [String]) -> Double {
                    // Relevance from fishing terms and locality mentions
                    let fishHits = fishingTermsLower.reduce(0) { $0 + (textLower.contains($1) ? 1 : 0) }
                    let fishScore = min(1.0, Double(fishHits) / 3.0)
                    let locHits = strictLoc.reduce(0) { $0 + (textLower.contains($1) ? 1 : 0) }
                    let locScore = strictLoc.isEmpty ? 0.0 : min(1.0, Double(locHits) / 2.0)
                    let relevance = min(1.0, 0.7 * fishScore + 0.3 * locScore)
                    // Recency: 1.0 now, 0.0 at 30 days
                    let age = max(0.0, Date().timeIntervalSince(published))
                    let ageDays = age / 86400.0
                    let recency = max(0.0, 1.0 - ageDays / 30.0)
                    return 0.5 * relevance + 0.5 * recency
                }

                func isLocal(urlString: String?, textLower: String, strictLoc: [String]) -> Bool {
                    if strictLoc.isEmpty { return true }
                    if strictLoc.contains(where: { textLower.contains($0) }) { return true }
                    if let u = urlString, let host = URL(string: u)?.host?.lowercased() {
                        if strictLoc.contains("australia"), host.hasSuffix(".au") { return true }
                    }
                    return false
                }

                if let response = try? JSONDecoder().decode(NewsAPIResponse.self, from: data) {
                    var scored: [(FishingArticle, Double)] = []
                    scored.reserveCapacity(response.articles.count)
                    for doc in response.articles {
                        let title = doc.title ?? ""
                        let description = doc.description ?? ""
                        guard let url = doc.url, !title.isEmpty else { continue }
                        let published = (doc.publishedAt.flatMap { isoDecoder.date(from: $0) }) ?? Date()
                        guard published >= cutoff else { continue }
                        let textLower = (title + " " + description).lowercased()
                        // Must be fishing-related
                        let hasFishing = fishingTermsLower.contains { textLower.contains($0) }
                        guard hasFishing else { continue }
                        // Must be local to strict tokens (country/city)
                        guard isLocal(urlString: url, textLower: textLower, strictLoc: strictLocationTokensLower) else { continue }
                        let score = computeFinalScore(textLower: textLower, published: published, strictLoc: strictLocationTokensLower)
                        let article = FishingArticle(title: title, description: description, url: url, publishedAt: published, source: doc.source?.name ?? "Unknown")
                        scored.append((article, score))
                    }
                    // Sort by combined score desc, then most recent
                    return scored
                        .sorted { (a, b) in
                            if a.1 != b.1 { return a.1 > b.1 }
                            return a.0.publishedAt > b.0.publishedAt
                        }
                        .map { $0.0 }
                }

                if let err = try? JSONDecoder().decode(NewsAPIErrorResponse.self, from: data) {
                    let msg = err.message ?? err.code ?? "NewsAPI error"
                    throw NSError(domain: "NewsAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
                }

                throw NSError(domain: "NewsAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response"])
            }
			.receive(on: DispatchQueue.main)
			.sink { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
				if case let .failure(error) = completion {
                    self.errorMessage = error.localizedDescription
				// Debug logs removed
                }
			} receiveValue: { [weak self] fetched in
                guard let self = self else { return }
                self.articles = fetched
				// Debug logs removed
                self.saveCache(fetched, for: locationKey)
            }
            .store(in: &cancellables)
    }

    // MARK: - Cache Helpers
    private func cacheKey(for key: String) -> String { "\(cachePrefix)_\(key)" }
    private func cacheTsKey(for key: String) -> String { "\(cacheKey(for: key))_timestamp" }

    private func saveCache(_ articles: [FishingArticle], for key: String) {
        // Do not cache empty results to avoid pinning "no news" for an hour
        guard !articles.isEmpty else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(articles) {
            UserDefaults.standard.set(data, forKey: cacheKey(for: key))
            UserDefaults.standard.set(Date(), forKey: cacheTsKey(for: key))
        }
    }

    private func loadCache(for key: String) -> [FishingArticle]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: key)) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([FishingArticle].self, from: data)
    }

    private func isCacheExpired(for key: String) -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTsKey(for: key)) as? Date else { return true }
        return Date().timeIntervalSince(timestamp) > cacheExpiry
    }

    // MARK: - Helpers
    private func makeLocationKey(location: CLLocation?, placeName: String?) -> String {
        let lat = location?.coordinate.latitude ?? 0
        let lon = location?.coordinate.longitude ?? 0
        let latStr = String(format: "%.2f", lat) // ~1km precision
        let lonStr = String(format: "%.2f", lon)
        // Normalize to city + country only, ignoring any state component
        let normalizedPlace: String = {
            guard let name = placeName, !name.isEmpty else { return "" }
            let parts = name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let city = parts.first ?? ""
            let country = parts.count >= 2 ? parts.last ?? "" : ""
            let joined = [city, country]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
            return joined.lowercased().replacingOccurrences(of: " ", with: "_")
        }()
        return "\(normalizedPlace)_\(latStr)_\(lonStr)"
    }

private func makePlaceTokens(from placeName: String?, location: CLLocation?) -> [String] {
    var tokens: [String] = []
    if let placeName, !placeName.isEmpty {
        // Normalize to "City, Country" by stripping any state-like middle part
        // Examples:
        // - "Sydney, NSW, Australia" -> ["Sydney", "Australia"]
        // - "Sydney, Australia" -> ["Sydney", "Australia"]
        let parts = placeName
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var city: String? = nil
        var country: String? = nil
        if parts.count >= 2 {
            city = parts.first
            country = parts.last
        } else if parts.count == 1 {
            city = parts[0]
        }
        if let c = city { tokens.append(c) }
        if let ctry = country { tokens.append(ctry) }
    }
    if isInNewSouthWales(location) {
        tokens.append(contentsOf: [
            "Clareville","Avalon","Bilgola","Newport","Mona Vale","Narrabeen","Collaroy",
            "Dee Why","Manly","Palm Beach","Pittwater","Northern Beaches","Sydney","Hawkesbury"
        ])
    }
	let stopwords: Set<String> = ["new","south","wales","current","location"]
    let cleaned = tokens
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .filter { $0.count >= 3 }
        .filter { !stopwords.contains($0.lowercased()) }
    return Array(Set(cleaned))
    }
}

// MARK: - Fishing News View
struct FishingNewsView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var viewModel = FishingNewsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "newspaper")
                    .foregroundColor(.blue)
                Text("Fishing News & Catch Reports")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Azure/Bing news removed

            if viewModel.isLoading {
                ProgressView("Loading news...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let message = viewModel.errorMessage, viewModel.articles.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !viewModel.articles.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.articles) { article in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(article.title)
                    .font(.headline)
                                    .foregroundColor(.primary)

                                if !article.description.isEmpty {
                                    Text(article.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                                }

                                HStack(spacing: 4) {
                                    Text("Source:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(article.source)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(article.publishedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let url = URL(string: article.url) {
                                    Link("Read more", destination: url)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
                        }

                        // Attribution
                        Text("Powered by NewsAPI.org")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            } else if !viewModel.isLoading && viewModel.errorMessage == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No fishing news found for your area in the last 30 days.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Powered by NewsAPI.org")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.fetchNews(for: locationManager.location, placeName: locationManager.selectedLocationName)
        }
        .onChange(of: locationManager.location) { _, _ in
            viewModel.fetchNews(for: locationManager.location, placeName: locationManager.selectedLocationName)
        }
        .onChange(of: locationManager.selectedLocationName) { _, _ in
            viewModel.fetchNews(for: locationManager.location, placeName: locationManager.selectedLocationName)
        }
    }
}

// MARK: - NSW Region Check
private func isInNewSouthWales(_ location: CLLocation?) -> Bool {
    guard let loc = location else { return false }
    // Rough NSW bounding box: lat [-37.6, -28.0], lon [141.0, 154.1]
    let lat = loc.coordinate.latitude
    let lon = loc.coordinate.longitude
    return (lat >= -37.6 && lat <= -28.0) && (lon >= 141.0 && lon <= 154.1)
}

private func isInVictoria(_ location: CLLocation?) -> Bool {
    guard let loc = location else { return false }
    // Rough VIC bounding box
    let lat = loc.coordinate.latitude
    let lon = loc.coordinate.longitude
    return (lat >= -39.2 && lat <= -33.8) && (lon >= 140.7 && lon <= 150.1)
}

// Build a query like: "<base> (t1 OR t2 OR t3 ...)" but cap to maxChars
private func buildCappedQuery(baseTerms: String, tokens: [String], maxChars: Int) -> String {
    if tokens.isEmpty { return baseTerms }
    // Always try to keep the first N most relevant tokens
    var kept: [String] = []
    var current = baseTerms
    for token in tokens {
        // Try adding with OR separator
        let candidateKept = kept.isEmpty ? token : "\(kept.joined(separator: " OR ")) OR \(token)"
        let candidate = "\(baseTerms) (\(candidateKept))"
        if candidate.count <= maxChars {
            kept.append(token)
            current = candidate
        } else {
            break
        }
    }
    return current
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

// MARK: - Tide Chart View (24h smooth with fill + grid)
struct TideChartView: View {
    @ObservedObject var weatherService: WeatherService

    private let dateInFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()

    private let hourFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "water.waves.and.arrow.up")
                    .foregroundStyle(.teal)
                Text("24 Hour Forecast")
                    .font(.headline)
                Spacer()
            }

            GeometryReader { geo in
                let rect = geo.size.rect.inset(by: .init(top: 10, left: 10, bottom: 26, right: 34))
                let model = TideChartModel(
                    samples: weatherService.hourlyTide.compactMap { s in
                        guard let d = dateInFmt.date(from: s.time) else { return nil }
                        return (d, s.height)
                    },
                    spanHours: 24,
                    endAtNow: false,
                    rect: rect
                )

                ZStack {
                    // Grid (horizontal 5 lines)
                    ForEach(model.hGrid, id: \.self) { y in
                        Path { p in
                            p.move(to: CGPoint(x: rect.minX, y: y))
                            p.addLine(to: CGPoint(x: rect.maxX, y: y))
                        }
                        .stroke(.secondary.opacity(0.15), lineWidth: 1)
                    }

                    // Grid (vertical every 3h)
                    ForEach(model.vGrid, id: \.x) { tick in
                        Path { p in
                            p.move(to: CGPoint(x: tick.x, y: rect.minY))
                            p.addLine(to: CGPoint(x: tick.x, y: rect.maxY))
                        }
                        .stroke(.secondary.opacity(0.1), lineWidth: 1)
                    }

                    // Filled area under curve
                    if let line = model.smoothPath {
                        model.areaPath(from: line, in: rect)
                            .fill(LinearGradient(
                                stops: [.init(color: .teal.opacity(0.22), location: 0),
                                        .init(color: .teal.opacity(0.04), location: 1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    }

                    // Tide line
                    if let line = model.smoothPath {
                        line.stroke(.teal, lineWidth: 2)
                    }

                    // Current point dot
                    if let dot = model.currentPoint {
                        Circle()
                            .fill(Color.teal)
                            .frame(width: 8, height: 8)
                            .position(dot)
                        if let h = model.currentHeight {
                            Text(String(format: "%.1fm", h))
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.teal)
                                .position(x: min(rect.maxX - 10, dot.x + 22), y: max(rect.minY + 10, dot.y - 12))
                        }
                    }

                    // Right-side y-axis tick labels
                    ForEach(model.yTicks, id: \.y) { tick in
                        Text(tick.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(x: rect.maxX + 18, y: tick.y)
                    }

                    // Bottom hour labels
                    ForEach(model.vGrid, id: \.x) { tick in
                        Text(hourFmt.string(from: tick.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(x: tick.x, y: rect.maxY + 12)
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(height: 160)

            // Next 24 Hours extremes list
            if let extremes = nextExtremes(from: weatherService.dailyTideExtremes) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Next 24 Hours")
                            .font(.headline)
                    }
                    ForEach(extremes, id: \.time) { e in
                        HStack {
                            Image(systemName: e.isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(e.isHigh ? .blue : .red)
                            Text(e.time)
                                .frame(width: 56, alignment: .leading)
                            Text(e.isHigh ? "High" : "Low")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2fm", e.height))
                                .bold()
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.top, 2)
    }

    private func nextExtremes(from daily: [DailyTide]) -> [(time: String, isHigh: Bool, height: Double)]? {
        // Flatten next 24h extremes from DailyTide
        let now = Date()
        let fmtIn = DateFormatter(); fmtIn.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let fmtOut = DateFormatter(); fmtOut.dateFormat = "HH:mm"
        var items: [(Date, Bool, Double)] = []
        for d in daily {
            for h in d.highs { if let dt = fmtIn.date(from: String(h.time.prefix(16))) { items.append((dt, true, h.height)) } }
            for l in d.lows  { if let dt = fmtIn.date(from: String(l.time.prefix(16))) { items.append((dt, false, l.height)) } }
        }
        let next = items.filter { $0.0 >= now && $0.0 <= now.addingTimeInterval(24*3600) }
            .sorted { $0.0 < $1.0 }
            .prefix(4)
            .map { (fmtOut.string(from: $0.0), $0.1, abs($0.2)) }
        return next.isEmpty ? nil : Array(next)
    }
}

// MARK: - TideChartModel (layout + mapping)
private struct TideChartModel {
    struct VTick: Hashable { let x: CGFloat; let date: Date }

    let smoothPath: Path?
    let currentPoint: CGPoint?
    let currentHeight: Double?
    let hGrid: [CGFloat]
    let vGrid: [VTick]
    let debugLines: [String]
    struct YTick: Hashable { let y: CGFloat; let label: String }
    let yTicks: [YTick]

    init(samples: [(Date, Double)], spanHours: Int, endAtNow: Bool, rect: CGRect) {
        var dbg: [String] = []
        let now = Date()

        // 1) Choose the 24h window (centered around "now" to look like the screenshot)
        let start: Date
        let end: Date
        if endAtNow {
            end = now
            start = Calendar.current.date(byAdding: .hour, value: -spanHours, to: end) ?? now.addingTimeInterval(-86400)
        } else {
            start = Calendar.current.date(byAdding: .hour, value: -spanHours/2, to: now) ?? now.addingTimeInterval(-43200)
            end   = Calendar.current.date(byAdding: .hour, value:  spanHours/2, to: now) ?? now.addingTimeInterval(43200)
        }
        

        // 2) Sample/clip to window and ensure chronological order
        let windowed = samples
            .filter { $0.0 >= start && $0.0 <= end }
            .sorted { $0.0 < $1.0 }

        // If we don't have enough points, bail safely
        guard windowed.count >= 2, rect.width > 1, rect.height > 1 else {
            
            smoothPath = nil
            currentPoint = nil
            currentHeight = nil
            yTicks = []
            hGrid = []
            vGrid = []
            debugLines = dbg
            return
        }

        // 3) Nice y-range with padding and rounding to 0.1m
        // Use provider heights as-is (no abs), but display labels from 0 up
        let rawMin = windowed.map(\.1).min() ?? 0
        let rawMax = windowed.map(\.1).max() ?? 1
        let pad: Double = max(0.2, (rawMax - rawMin) * 0.15)
        // Compute natural range then clamp the displayed minimum to 0 so labels are non-negative
        let yMinNatural = floor((rawMin - pad) * 10) / 10
        let yMax = ceil((rawMax + pad) * 10) / 10
        let yMinDisplay = max(0, yMinNatural)
        let ySpanDisplay = max(0.1, yMax - yMinDisplay)
        

        func xPos(_ d: Date) -> CGFloat {
            CGFloat(d.timeIntervalSince(start) / end.timeIntervalSince(start)) * rect.width + rect.minX
        }
        func yPos(_ h: Double) -> CGFloat {
            let hc = min(max(h, yMinDisplay), yMax)
            return rect.maxY - CGFloat((hc - yMinDisplay) / ySpanDisplay) * rect.height
        }

        // 4) Build points and smooth path (Catmull–Rom to Bezier)
        let pts: [CGPoint] = windowed.map { CGPoint(x: xPos($0.0), y: yPos($0.1)) }
        
        smoothPath = Path.catmullRomSpline(through: pts, alpha: 0.5)

        // 5) Current closest sample → dot
        if let nearest = windowed.min(by: { abs($0.0.timeIntervalSince(now)) < abs($1.0.timeIntervalSince(now)) }) {
            currentPoint = CGPoint(x: xPos(nearest.0), y: yPos(nearest.1))
            currentHeight = nearest.1
            
        } else {
            currentPoint = nil
            currentHeight = nil
        }

        // 6) Grid + labels
        hGrid = stride(from: 0, through: 4, by: 1).map { i in
            rect.maxY - CGFloat(i) / 4 * rect.height
        }
        yTicks = (0...4).map { i in
            let ratio = CGFloat(i) / 4
            let y = rect.maxY - ratio * rect.height
            let value = yMinDisplay + Double(ratio) * ySpanDisplay
            return YTick(y: y, label: String(format: "%.1fm", max(0, value)))
        }

        // Vertical ticks every 3 hours, aligned to the previous whole 3-hour mark
        var v: [VTick] = []
        let cal = Calendar.current
        var tick = cal.nextDate(after: start, matching: DateComponents(minute: 0), matchingPolicy: .nextTime, direction: .forward) ?? start
        let hour = cal.component(.hour, from: tick)
        let adjust = hour % 3
        if adjust != 0 { tick = cal.date(byAdding: .hour, value: -adjust, to: tick) ?? tick }

        while tick <= end {
            v.append(.init(x: xPos(tick), date: tick))
            tick = cal.date(byAdding: .hour, value: 3, to: tick) ?? end.addingTimeInterval(1)
        }
        vGrid = v
        debugLines = dbg
    }

    /// Create a closed area under the line down to the bottom of the rect.
    func areaPath(from line: Path, in rect: CGRect) -> Path {
        var p = line
        if let last = line.currentPoint {
            p.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - Utils
private extension CGSize { var rect: CGRect { .init(origin: .zero, size: self) } }

// Smooth spline through points (Catmull–Rom → cubic Bézier)
private extension Path {
    static func catmullRomSpline(through points: [CGPoint], alpha: CGFloat = 0.5) -> Path {
        guard points.count > 1 else { return Path() }

        var p = Path()
        p.move(to: points[0])

        let n = points.count
        for i in 0 ..< n - 1 {
            let p0 = i == 0 ? points[i] : points[i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = (i + 2 < n) ? points[i + 2] : p2

            let d1 = hypot(p1.x - p0.x, p1.y - p0.y)
            let d2 = hypot(p2.x - p1.x, p2.y - p1.y)
            let d3 = hypot(p3.x - p2.x, p3.y - p2.y)

            let b1 = d1 > 0 ? (pow(d1, 2 * alpha)) : 0
            let b2 = d2 > 0 ? (pow(d2, 2 * alpha)) : 0
            let b3 = d3 > 0 ? (pow(d3, 2 * alpha)) : 0

            let c1x = p1.x + (b1 > 0 ? ( (p2.x - p0.x) * b2 / (b1 + b2) / 2 ) : 0)
            let c1y = p1.y + (b1 > 0 ? ( (p2.y - p0.y) * b2 / (b1 + b2) / 2 ) : 0)
            let c2x = p2.x - (b3 > 0 ? ( (p3.x - p1.x) * b2 / (b2 + b3) / 2 ) : 0)
            let c2y = p2.y - (b3 > 0 ? ( (p3.y - p1.y) * b2 / (b2 + b3) / 2 ) : 0)

            p.addCurve(to: p2, control1: CGPoint(x: c1x, y: c1y), control2: CGPoint(x: c2x, y: c2y))
        }
        return p
    }
}

