# 🎣 Rock Fisherman

A comprehensive iOS fishing weather app built with SwiftUI that provides real-time weather data and fishing condition analysis to help anglers plan their fishing trips.

## ✨ Features

### 🌤️ Weather, Marine and Tide Integration
- **Real-time weather data** from Open‑Meteo
- **Marine data (waves)** from Open‑Meteo Marine (height, direction, period)
- **Tide times and heights** from WorldTides™ (heights + daily extremes)
- **Current conditions** including temperature, humidity, wind and precipitation
- **24‑hour hourly forecast** (aligned grid table)
- **7‑day forecast** including daily wave max and tide highs/lows
- **Automatic location detection** and robust country‑aware search

### 🎯 Fishing‑Specific Features
- **Fishing condition scoring** based on weather parameters
- **Optimal fishing indicators** for temperature, wind, and precipitation
- **Visual fishing status** with color-coded conditions (Excellent, Good, Fair, Poor)
- **Fishing tips and best practices** for different weather conditions

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
3. Build and run. The app will fetch hourly tide heights and daily extremes for the next 3 days.

Notes:
- We request `heights&extremes&date=today&days=3&lat=<lat>&lon=<lon>&key=<key>`.
- Times are rendered in local time; extremes populate daily High/Low values and times.
- WorldTides requires copyright reproduction; see their docs at `https://www.worldtides.info/apidocs`.

## 📊 Weather Data

### Current Conditions
- Temperature (current and feels like)
- Relative humidity
- Wind speed and direction
- Precipitation amount
- Weather code for conditions

### Forecast Data
- **Hourly**: 24‑hour forecast with temperature, wind, precipitation, wave height and tide height
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
- `FishingTipCard` – Educational fishing tips

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
