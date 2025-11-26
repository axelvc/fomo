//
//  EditItemView.swift
//  fomo
//
//  Created by Axel on 23/11/25.
//

import FamilyControls
import SwiftData
import SwiftUI

struct EditItemView: View {
    @Bindable var item: Item

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var isNew: Bool { item.modelContext == nil }

    @State private var auth = ScreenTimeAuthorization()
    @State private var showAppPicker = false
    @State private var activitySelection: FamilyActivitySelection = .init()

    var body: some View {
        VStack {

            if isNew {
                VStack {
                    Picker("Block mode", selection: $item.blockMode) {
                        ForEach(BlockMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }

            Form {
                Section {
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
                }

                Section {
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
                }

                Section {
                    Picker("Break mode", selection: $item.breakMode) {
                        ForEach(BreakMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
            }

            Button(action: saveItem) {
                Text("Save item")
                    .font(.title3)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .buttonStyle(.bordered)
            .disabled(!item.isValid)
        }
        .navigationTitle(isNew ? "New item" : "Edit item")
    }

    func saveItem() {
        if !isNew {
            BlockController.shared.stopMonitoring(for: item)
        }

        modelContext.insert(item)
        try? modelContext.save()

        item.block()
        dismiss()
    }
}

struct EditTimerView: View {
    @Binding var duration: Duration
    var label: String = "Time:"

    @State private var popupOn = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button("\(duration.hours):\(duration.minutes)", ) {
                popupOn.toggle()
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $popupOn) {
                HStack {
                    Picker("Hour", selection: $duration.hours) {
                        ForEach(0..<24) { n in
                            Text(n.description)
                        }
                    }
                    .pickerStyle(.wheel)

                    Text(":")

                    Picker("Minute", selection: $duration.minutes) {
                        ForEach(0..<60) { n in
                            Text(n.description)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct EditScheduleView: View {
    @Binding var scheduleWindow: ScheduleWindow

    var body: some View {
        VStack(alignment: .leading) {
            DatePicker(
                "From:", selection: $scheduleWindow.start, displayedComponents: .hourAndMinute)
            DatePicker("To:", selection: $scheduleWindow.end, displayedComponents: .hourAndMinute)
        }
    }
}

struct EditLimitView: View {
    @Binding var limitConfig: LimitConfig

    var body: some View {
        VStack(alignment: .leading) {
            EditTimerView(duration: $limitConfig.freeTime, label: "Free time:")
            EditTimerView(duration: $limitConfig.breakTime, label: "Break time:")
        }
    }
}

struct EditOpensView: View {
    @Binding var opensConfig: OpensConfig

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Opens:", selection: $opensConfig.opens) {
                ForEach(0...20, id: \.self) { n in
                    Text(n.description).tag(n)
                }
            }
            .pickerStyle(.menu)

            Picker("Duration:", selection: $opensConfig.allowedPerOpen) {
                ForEach(0...60, id: \.self) { n in
                    Text("\(n) min").tag(n)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

#Preview {
    let item = Item()

    NavigationStack {
        EditItemView(item: item)
    }
}
