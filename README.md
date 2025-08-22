# 🎣 Rock Fisherman

A comprehensive iOS fishing weather app built with SwiftUI that provides real-time weather data and fishing condition analysis to help anglers plan their fishing trips.

## ✨ Features

### 🌤️ Weather, Marine and Tide Integration
- **Real-time weather data** from Open‑Meteo
- **Marine data (waves)** from Open‑Meteo Marine (height, direction, period)
- **Tide times and heights** from WorldTides™ (heights + daily extremes)
- **Current conditions** including temperature, humidity, wind and precipitation
- **48‑hour scrollable hourly forecast** with bold day headers (aligned grid: Time, Weather, Tide, Wind, Rain, Wave, Fish)
- **7‑day forecast** including daily wave max and tide highs/lows
- **Wind direction across views** using a 16‑point compass value (e.g., ENE)
- **Automatic location detection** and robust country‑aware search
- **Automatic foreground refresh**: when you return to the app, it requests a fresh location and reloads the latest weather, wave and tide data

### 🎯 Fishing‑Specific Features
- **Fishing condition scoring** based on weather parameters
- **Optimal fishing indicators** for temperature, wind, and precipitation
- **Visual fishing status** with color-coded conditions (Excellent, Good, Fair, Poor)
- **Fishing news & live catch reports** (last 30 days, locality‑aware for suburb/city/state) with 1‑hour caching (no external debug logging)

### 🗞️ Local News Relevance
- Builds query tokens from the selected place (suburb/city/state) and biases results to your area
- Filters out irrelevant articles (e.g., non‑NSW content for Sydney suburbs) with NSW/VIC heuristics
- Uses a strict filter first, then a relaxed NSW fallback if nothing is found
- Caps query tokens and page size to avoid timeouts; 10s request timeout

### 📱 Modern iOS Design
- **SwiftUI-based interface** following Apple's Human Interface Guidelines
- **Tab-based navigation** for easy access to different features
- **Responsive design** that works on all iPhone sizes
- **Dark mode support** with system-appropriate colors
- **Accessibility features** for inclusive user experience

## 🏗️ Architecture

The app follows modern iOS development patterns:

- **MVVM Architecture** with ObservableObject for state management
- **Async/await** for modern concurrency handling
- **Core Location** for location services
- **MapKit** (LocalSearch + Completer) for country‑aware location search with AU bias
- **Optimized concurrency**: weather, marine, and tide API calls run in parallel for faster loads
- **Combine** for debounced search
- **URLSession** for network requests
- **Modular design** with separate services and view components

## 📁 Project Structure

```
Rock Fisherman/
├── Rock_FishermanApp.swift      # Main app entry point
├── ContentView.swift            # Main tab view and navigation
├── WeatherService.swift         # Open Meteo API integration
├── LocationManager.swift        # Location services and permissions
├── WeatherViews.swift           # Custom weather + tide/wave UI components
├── LocationSearchService.swift  # Country‑aware search (MapKit + geocoder)
├── LocationSelectionView.swift  # Onboarding/location sheet
├── Info.plist                  # App permissions and configuration
└── Assets.xcassets/            # App icons and assets
```

## 🆕 What’s New in v1.1

- **Conditions header image refined**: location title now appears directly under the image with ~5pt spacing; header image limited to the Conditions page.
- **Location services cleanup**: removed synchronous authorization checks on the main thread; rely on `locationManagerDidChangeAuthorization` and dispatch `requestLocation()` off-main for responsiveness.
- **Stability fixes**: removed a duplicate `LocationManager` source file; addressed Codable/linter warnings (excluded auto-generated `id` from decoding, unused variables cleaned up).
- **Documentation**: README updated with header image setup and latest behavior.

## 🆕 What’s New in v1.2

