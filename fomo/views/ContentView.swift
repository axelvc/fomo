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
                    ItemPreview(item: item)
                        .overlay {
                            NavigationLink("Edit") {
                                EditItemView(item: item)
                            }
                            .opacity(0)
                        }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    NavigationLink(destination: EditItemView(item: Item())) {
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
                let item = items[index]

                BlockController.shared.stopMonitoring(for: item)
                modelContext.delete(item)
            }

            try! modelContext.save()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: Item.self, inMemory: true,
            onSetup: { result in
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
