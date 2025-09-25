//
//  Rockfisherman_WidgetLiveActivity.swift
//  Rockfisherman Widget
//
//  Created by Steven White on 25/09/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Rockfisherman_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Rockfisherman_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Rockfisherman_WidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension Rockfisherman_WidgetAttributes {
    fileprivate static var preview: Rockfisherman_WidgetAttributes {
        Rockfisherman_WidgetAttributes(name: "World")
    }
}

extension Rockfisherman_WidgetAttributes.ContentState {
    fileprivate static var smiley: Rockfisherman_WidgetAttributes.ContentState {
        Rockfisherman_WidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Rockfisherman_WidgetAttributes.ContentState {
         Rockfisherman_WidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Rockfisherman_WidgetAttributes.preview) {
   Rockfisherman_WidgetLiveActivity()
} contentStates: {
    Rockfisherman_WidgetAttributes.ContentState.smiley
    Rockfisherman_WidgetAttributes.ContentState.starEyes
}