- **Tides reliability**: Fetches daily extremes in small chunks (e.g., 3d + remaining) and aggregates to 7 days to reduce provider timeouts; hourly heights are fetched for 3 days in a single call.
- **Loading state**: Tide chart shows a dedicated spinner while tide data loads.
- **Coalescing**: Identical tide requests for the same lat/lon/day are coalesced so concurrent callers await one network call.
- **Key persistence**: WorldTides API key is persisted to Keychain on first run and read on cold starts.
- **Docs**: README updated to reflect chunked tide fetching, coalescing, and 7‑day coverage.
- **Performance**: Hourly tide heights limited to 3 days for faster, more reliable loads while daily extremes still cover 7 days.
- **Resilience**: Tide requests use timeouts (12s/15s) and up to 3 retries with exponential backoff.
- **Caching**: 10‑minute in‑memory cache keyed by rounded lat/lon/day serves data instantly after the app resumes; background fetch refreshes it.

## 🆕 What’s New in v1

- Automatic foreground refresh when returning to the app
- Hourly forecast extended to the next 48 hours and made scrollable
- Added wind direction column to hourly forecast and wind direction text to current conditions and daily forecast
- Renamed "High Tide" column to **"Tide"**
- Header image added to the top of the Conditions page, with the location title directly under the image
- Local news relevance greatly improved for suburbs and towns (includes broader city/state where appropriate)
- Location services responsiveness improvements and reduced main‑thread work
- Removed development debug logs

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Active Apple Developer account (for device testing)

### Installation
1. Clone or download the project
2. Open `Rock Fisherman.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run the project

### First Launch
1. The app will request location access permission
2. Grant location access to get personalized weather data
3. Weather data will automatically load for your current location
4. Use the tab navigation to explore different features

## 🔧 Configuration

### Location Permissions
The app requires location access to provide weather data. The following keys are configured in `Info.plist`:

- `NSLocationWhenInUseUsageDescription` - Location access for weather data
- `NSLocationAlwaysAndWhenInUseUsageDescription` - Location access for weather data

### API Configuration

Weather (Open‑Meteo)
- Base URL: `https://api.open-meteo.com/v1/forecast`
- No API key required

Marine (Open‑Meteo Marine)
- Base URL: `https://marine-api.open-meteo.com/v1/marine`
- No API key required

Tides (WorldTides™)
- Base URL: `https://www.worldtides.info/api/v3`
- Requires API key (see below)

Add your WorldTides key:
1. In Xcode, open your target `Info` tab (or edit `Info.plist`).
2. Add a String key named `WORLDTIDES_API_KEY` with your API key value.
3. Build and run. The app will fetch hourly tide heights and daily extremes for the next 7 days.
4. On first successful run, the key is securely persisted in the Keychain so it remains available after crashes or cold starts.

News & Catch Reports (NewsAPI.org)
- Base URL: `https://newsapi.org/v2/everything`
- Requires API key (see below)

Add your NewsAPI key (preferred: Scheme environment variable):
1. In Xcode, select Product → Scheme → Edit Scheme…
2. Select the Run action → Arguments tab.
3. Under Environment Variables, add:
   - Key: `YOUR_NEWSAPI_API_KEY`
   - Value: your NewsAPI key
4. Build and run. The app will load fishing news and catch reports for your selected location.

Optional fallback (if you prefer Info.plist):
1. Add a String key named `YOUR_NEWSAPI_API_KEY` with your API key value in `Info.plist`.
2. The app reads the environment variable first, then falls back to `Info.plist`.

Notes for NewsAPI:
- Results are limited to the last 30 days and sorted by publish date.
- Geographic radius filters aren’t available in NewsAPI; the app biases local results by including your selected place name tokens in the query and filters client‑side for relevance.
- Responses are cached per‑location for 1 hour to reduce API usage and improve performance.

Note: The previous Azure/Bing-powered news section has been removed while we evaluate alternative providers.

