# 🎣 Rock Fisherman

A comprehensive iOS fishing weather app built with SwiftUI that provides real-time weather data and fishing condition analysis to help anglers plan their fishing trips.

## ✨ Features

### 🌤️ Weather Integration
- **Real-time weather data** from Open Meteo API
- **Current conditions** including temperature, humidity, wind, and precipitation
- **24-hour hourly forecast** for detailed planning
- **7-day daily forecast** for long-term trip planning
- **Automatic location detection** for personalized weather data

### 🎯 Fishing-Specific Features
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
- **URLSession** for network requests
- **Modular design** with separate services and view components

## 📁 Project Structure

```
Rock Fisherman/
├── Rock_FishermanApp.swift      # Main app entry point
├── ContentView.swift            # Main tab view and navigation
├── WeatherService.swift         # Open Meteo API integration
├── LocationManager.swift        # Location services and permissions
├── WeatherViews.swift           # Custom weather UI components
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
The app uses the free Open Meteo API which doesn't require authentication:
- Base URL: `https://api.open-meteo.com/v1/forecast`
- No API key required
- Rate limits: Generous for personal use

## 📊 Weather Data

### Current Conditions
- Temperature (current and feels like)
- Relative humidity
- Wind speed and direction
- Precipitation amount
- Weather code for conditions

### Forecast Data
- **Hourly**: 24-hour forecast with temperature, wind, and precipitation
- **Daily**: 7-day forecast with high/low temperatures and conditions

### Fishing Condition Algorithm
The app calculates fishing conditions based on:
- **Temperature**: Optimal range 10-25°C
- **Wind**: Optimal range 0-20 km/h
- **Precipitation**: Optimal range 0-5 mm

## 🎨 UI Components

### Custom Views
- `CurrentWeatherCard` - Main weather display
- `FishingConditionsIndicator` - Fishing condition scoring
- `HourlyForecastRow` - Hourly forecast items
- `DailyForecastRow` - Daily forecast items
- `FishingTipCard` - Educational fishing tips

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
- **Tide information** for coastal fishing
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

- **Open Meteo** for free weather API
- **Apple** for SwiftUI framework
- **Fishing community** for condition insights

---

**Happy Fishing! 🎣**

*Built with ❤️ using SwiftUI and Open Meteo*
