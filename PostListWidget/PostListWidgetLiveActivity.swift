//
//  PostListWidgetLiveActivity.swift
//  PostListWidget
//
//  Created by scy on 2025/9/22.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PostListWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

//struct PostListWidgetLiveActivity: Widget {
//    var body: some WidgetConfiguration {
//        ActivityConfiguration(for: PostListWidgetAttributes.self) { context in
//            // Lock screen/banner UI goes here
//            VStack {
//                Text("Hello \(context.state.emoji)")
//            }
//            .activityBackgroundTint(Color.cyan)
//            .activitySystemActionForegroundColor(Color.black)
//
//        } dynamicIsland: { context in
//            DynamicIsland {
//                // Expanded UI goes here.  Compose the expanded UI through
//                // various regions, like leading/trailing/center/bottom
//                DynamicIslandExpandedRegion(.leading) {
//                    Text("Leading")
//                }
//                DynamicIslandExpandedRegion(.trailing) {
//                    Text("Trailing")
//                }
//                DynamicIslandExpandedRegion(.bottom) {
//                    Text("Bottom \(context.state.emoji)")
//                    // more content
//                }
//            } compactLeading: {
//                Text("L")
//            } compactTrailing: {
//                Text("T \(context.state.emoji)")
//            } minimal: {
//                Text(context.state.emoji)
//            }
//            .widgetURL(URL(string: "http://www.apple.com"))
//            .keylineTint(Color.red)
//        }
//    }
//}

extension PostListWidgetAttributes {
    fileprivate static var preview: PostListWidgetAttributes {
        PostListWidgetAttributes(name: "World")
    }
}

extension PostListWidgetAttributes.ContentState {
    fileprivate static var smiley: PostListWidgetAttributes.ContentState {
        PostListWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PostListWidgetAttributes.ContentState {
         PostListWidgetAttributes.ContentState(emoji: "🤩")
     }
}

//#Preview("Notification", as: .content, using: PostListWidgetAttributes.preview) {
//   PostListWidgetLiveActivity()
//} contentStates: {
//    PostListWidgetAttributes.ContentState.smiley
//    PostListWidgetAttributes.ContentState.starEyes
//}