### Header Image (Conditions screen)
To show the header image at the top of the Conditions page:
1. In Xcode, open `Assets.xcassets` and add a new Image Set named `HeaderImage` (case sensitive).
2. Import a PNG or JPEG image into the 1x slot (2x/3x optional). Make sure the image looks good when cropped.
3. In the right‑hand pane, confirm Target Membership includes the app target.
4. In Attributes, set Appearances to "Any".
The app will automatically render this image and place the location title about 5pt below it.

### Performance & Logging
- All weather, wave and tide requests run concurrently to minimize total load time.
- Development-only debug logs have been removed for production builds to reduce console noise and improve performance.


- Notes:
- We request tide data in a robust way to handle slow provider responses:
  - Extremes are fetched in small chunks (e.g., 3 days + remaining) and aggregated to 7 days
  - Hourly heights are fetched for 3 days to keep responses fast and reliable
  - Requests use timeouts (12s/15s) and up to 3 retries with exponential backoff
  - A 10‑minute in‑memory cache (keyed by rounded lat/lon and day) serves data immediately after app resume while the network refresh updates it in the background
  - Times are rendered in local time; extremes populate daily High/Low values and times
- WorldTides requires copyright reproduction; see their docs at `https://www.worldtides.info/apidocs`.

## 📊 Weather Data

### Current Conditions
- Temperature (current and feels like)
- Relative humidity
- Wind speed and direction
- Precipitation amount
- Weather code for conditions

### Forecast Data
- **Hourly**: 48‑hour forecast (scrollable) with temperature, wind (with 16‑point direction), precipitation, wave height and tide height
- **Daily**: 7‑day forecast with min/max temperature, weather, wave height max, and tide high/low heights (with times)

### Fishing Condition Algorithm
The app calculates fishing conditions based on:
- **Temperature**: Optimal range 10-25°C
- **Wind**: Optimal range 0-20 km/h
- **Precipitation**: Optimal range 0-5 mm

## 🎨 UI Components

### Custom Views
- `TideChartView` – 24‑hour tide curve zoomed between previous and next extreme; current height labeled on left axis with grid and hour marks
- `CurrentWeatherView` – Main weather display and wave conditions
- `HourlyForecastView` – Single Grid with aligned columns (Time/Temp/Wind/Rain/Wave/Tide/Fish)
- `DailyForecastView` – 7‑day summary including wave and tide extremes
- `FishingNewsView` – Fishing news and catch reports near the selected location (with 1‑hour caching)

### Design Principles
- **Clarity**: Easy-to-read weather information
- **Efficiency**: Quick access to relevant data
- **Aesthetics**: Beautiful, modern interface
- **Accessibility**: Inclusive design for all users

## 🔄 State Management

The app uses SwiftUI's built-in state management:
- `@StateObject` for service objects
- `@ObservedObject` for view updates
- `@Published` properties for reactive updates
- Async/await for background operations

## 🌐 Network Layer

- **URLSession** for HTTP requests
- **Async/await** for modern concurrency
- **Error handling** with user-friendly messages
- **Automatic retry** functionality

## 📱 Supported Devices

- iPhone (all sizes)
- iOS 17.0 and later
- Portrait and landscape orientations
- Dark and light mode themes

## 🚧 Future Enhancements

Potential features for future versions:
- **Moon phase data** for fishing timing
- **Fishing spot recommendations**
- **Weather alerts** for severe conditions
- **Offline weather caching**
- **Widget support** for quick weather checks
- **Apple Watch companion app**

## 🤝 Contributing

This is a personal project, but suggestions and feedback are welcome!

## 📄 License

This project is for educational and personal use.

## 🙏 Acknowledgments

- **Open‑Meteo** for free weather and marine APIs
- **WorldTides™** for global tide predictions ([API docs](https://www.worldtides.info/apidocs))
- **Apple** for SwiftUI, MapKit, Core Location
- **Fishing community** for condition insights

---

**Happy Fishing! 🎣**

*Built with ❤️ using SwiftUI, Open‑Meteo and WorldTides™*
