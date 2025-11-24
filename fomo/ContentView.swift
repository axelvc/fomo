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

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true, onSetup: { result in
            guard case .success(let store) = result else { return }
            
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
