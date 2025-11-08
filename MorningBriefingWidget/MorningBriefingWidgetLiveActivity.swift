//
//  MorningBriefingWidgetLiveActivity.swift
//  MorningBriefingWidget
//
//  Created by Belachew Tessema on 11/7/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MorningBriefingWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MorningBriefingWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MorningBriefingWidgetAttributes.self) { context in
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

extension MorningBriefingWidgetAttributes {
    fileprivate static var preview: MorningBriefingWidgetAttributes {
        MorningBriefingWidgetAttributes(name: "World")
    }
}

extension MorningBriefingWidgetAttributes.ContentState {
    fileprivate static var smiley: MorningBriefingWidgetAttributes.ContentState {
        MorningBriefingWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MorningBriefingWidgetAttributes.ContentState {
         MorningBriefingWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MorningBriefingWidgetAttributes.preview) {
   MorningBriefingWidgetLiveActivity()
} contentStates: {
    MorningBriefingWidgetAttributes.ContentState.smiley
    MorningBriefingWidgetAttributes.ContentState.starEyes
}
