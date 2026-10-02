import WidgetKit
import SwiftUI

/// 「復習」 — cards due now, on the Home Screen and the Lock Screen.
struct ReviewWidget: Widget {
    let kind = "ReviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CatchWordsProvider()) { entry in
            ReviewWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetText.t(.reviewName, WidgetText.currentLang))
        .description(WidgetText.t(.reviewDesc, WidgetText.currentLang))
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct ReviewWidgetView: View {
    let entry: CatchWordsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(DeepLink.review)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circular.containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            rectangular.containerBackground(for: .widget) { Color.clear }
        default:
            small.containerBackground(for: .widget) { Color.white }
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.due > 0 ? "rectangle.stack.fill" : "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(entry.due)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(4)
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(WidgetText.t(.reviewName, entry.lang), systemImage: "rectangle.stack.fill")
                .font(.system(size: 13, weight: .semibold))
                .widgetAccentable()
            Text(entry.due > 0 ? WidgetText.t(.remaining, entry.lang, entry.due) : WidgetText.t(.allDone, entry.lang))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let streak = entry.streak, streak > 0 {
                Text(WidgetText.t(.streak, entry.lang, streak))
                    .font(.system(size: 12))
                    .lineLimit(1)
            } else if entry.totalWords > 0 {
                Text(WidgetText.t(.wordsCaught, entry.lang, entry.totalWords))
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(WidgetText.t(.reviewName, entry.lang))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetStyle.accent)
                Spacer(minLength: 0)
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetStyle.accent)
            }
            Spacer(minLength: 0)
            if entry.due > 0 {
                Text("\(entry.due)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetStyle.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(WidgetText.t(.remaining, entry.lang, entry.due))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetStyle.subInk)
                    .lineLimit(1)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(WidgetStyle.accent)
                Text(WidgetText.t(.allDone, entry.lang))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetStyle.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if let streak = entry.streak, streak > 0 {
                    Label(WidgetText.t(.streak, entry.lang, streak), systemImage: "flame.fill")
                }
                if entry.totalWords > 0 {
                    Text(WidgetText.t(.wordsCaught, entry.lang, entry.totalWords))
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(WidgetStyle.subInk)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
