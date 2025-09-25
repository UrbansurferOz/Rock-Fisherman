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
        VStack(spacing: 8) {
            TideMiniChart()
                .frame(height: 56)
            TideMiniExtremesRow()
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

private struct TideMiniChart: View {
    private let dfIn: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; return f }()
    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let (pts, ymin, ymax) = readSeries()
            ZStack {
                Path { p in
                    let grid = 3
                    for i in 0...grid {
                        let y = rect.minY + CGFloat(i) / CGFloat(grid) * rect.height
                        p.move(to: CGPoint(x: rect.minX, y: y))
                        p.addLine(to: CGPoint(x: rect.maxX, y: y))
                    }
                }.stroke(.secondary.opacity(0.12), lineWidth: 1)
                if pts.count >= 2 {
                    let path = Path { p in
                        for (i, s) in pts.enumerated() {
                            let x = rect.minX + CGFloat(s.t) * rect.width
                            let y = mapY(s.h, rect: rect, ymin: ymin, ymax: ymax)
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    path.stroke(.teal, lineWidth: 2)
                }
            }
        }
    }
    private func mapY(_ h: Double, rect: CGRect, ymin: Double, ymax: Double) -> CGFloat {
        let lo = ymin
        let hi = max(ymin + 0.1, ymax)
        let n = min(max((h - lo) / (hi - lo), 0), 1)
        return rect.maxY - CGFloat(n) * rect.height
    }
    private func readSeries() -> ([(t: Double, h: Double)], Double, Double) {
        let d = UserDefaults(suiteName: "group.UrbansuferOz.RockFisherman")
        let times = (d?.array(forKey: "tide24hTimes") as? [String]) ?? []
        let heights = (d?.array(forKey: "tide24hHeights") as? [Double]) ?? []
        guard times.count == heights.count, times.count >= 2 else { return ([], 0, 1) }
        let dates: [Date] = times.compactMap { dfIn.date(from: String($0.prefix(16))) }
        guard let start = dates.first, let end = dates.last, end > start else { return ([], 0, 1) }
        var pts: [(Double, Double)] = []
        for i in 0..<dates.count {
            let t = dates[i].timeIntervalSince(start) / end.timeIntervalSince(start)
            pts.append((t, heights[i]))
        }
        let ymin = heights.min() ?? 0
        let ymax = heights.max() ?? 1
        return (pts, ymin, ymax)
    }
}

private struct TideMiniExtremesRow: View {
    private let dfIn: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; return f }()
    private let dfOut: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    var body: some View {
        let d = UserDefaults(suiteName: "group.UrbansuferOz.RockFisherman")
        let times = (d?.array(forKey: "tide24hExtremeTimes") as? [String]) ?? []
        let isHigh = (d?.array(forKey: "tide24hExtremeIsHigh") as? [Int]) ?? []
        let heights = (d?.array(forKey: "tide24hExtremeHeights") as? [Double]) ?? []
        let n = min(times.count, min(isHigh.count, heights.count))
        return HStack(spacing: 8) {
            ForEach(0..<n, id: \.self) { i in
                let up = (isHigh[i] == 1)
                HStack(spacing: 4) {
                    Image(systemName: up ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                    Text(dfOut.string(from: dfIn.date(from: String(times[i].prefix(16))) ?? Date()))
                        .font(.caption2)
                    Text(String(format: "%.2fm", heights[i]))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview(as: .systemSmall) {
    Rockfisherman_Widget()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, nextHighTide: "12:34", height: 1.23)
    SimpleEntry(date: .now, configuration: .starEyes, nextHighTide: "18:45", height: 0.98)
}
