//
//  EditItem.swift
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

    let startDate = Date.now

    var body: some View {
        Form {
            if isNew {
                Picker("Block mode", selection: $item.blockMode) {
                    ForEach(BlockMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
            }

            Section {
                TextField("Blocker name (e.g. Work)", text: $item.name)

                CustomButton(
                    label: "Blocked apps",
                    icon: "apps.iphone",
                    action: { showAppPicker.toggle() }
                ) {
                    Text("\(item.activitySelection.applicationTokens.count) apps")
                }
                .familyActivityPicker(
                    isPresented: $showAppPicker,
                    selection: $item.activitySelection
                )
            }

            Section {
                switch item.blockMode {
                case .timer:
                    DurationPicker(
                        duration: $item.timerDuration,
                        label: "Duration",
                        icon: "timer"
                    )
                case .schedule:
                    SchedulePicker(scheduleWindow: $item.scheduleWindow)
                case .limit:
                    LimitPicker(limitConfig: $item.limitConfig)
                case .opens:
                    OpensPicker(opensConfig: $item.opensConfig)
                }
            }

            Section {
                Picker("Break mode", selection: $item.breakMode) {
                    ForEach(BreakMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }
        }.safeAreaInset(edge: .bottom) {
            Button(action: saveItem) {
                Text("Save item")
                    .font(.title3)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!item.isValid)
            .padding(.horizontal)
        }
        .navigationTitle(isNew ? "New item" : "Edit item")
    }

    func saveItem() {
        if !isNew {
            BlockController.shared.stopMonitoring(for: item)
        }

        modelContext.insert(item)
        try? modelContext.save()

        BlockController.shared.startMonitoring(for: item)
        dismiss()
    }
}

struct DurationPicker: View {
    @Binding var duration: TimeInterval
    var label: String
    var icon: String

    @State private var popupOn = false

    private var hours: Binding<Int> {
        Binding(
            get: { duration.hours },
            set: { duration = TimeInterval(hours: $0, minutes: duration.minutes) }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { duration.minutes },
            set: { duration = TimeInterval(hours: duration.hours, minutes: $0) }
        )
    }

    var body: some View {
        CustomButton(label: label, icon: icon, action: { popupOn.toggle() }) {
            if duration.hours > 0 {
                Text("\(duration.hours)h")
            }

            if duration.minutes > 0 || duration.hours == 0 {
                Text("\(duration.minutes)m")
            }
        }
        .popover(isPresented: $popupOn) {
            HStack(spacing: 0) {
                Picker("Hour", selection: hours) {
                    ForEach(0..<24) { n in
                        Text("\(n)")
                    }
                }
                .pickerStyle(.wheel)

                Text(":")

                Picker("Minute", selection: minutes) {
                    ForEach(0..<60) { n in
                        Text("\(n)")
                    }
                }
                .pickerStyle(.wheel)
            }
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
    }
}

struct SchedulePicker: View {
    @Binding var scheduleWindow: ScheduleWindow

    var body: some View {
        SchedulePickerButton(
            label: "From",
            icon: "calendar.badge.clock",
            date: $scheduleWindow.start,
        )
        SchedulePickerButton(
            label: "To",
            icon: "calendar",
            date: $scheduleWindow.end,
        )
    }

    private struct SchedulePickerButton: View {
        let label: String
        let icon: String
        @Binding var date: Date

        @State private var popupOn = false

        var body: some View {
            CustomButton(
                label: label,
                icon: icon,
                action: { popupOn.toggle() }
            ) {
                Text(date, style: .time)
            }
            .popover(isPresented: $popupOn) {
                DatePicker(
                    label,
                    selection: $date,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct LimitPicker: View {
    @Binding var limitConfig: LimitConfig

    var body: some View {
        DurationPicker(
            duration: $limitConfig.freeTime,
            label: "Free for",
            icon: "hourglass.bottomhalf.filled"
        )
        DurationPicker(
            duration: $limitConfig.breakTime,
            label: "Block for",
            icon: "lock.shield"
        )
    }
}

struct OpensPicker: View {
    @Binding var opensConfig: OpensConfig

    @State private var opensPopupOn = false
    @State private var durationPopupOn = false

    var body: some View {
        CustomButton(
            label: "Opens",
            icon: "number",
            action: { opensPopupOn.toggle() }
        ) {
            Text("\(opensConfig.opens)")
        }
        .popover(isPresented: $opensPopupOn) {
            HorizontalNumberPicker(
                selection: $opensConfig.opens,
                values: 0...20,
                label: "times"
            )
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }

        CustomButton(
            label: "Duration",
            icon: "timer",
            action: { durationPopupOn.toggle() }
        ) {
            Text("\(opensConfig.allowedPerOpen)m")
        }
        .popover(isPresented: $durationPopupOn) {
            HorizontalNumberPicker(
                selection: $opensConfig.allowedPerOpen,
                values: 0...60,
                label: "min"
            )
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
    }

    private struct HorizontalNumberPicker: View {
        @Binding var selection: Int
        var values: ClosedRange<Int>
        var label: String?

        @State private var scrollID: Int?
        private let itemWidth: CGFloat = 40

        var body: some View {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    labelView.hidden()

                    Text("\(selection)")
                        .font(.title)
                        .bold()
                        .contentTransition(.numericText())

                    labelView
                }

                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(values, id: \.self) { value in
                                VStack(spacing: 0) {
                                    Spacer()
                                    // Line
                                    Rectangle()
                                        .fill(
                                            value == selection
                                                ? Color.primary.opacity(1)
                                                : Color.secondary.opacity(
                                                    value.isMultiple(of: 5)
                                                        ? 1 : 0.5
                                                )
                                        )
                                        .frame(
                                            width: 8,
                                            height: value == selection
                                                ? 48
                                                : (value.isMultiple(of: 5)
                                                    ? 32 : 16)
                                        )
                                        .cornerRadius(2)
                                        .padding(.bottom, 4)
                                    // Label
                                    Text(value.description)
                                        .font(.caption)
                                        .foregroundColor(
                                            .secondary
                                        )
                                }
                                .frame(width: itemWidth)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        selection = value
                                    }
                                }
                                .id(value)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
                    .scrollPosition(id: $scrollID)
                    .safeAreaPadding(
                        .horizontal,
                        (geo.size.width - itemWidth) / 2
                    )
                    .sensoryFeedback(.selection, trigger: scrollID)
                    .onAppear {
                        scrollID = selection
                    }
                    .onChange(of: selection) {
                        withAnimation {
                            scrollID = selection
                        }
                    }
                    .onChange(of: scrollID) {
                        if let scrollID {
                            withAnimation {
                                selection = scrollID
                            }
                        }
                    }
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .white, .clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ).allowsHitTesting(false)
                    )
                    .overlay(
                        Rectangle()
                            .fill(.background.secondary)
                            .cornerRadius(.infinity)
                            .frame(width: 30, height: 80)
                            .offset(y: 5)
                    )
                }
                .frame(height: 80)
            }
        }

        @ViewBuilder
        private var labelView: some View {
            if let label {
                Text(label)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CustomButton<Content: View>: View {
    var label: String
    var icon: String
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(.gray.tertiary)
                    )
                Text(label)

                Spacer()

                Group {
                    content()
                    Image(systemName: "chevron.right").scaleEffect(0.8)
                }
                .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

}

#Preview {
    let item = Item()

    NavigationStack {
        EditItemView(item: item)
    }
}
