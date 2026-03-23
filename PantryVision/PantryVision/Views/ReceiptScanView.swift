import SwiftUI
import PhotosUI

struct ReceiptScanView: View {
    @EnvironmentObject private var groceryStore: GroceryListStore
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var matchedNames: [String] = []
    @State private var errorMessage: String?

    private let scanner = ReceiptScanService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt Photo") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose receipt", systemImage: "doc.text.viewfinder")
                    }
                    .disabled(isScanning)

                    Button {
                        Task { await scan() }
                    } label: {
                        if isScanning {
                            ProgressView()
                        } else {
                            Text("Scan Receipt")
                        }
                    }
                    .disabled(pickerItem == nil || isScanning)
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if !matchedNames.isEmpty {
                    Section("Updated purchases") {
                        ForEach(matchedNames, id: \.self) { name in
                            Text(name)
                        }
                    }
                } else if !isScanning {
                    Section {
                        Text("Tip: After scanning, matching grocery items will be marked as purchased.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Scan Receipt")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func scan() async {
        errorMessage = nil
        matchedNames = []
        isScanning = true
        defer { isScanning = false }

        do {
            guard let pickerItem else { return }
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else { return }
            guard let image = UIImage(data: data) else { return }

            let result = try await scanner.scanReceipt(image)
            let matched = groceryStore.markPurchasedFromReceiptCandidates(result.itemCandidates)
            matchedNames = matched
            if matched.isEmpty {
                errorMessage = "No matching items found in your grocery list yet."
            }
        } catch {
            errorMessage = "Receipt scan failed. Please try again."
        }
    }
}

