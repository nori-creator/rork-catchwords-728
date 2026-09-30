import SwiftUI

/// Month calendar with photo days; tapping a day swaps to that day's timeline (swipe right returns).
struct DexCalendarView: View {
    @Environment(DexStore.self) private var dex
    let stickers: [Sticker]
    @Binding var selectedDay: Date?
    let onOpen: (Sticker) -> Void

    @State private var month: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var timelineDay: Date?

    private let cal = Calendar.current
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        Group {
            if let day = timelineDay {
                timeline(day)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                monthGrid
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: timelineDay)
    }

    private var monthGrid: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                Spacer()
                Text(month.formatted(.dateTime.year().month(.wide)))
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
            }
            .foregroundStyle(Theme.foreground)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                ForEach(Array(days().enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.aspectRatio(0.8, contentMode: .fit)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.card.opacity(0.7), in: .rect(cornerRadius: 22))
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width < -40 { shift(1) } else if v.translation.width > 40 { shift(-1) }
        })
    }

    private func dayCell(_ day: Date) -> some View {
        let items = stickers.filter { cal.isDate($0.takenAt, inSameDayAs: day) }
        let first = items.first
        let isToday = cal.isDateInToday(day)
        return Button {
            guard !items.isEmpty else { return }
            Haptics.selection()
            timelineDay = day
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Theme.surface2.opacity(items.isEmpty ? 0.25 : 0.6))
                if let first {
                    StickerImage(path: first.heroPath, url: dex.url(for: first.heroPath), contentMode: first.cutoutImageUrl != nil ? .fit : .fill)
                        .padding(first.cutoutImageUrl != nil ? 3 : 0)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(first.room.accent.opacity(0.8), lineWidth: 1.5))
                }
                Text("\(cal.component(.day, from: day))")
                    .font(AppFont.mono(10, weight: .bold))
                    .foregroundStyle(isToday ? Theme.primary : .white)
                    .padding(3)
                    .background(items.isEmpty ? .clear : .black.opacity(0.45), in: .rect(cornerRadius: 4))
                    .padding(3)
                if items.count > 1 {
                    Text("+\(items.count - 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Theme.primary, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(3)
                }
            }
            .aspectRatio(0.8, contentMode: .fit)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .disabled(items.isEmpty)
    }

    private func timeline(_ day: Date) -> some View {
        let items = stickers.filter { cal.isDate($0.takenAt, inSameDayAs: day) }.sorted { $0.takenAt < $1.takenAt }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { timelineDay = nil } label: {
                    Label("月に戻る", systemImage: "chevron.left").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.primary)
                .frame(minHeight: 44)
                Spacer()
                Text(day.formatted(.dateTime.month().day().weekday()))
                    .font(AppFont.hand(18)).foregroundStyle(Theme.foreground)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, s in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Text(s.takenAt.formatted(.dateTime.hour().minute()))
                            .font(AppFont.mono(12, weight: .semibold)).foregroundStyle(Theme.muted)
                        Rectangle().fill(Theme.border).frame(width: 1).frame(maxHeight: .infinity)
                    }
                    .frame(width: 48)
                    Button { onOpen(s) } label: {
                        HStack(spacing: 12) {
                            Color.clear.frame(width: 72, height: 72)
                                .overlay {
                                    StickerImage(path: s.heroPath, url: dex.url(for: s.heroPath), contentMode: s.cutoutImageUrl != nil ? .fit : .fill)
                                        .allowsHitTesting(false)
                                }
                                .background(Theme.surface2.opacity(0.5))
                                .clipShape(.rect(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.word?.headword ?? "").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.foreground)
                                Text(s.word?.meaningJa ?? "").font(.system(size: 13)).foregroundStyle(Theme.muted)
                                if let place = s.locationName {
                                    Label(place, systemImage: "mappin").font(.system(size: 11)).foregroundStyle(Theme.muted)
                                }
                                if let cap = s.caption, !cap.isEmpty {
                                    Text(cap).font(AppFont.hand(14)).foregroundStyle(Theme.foreground.opacity(0.8)).lineLimit(2)
                                }
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Theme.card, in: .rect(cornerRadius: 18))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.bottom, 12)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(idx) * 0.05), value: timelineDay)
            }
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width > 60 { timelineDay = nil }
        })
    }

    private func shift(_ delta: Int) {
        Haptics.selection()
        withAnimation(.snappy) { month = cal.date(byAdding: .month, value: delta, to: month) ?? month }
    }

    private func days() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: month) - 1
        var out: [Date?] = Array(repeating: nil, count: firstWeekday)
        for d in range {
            out.append(cal.date(byAdding: .day, value: d - 1, to: month))
        }
        return out
    }
}
