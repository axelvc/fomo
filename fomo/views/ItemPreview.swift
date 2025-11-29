//
//  ItemPreview.swift
//  fomo
//
//  Created by Axel on 29/11/25.
//

import FamilyControls
import SwiftData
import SwiftUI

struct ItemPreview: View {
    @Bindable var item: Item

    @Environment(\.colorScheme) var colorScheme

    var background: Color {
        colorScheme == .dark
            ? Color(uiColor: .secondarySystemBackground)
            : Color(uiColor: .systemBackground)
    }

    var backgroundOpacity: Double { colorScheme == .dark ? 0.2 : 1 }
    var borderOpacity: Double { colorScheme == .dark ? 0.5 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: iconName)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14).fill(
                            Color(uiColor: .secondarySystemBackground))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("\(item.apps.count) Apps")
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: .infinity)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                }
            }

            Divider()
                .background(.background.secondary)

            HStack(spacing: 0) {
                switch item.blockMode {
                case .timer:
                    let duration = formattedDuration(item.timerDuration)

                    Text("Duration: \(duration)")
                case .schedule:
                    Text("Window: ")
                    Text(item.scheduleWindow.start, style: .time)
                    Text(" - ")
                    Text(item.scheduleWindow.end, style: .time)

                    Spacer()

                    ScheduleTimer(start: item.scheduleWindow.start, end: item.scheduleWindow.end)
                case .limit:
                    let free = formattedDuration(item.limitConfig.freeTime)
                    let blocked = formattedDuration(item.limitConfig.breakTime)

                    Text("Session: \(free) / \(blocked)")
                case .opens:
                    let opens = item.opensConfig.opens
                    let sessionTime = item.opensConfig.allowedPerOpen

                    Text("Opens: \(opens)/\(opens) | \(sessionTime) min")
                }
            }
            .monospaced()
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(background.opacity(backgroundOpacity))
                .stroke(
                    background.opacity(borderOpacity),
                    lineWidth: 1
                )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 4, leading: 4, bottom: 4, trailing: 4))
    }

    private var iconName: String {
        switch item.blockMode {
        case .timer: return "timer"
        case .schedule: return "calendar"
        case .limit: return "hourglass"
        case .opens: return "lock.open"
        }
    }

    private func formattedDuration(_ duration: Duration) -> String {
        let hour = duration.hours
        let minute = duration.minutes

        if hour == 0 {
            return "\(minute)m"
        }

        return "\(hour)h \(minute)m"
    }
}

struct ScheduleTimer: View {
    var start: Date
    var end: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date

            if now < start {
                let diff = start.timeIntervalSince(now)
                Text("Starts in \(formatInterval(diff))")
            } else if now < end {
                let diff = end.timeIntervalSince(now)
                Text("\(formatInterval(diff)) remaining")
            } else {
                Text("Ended")
            }
        }
    }

    func formatInterval(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    var timer = Item()
    var schedule = Item()
    var limit = Item()
    var opens = Item()

    List {
        ItemPreview(item: timer)
        ItemPreview(item: schedule)
        ItemPreview(item: limit)
        ItemPreview(item: opens)
    }
    .onAppear {
        timer.name = "Timer blocker"
        timer.blockMode = .timer
        timer.timerDuration = .init(hours: 0, minutes: 5)

        schedule.name = "Schedule blocker"
        schedule.blockMode = .schedule
        let date = Date.now.addingTimeInterval(30)
        schedule.scheduleWindow = .init(start: date, end: date.addingTimeInterval(60))

        limit.name = "Limit blocker"
        limit.blockMode = .limit
        limit.limitConfig = .init(
            freeTime: .init(hours: 0, minutes: 5), breakTime: .init(hours: 0, minutes: 8))

        opens.name = "Opens blocker"
        opens.blockMode = .opens
        opens.opensConfig = .init(opens: 5, allowedPerOpen: 60)
    }

}
