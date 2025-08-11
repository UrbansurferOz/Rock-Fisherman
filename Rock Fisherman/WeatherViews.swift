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

// MARK: - Hourly Forecast View (aligned)
struct HourlyForecastView: View {
    @ObservedObject var weatherService: WeatherService

    // Single source of truth for column widths (reduced to fit iPhone screens)
    private let colTime: CGFloat = 70
    private let colIcon: CGFloat = 20
    private let colTemp: CGFloat = 35
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

                    Text("") // icon column spacer
                        .frame(width: colIcon)

                    Text("Temp")
                        .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                        .frame(width: colTemp, alignment: .leading)

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

                    Text("Fish")
                        .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                        .frame(width: colFish, alignment: .leading)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color(.systemGray6))
                .cornerRadius(6)

                // Rows
                ForEach(next12HoursForecast, id: \.id) { f in
                    GridRow {
                        // Time
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.formattedTime)
                                .font(.caption).fontWeight(.medium)
                            Text(f.formattedRelativeTime)
                                .font(.caption2).foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: colTime, alignment: .leading)

                        // Icon
                        Image(systemName: weatherIcon(for: f.weatherCode))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: colIcon)

                        // Temp
                        Text("\(Int(round(f.temperature)))°")
                            .font(.caption).fontWeight(.medium)
                            .monospacedDigit()
                            .frame(width: colTemp, alignment: .leading)

                        // Inline Tide Height (if available)
                        if let tide = f.tideHeight {
                            Text(String(format: "%.1fm", tide))
                                .font(.caption2).foregroundColor(.secondary)
                        }

                        // Wind
                        HStack(spacing: 2) {
                            Image(systemName: "wind").font(.caption2).foregroundColor(.gray)
                            Text("\(Int(round(f.windSpeed)))")
                                .font(.caption2).monospacedDigit()
                        }
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
                            .frame(width: colFish)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 12)
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
                                
                                // Wave data
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

                                // Tide extremes
                if let hi = forecast.highTideHeight, let lo = forecast.lowTideHeight {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.caption)
                                            .foregroundColor(.teal)
                        if let th = forecast.highTideTime, let tl = forecast.lowTideTime {
                            Text("High: \(String(format: "%.1fm", hi)) (\(th))  Low: \(String(format: "%.1fm", lo)) (\(tl))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("High: \(String(format: "%.1fm", hi))  Low: \(String(format: "%.1fm", lo))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                                    }
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

// MARK: - Tide Chart View
struct TideChartView: View {
    @ObservedObject var weatherService: WeatherService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "water.waves.and.arrow.up")
                    .foregroundColor(.teal)
                Text("Tide and Wave")
                    .font(.headline)
                Spacer()
            }

            GeometryReader { geo in
                ZStack {
                    let plot = TidePlotData(service: weatherService, width: geo.size.width, height: geo.size.height)

                    // Tide curve (left axis) — smooth solid line
                    Path { path in
                        guard let first = plot.tidePoints.first else { return }
                        path.move(to: first)
                        for p in plot.tidePoints.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(Color.teal, lineWidth: 2)

                    // Current tide dot
                    if let dot = plot.currentTidePoint {
                        Circle().fill(Color.teal)
                            .frame(width: 8, height: 8)
                            .position(dot)
                    }

                    // Left axis current value marker aligned with dot
                    if let current = plot.currentTideHeight, let dot = plot.currentTidePoint {
                        Path { p in
                            p.move(to: CGPoint(x: 10, y: 4))
                            p.addLine(to: CGPoint(x: 10, y: geo.size.height - 4))
                        }
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1.2)

                        Text(String(format: "%.1fm", current))
                            .font(.footnote).bold()
                            .foregroundColor(.primary)
                            .padding(.horizontal, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                            .position(x: 36, y: dot.y)
                    }

                    // X-axis labels for previous and next extremes
                    if let prev = plot.prevLabelPoint {
                        VStack(spacing: 2) {
                            Circle().fill(Color.teal.opacity(0.8))
                                .frame(width: 5, height: 5)
                            Text(plot.prevLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .position(prev)
                    }
                    if let next = plot.nextLabelPoint {
                        VStack(spacing: 2) {
                            Circle().fill(Color.teal.opacity(0.8))
                                .frame(width: 5, height: 5)
                            Text(plot.nextLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .position(next)
                    }
                }
            }
            .frame(height: 140)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .clipped()
        }
        .padding()
    }
}

private struct TidePlotData {
    let tidePoints: [CGPoint]
    let currentTidePoint: CGPoint?
    let currentTideHeight: Double?
    let prevLabelPoint: CGPoint?
    let nextLabelPoint: CGPoint?
    let prevLabel: String
    let nextLabel: String

    init(service: WeatherService, width: CGFloat, height: CGFloat) {
        // Build a window centered on now between previous and next tide extreme
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        // Map hourly tide samples to points
        let samples = service.hourlyTide
        // Guard for empty
        guard !samples.isEmpty else {
            tidePoints = []; currentTidePoint = nil; currentTideHeight = nil; prevLabelPoint = nil; nextLabelPoint = nil; prevLabel = ""; nextLabel = ""; return
        }

        // Find previous and next extremes
        var extremes: [(Date, Double)] = []
        for d in service.dailyTideExtremes {
            for h in d.highs { if let dt = formatter.date(from: String(h.time.prefix(16))) { extremes.append((dt, h.height)) } }
            for l in d.lows { if let dt = formatter.date(from: String(l.time.prefix(16))) { extremes.append((dt, l.height)) } }
        }
        extremes.sort { $0.0 < $1.0 }
        let prev = extremes.last { $0.0 <= now }
        let next = extremes.first { $0.0 >= now && $0.0 != prev?.0 }

        // Time window from prev to next; fallback ±6h
        let startTime = prev?.0 ?? Calendar.current.date(byAdding: .hour, value: -6, to: now)!
        let endTime = next?.0 ?? Calendar.current.date(byAdding: .hour, value: 6, to: now)!

        // Filter samples within window
        let windowed: [(TideHeight, Date)] = samples.compactMap { s in
            guard let dt = formatter.date(from: s.time) else { return nil }
            guard dt >= startTime && dt <= endTime else { return nil }
            return (s, dt)
        }
        // Compute y range for tide from window
        let minTide = windowed.map { $0.0.height }.min() ?? 0
        let maxTide = windowed.map { $0.0.height }.max() ?? 2
        let tideRange = max(0.1, maxTide - minTide)

        // Compute y range for wave using hourly wave data aligned by time
        let waveHeights = service.hourlyWaveData.filter { hw in
            if let dt = formatter.date(from: hw.time) { return dt >= startTime && dt <= endTime }
            return false
        }
        let minWave = waveHeights.map { $0.waveHeight }.min() ?? 0
        let maxWave = waveHeights.map { $0.waveHeight }.max() ?? 2
        let waveRange = max(0.1, maxWave - minWave)

        // X mapping over the window
        let times: [Date] = windowed.map { $0.1 }
        guard let minTime = times.min(), let maxTime = times.max(), minTime < maxTime else {
            tidePoints = []; currentTidePoint = nil; currentTideHeight = nil; prevLabelPoint = nil; nextLabelPoint = nil; prevLabel = ""; nextLabel = ""; return
        }

        func x(for date: Date) -> CGFloat {
            let span = max(1, maxTime.timeIntervalSince(minTime))
            let ratio = (date.timeIntervalSince(minTime)) / span
            return CGFloat(ratio) * (width - 8) + 4
        }

        func yTide(for h: Double) -> CGFloat {
            let ratio = (h - minTide) / tideRange
            return height - CGFloat(ratio) * (height - 8) - 4
        }

        func yWave(for h: Double) -> CGFloat {
            let ratio = (h - minWave) / waveRange
            return height - CGFloat(ratio) * (height - 8) - 4
        }

        tidePoints = windowed.map { pair in
            CGPoint(x: x(for: pair.1), y: yTide(for: pair.0.height))
        }

        // Current dot
        if let nearest = windowed.min(by: { abs($0.1.timeIntervalSince(now)) < abs($1.1.timeIntervalSince(now)) }) {
            currentTideHeight = nearest.0.height
            currentTidePoint = CGPoint(x: x(for: nearest.1), y: yTide(for: nearest.0.height))
        } else {
            currentTidePoint = nil
            currentTideHeight = nil
        }

        // Extreme labels along X axis
        let timeLabelFmt = DateFormatter()
        timeLabelFmt.dateFormat = "HH:mm"
        if let p = prev?.0 {
            prevLabel = timeLabelFmt.string(from: p)
            prevLabelPoint = CGPoint(x: x(for: p), y: height - 10)
        } else {
            prevLabel = ""
            prevLabelPoint = nil
        }
        if let n = next?.0 {
            nextLabel = timeLabelFmt.string(from: n)
            nextLabelPoint = CGPoint(x: x(for: n), y: height - 10)
        } else {
            nextLabel = ""
            nextLabelPoint = nil
        }
    }
}

