//
//  ContentView.swift
//  fomo
//
//  Created by Axel on 17/11/25.
//

import FamilyControls
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        EditItemView(item: item)
                    } label: {
                        ItemPreview(item: item)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            modelContext.delete(item)
                            try? modelContext.save()
                        }
                        NavigationLink {
                            EditItemView(item: item)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    NavigationLink {
                        EditItemView(item: Item())
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }

            try! modelContext.save()
        }
    }
}

struct ItemPreview: View {
    @Bindable var item: Item

    var body: some View {
        VStack(alignment: .leading) {
            Text(item.name).font(.largeTitle)
            Text(item.blockMode.title).font(.subheadline)

            switch item.blockMode {
            case .timer:
                Capsule()
                    .fill(.gray.tertiary)
                    .frame(width: 65, height: 20)
                    .overlay {
                        DurationTimer(to: item.scheduleWindow.end).font(.caption)
                    }
            case .schedule:
                Capsule()
                    .fill(.gray.tertiary)
                    .frame(width: 85, height: 20)
                    .overlay {
                        let from = item.scheduleWindow.start.formatted(.dateTime.hour().minute())
                        let to = item.scheduleWindow.end.formatted(.dateTime.hour().minute())

                        Text("\(from) - \(to)").font(.caption)
                    }

                Capsule()
                    .fill(.gray.tertiary)
                    .frame(width: 135, height: 20)
                    .overlay {
                        CalendarTimer().font(.caption)
                    }
            case .limit:
                let freeTime = formattedDuration(item.limitConfig.freeTime)
                let breakTime = formattedDuration(item.limitConfig.breakTime)

                HStack {
                    Capsule()
                        .fill(.gray.tertiary)
                        .frame(width: 80, height: 20)
                        .overlay {
                            Text("\(freeTime) Limit")
                                .font(.caption)
                        }

                    Capsule()
                        .fill(.gray.tertiary)
                        .frame(width: 80, height: 20)
                        .overlay {
                            Text("\(breakTime) Break")
                                .font(.caption)
                        }
                }
            case .opens:
                let opens = item.opensConfig.opens
                let breakTime = item.opensConfig.allowedPerOpen

                HStack {
                    Capsule()
                        .fill(.gray.tertiary)
                        .frame(width: 70, height: 20)
                        .overlay {
                            Text("\(opens) Opens")
                                .font(.caption)
                        }

                    Capsule()
                        .fill(.gray.tertiary)
                        .frame(width: 50, height: 20)
                        .overlay {
                            Text("\(breakTime) min")
                                .font(.caption)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func DurationTimer(to: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, to.timeIntervalSince(context.date))

            Text(intervalToHMS(interval: remaining)).monospacedDigit()
        }
    }

    @ViewBuilder
    private func CalendarTimer() -> some View {
        let start = item.scheduleWindow.start
        let end = item.scheduleWindow.end

        TimelineView(.periodic(from: .now, by: 1)) { context in
            let isRunning = start < context.date && context.date < end
            let interval = max(0, (isRunning ? end : start).timeIntervalSince(context.date))

            HStack(spacing: 0) {
                Text(isRunning ? "Running: " : "Starting in: ")
                Text(intervalToHMS(interval: interval)).monospacedDigit()
            }
        }
    }

    private func intervalToHMS(interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        return String(format: "%01d:%02d:%02d", hours, minutes, seconds)
    }

    private func formattedDuration(_ duration: Duration) -> String {
        let hour = item.timerDuration.hours.description
        let minute = item.timerDuration.minutes.description.padding(
            toLength: 2, withPad: "0", startingAt: 0)

        return "\(hour):\(minute)"
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: Item.self, inMemory: true,
            onSetup: { result in
                guard case .success(let store) = result else { return }

                // let item = Item()
                // let date = Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 25, hour: 4, minute: 26))!
                // item.name = "Scheduled"
                // item.blockMode = .schedule
                // item.scheduleWindow = ScheduleWindow()
                // item.scheduleWindow.start = date
                // item.scheduleWindow.end = date.addingTimeInterval(TimeInterval(60 * 5))
                // store.mainContext.insert(item)

                let items: [(String, BlockMode)] = [
                    ("Timer", BlockMode.timer),
                    ("Schedule", BlockMode.schedule),
                    ("Limit", BlockMode.limit),
                    ("Opens", BlockMode.opens),
                ]

                for (name, mode) in items {
                    let item = Item()
                    item.name = name
                    item.blockMode = mode
                    store.mainContext.insert(item)
                }
            })
}
