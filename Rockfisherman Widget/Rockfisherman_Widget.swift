//
//  Rockfisherman_Widget.swift
//  Rockfisherman Widget
//
//  Created by Steven White on 25/09/2025.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), nextHighTide: "--:--", height: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let (timeStr, height) = nextHighTideFromAppGroup()
        return SimpleEntry(date: Date(), configuration: configuration, nextHighTide: timeStr, height: height)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let (timeStr, height) = nextHighTideFromAppGroup()
        let now = Date()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        let entry = SimpleEntry(date: now, configuration: configuration, nextHighTide: timeStr, height: height)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func nextHighTideFromAppGroup() -> (String, Double?) {
        let defaults = UserDefaults(suiteName: "group.UrbansuferOz.RockFisherman")
        let time = defaults?.string(forKey: "nextHighTideTime") ?? "--:--"
        let height = defaults?.object(forKey: "nextHighTideHeight") as? Double
        return (time, height)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let nextHighTide: String
    let height: Double?
}

struct Rockfisherman_WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.blue)
            Text("Next High Tide")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.nextHighTide)
                    .font(.headline)
                    .monospacedDigit()
                if let h = entry.height {
                    Text(String(format: "%.2fm", h))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct Rockfisherman_Widget: Widget {
    let kind: String = "Rockfisherman_Widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            Rockfisherman_WidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    Rockfisherman_Widget()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, nextHighTide: "12:34", height: 1.23)
    SimpleEntry(date: .now, configuration: .starEyes, nextHighTide: "18:45", height: 0.98)
}
