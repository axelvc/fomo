//
//  ContentView.swift
//  fomo
//
//  Created by Axel on 17/11/25.
//

import SwiftUI
import SwiftData
import FamilyControls

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
                        Text(item.name)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(name: "foo")
            modelContext.insert(newItem)
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

struct EditItemView: View {
    @Bindable var item: Item
    @State private var showAppPicker = false

    var body: some View {
        Form {
            TextField("Name", text: $item.name)
            
            Button("Blocked apps") {
                showAppPicker.toggle()
            }
            .familyActivityPicker(isPresented: $showAppPicker, selection: $item.apps)

            Picker("Block mode", selection: $item.blockMode) {
                ForEach(BlockMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            switch item.blockMode {
            case .timer(let duration):
                let durationBinding = Binding<Duration>(
                    get: { duration },
                    set: { item.blockMode = .timer($0) }
                )

                EditTimerView(duration: durationBinding)
            case .schedule(let scheduleWindow):
                let bindignScheduleWindow = Binding<ScheduleWindow>(
                    get: { scheduleWindow },
                    set: { item.blockMode = .schedule($0) }
                )

                EditScheduleView(scheduleWindow: bindignScheduleWindow)
            case .limit(let limitConfig):
                let bindignLimitConfig = Binding<LimitConfig>(
                    get: { limitConfig },
                    set: { item.blockMode = .limit($0) }
                )

                EditLimitView(limitConfig: bindignLimitConfig)
            case .opens(let opensConfig):
                let bindingOpensConfig = Binding<OpensConfig>(
                    get: { opensConfig },
                    set: { item.blockMode = .opens($0) }
                )
                
                EditOpensView(opensConfig: bindingOpensConfig)
            }

            Picker("Break mode", selection: $item.breakMode) {
                ForEach(BreakMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Toggle("Repeat", isOn: $item.repeatOn)
            Toggle("Notifications", isOn: $item.notificationOn)
        }
        .navigationTitle("Edit Item")
        .onChange(of: item.blockMode) {
            print(item.blockMode, item.apps)
        }
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
            Text("Focus time")
            EditTimerView(duration: $limitConfig.focus)
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
        .modelContainer(for: Item.self, inMemory: true)
}
