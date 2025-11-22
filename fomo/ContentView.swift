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
                        Button(role: .destructive) {
                            modelContext.delete(item)
                            try? modelContext.save()
                        }
                        NavigationLink() {
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
                Text(formattedDuration(item.timerDuration))
            case .schedule:
                let from = item.scheduleWindow.start.formatted(.dateTime.hour().minute())
                let to = item.scheduleWindow.start.formatted(.dateTime.hour().minute())
                
                Text("\(from) - \(to)")
            case .limit:
                let freeTime = formattedDuration(item.limitConfig.freeTime)
                let breakTime = formattedDuration(item.limitConfig.breakTime)
                
                Text("Each \(freeTime) take a break of \(breakTime).")
            case .opens:
                let opens = item.opensConfig.opens
                let breakTime = formattedDuration(item.opensConfig.allowedPerOpen)
                
                Text("\(opens) opens of \(breakTime) minutes each")
            }
        }
    }
    
    private func formattedDuration(_ duration: Duration) -> String {
        let hour = item.timerDuration.hours.description.padding(toLength: 2, withPad: "0", startingAt: 0)
        let minute = item.timerDuration.minutes.description.padding(toLength: 2, withPad: "0", startingAt: 0)

        return "\(hour):\(minute)"
    }
}

struct EditItemView: View {
    @Bindable var item: Item
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var isNew: Bool { item.modelContext == nil }

    @State private var auth = ScreenTimeAuthorization()
    @State private var showAppPicker = false
    @State private var activitySelection: FamilyActivitySelection = .init()

    var body: some View {
        Form {
            TextField("Name", text: $item.name)

            Button("Blocked apps") {
                showAppPicker.toggle()
            }
            .familyActivityPicker(
                isPresented: $showAppPicker,
                selection: $activitySelection
            )
            .onChange(of: activitySelection) {
                item.apps = activitySelection.applicationTokens
            }

            Picker("Block mode", selection: $item.blockMode) {
                ForEach(BlockMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            switch item.blockMode {
            case .timer:
                EditTimerView(duration: $item.timerDuration)
            case .schedule:
                EditScheduleView(scheduleWindow: $item.scheduleWindow)
            case .limit:
                EditLimitView(limitConfig: $item.limitConfig)
            case .opens:
                EditOpensView(opensConfig: $item.opensConfig)
            }

            Picker("Break mode", selection: $item.breakMode) {
                ForEach(BreakMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Toggle("Repeat", isOn: $item.repeatOn)
            Toggle("Notifications", isOn: $item.notificationOn)
        }
        .navigationTitle(isNew ? "New item" : "Edit item")
        .onChange(of: item.repeatOn) {
            print(item.timerDuration)
        }

        Button("Save item") {
            if isNew {
                modelContext.insert(item)
            }
            
            try? modelContext.save()
            dismiss()
        }
        .disabled(!item.isValid)
    }
}

struct EditTimerView: View {
    @Binding var duration: Duration

    var body: some View {
        HStack {
            Text("Time:")
            Spacer()
            Picker("", selection: $duration.hours) {
                ForEach(0..<24) { n in
                    Text(n.description)
                }
            }
            .pickerStyle(.menu)
            Picker("", selection: $duration.minutes) {
                ForEach(0..<60) { n in
                    Text(n.description)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

struct EditScheduleView: View {
    @Binding var scheduleWindow: ScheduleWindow

    var body: some View {
        VStack(alignment: .leading) {
            DatePicker("From:", selection: $scheduleWindow.start)
            DatePicker("To:", selection: $scheduleWindow.end)
        }
    }
}

struct EditLimitView: View {
    @Binding var limitConfig: LimitConfig

    var body: some View {
        VStack(alignment: .leading) {
            Text("Free time")
            EditTimerView(duration: $limitConfig.freeTime)
            Text("Break time")
            EditTimerView(duration: $limitConfig.breakTime)
        }
    }
}

struct EditOpensView: View {
    @Binding var opensConfig: OpensConfig

    var body: some View {
        VStack(alignment: .leading) {
            Stepper(
                "Opens: \(opensConfig.opens)",
                value: $opensConfig.opens,
                in: 0...20
            )
            EditTimerView(duration: $opensConfig.allowedPerOpen)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true, onSetup: { result in
            guard case .success(let store) = result else { return }
            
            let items: [(String, BlockMode)] = [
                ("Foo", BlockMode.timer),
                ("Bar", BlockMode.schedule),
                ("Faz", BlockMode.limit),
                ("Baz", BlockMode.opens),
            ]
            
            for (name, mode) in items {
                let item = Item()
                item.name = name
                item.blockMode = mode

                store.mainContext.insert(item)
            }
        })
}
