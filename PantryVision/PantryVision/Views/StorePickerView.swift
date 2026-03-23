import SwiftUI

struct StorePickerView: View {
    @EnvironmentObject private var groceryStore: GroceryListStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(GroceryStoreProfile.catalog) { store in
                    Button {
                        groceryStore.selectStore(store.id)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.displayName)
                                    .font(.body)
                                Text("Aisle hints via keywords (MVP)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if groceryStore.selectedStore.id == store.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Store")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

