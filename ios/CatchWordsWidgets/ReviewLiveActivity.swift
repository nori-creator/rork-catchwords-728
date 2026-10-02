import ActivityKit
import WidgetKit
import SwiftUI

/// The review round on the Lock Screen and in the Dynamic Island (started by the app's review screen).
struct ReviewLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReviewActivityAttributes.self) { context in
            ReviewLockScreenView(state: context.state, lang: context.attributes.lang)
                .activityBackgroundTint(Color.white)
                .activitySystemActionForegroundColor(WidgetStyle.accent)
                .widgetURL(DeepLink.review)
        } dynamicIsland: { context in
            let s = context.state
            let lang = context.attributes.lang
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ProgressRing(progress: progress(s), lineWidth: 4)
                        .frame(width: 36, height: 36)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(s.done)/\(s.total)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(WidgetText.t(s.done >= s.total ? .liveDone : .reviewing, lang))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: Double(min(s.done, s.total)), total: Double(max(s.total, 1)))
                            .tint(WidgetStyle.accent)
                        HStack {
                            Text(WidgetText.t(.correct, lang, s.correct))
                            Spacer()
                            Text(WidgetText.t(.remaining, lang, max(0, s.total - s.done)))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                ProgressRing(progress: progress(s), lineWidth: 3)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                Text("\(s.done)/\(s.total)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WidgetStyle.accent)
            } minimal: {
                ProgressRing(progress: progress(s), lineWidth: 3)
                    .frame(width: 18, height: 18)
            }
            .widgetURL(DeepLink.review)
            .keylineTint(WidgetStyle.accent)
        }
    }
}

private func progress(_ s: ReviewActivityAttributes.ContentState) -> Double {
    s.total > 0 ? Double(min(s.done, s.total)) / Double(s.total) : 0
}

struct ReviewLockScreenView: View {
    let state: ReviewActivityAttributes.ContentState
    let lang: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: progress(state), lineWidth: 5)
                Image(systemName: state.done >= state.total ? "checkmark" : "rectangle.stack.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(WidgetStyle.accent)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(WidgetText.t(state.done >= state.total ? .liveDone : .reviewing, lang))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(WidgetStyle.ink)
                    Spacer()
                    Text("\(state.done)/\(state.total)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetStyle.accent)
                }
                ProgressView(value: Double(min(state.done, state.total)), total: Double(max(state.total, 1)))
                    .tint(WidgetStyle.accent)
                HStack {
                    Text(WidgetText.t(.correct, lang, state.correct))
                    Spacer()
                    if state.done < state.total {
                        Text(WidgetText.t(.remaining, lang, state.total - state.done))
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetStyle.subInk)
            }
        }
        .padding(16)
    }
}
