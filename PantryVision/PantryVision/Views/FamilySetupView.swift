import SwiftUI

struct FamilySetupView: View {
    @EnvironmentObject private var groceryStore: GroceryListStore
    @Environment(\.dismiss) private var dismiss

    @State private var familyCodeInput: String = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var createdFamilyCode: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Family") {
                    if let createdFamilyCode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Share this code with your spouse:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(createdFamilyCode)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                        }
                    }

                    TextField("Family code", text: $familyCodeInput)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: familyCodeInput) { newValue in
                            let upper = newValue.uppercased()
                            if newValue != upper {
                                familyCodeInput = upper
                            }
                        }
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await createFamily() }
                    } label: {
                        if isBusy {
                            ProgressView()
                        } else {
                            Text("Create Family (generates code)")
                        }
                    }
                    .disabled(isBusy)

                    Button {
                        Task { await joinFamily() }
                    } label: {
                        if isBusy {
                            ProgressView()
                        } else {
                            Text("Join Family")
                        }
                    }
                    .disabled(isBusy || familyCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Family Setup")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func createFamily() async {
        errorMessage = nil
        createdFamilyCode = nil
        isBusy = true
        defer { isBusy = false }

        do {
            let code = try await groceryStore.createFamily()
            createdFamilyCode = code
        } catch {
            errorMessage = "Could not create family. Check Cloud Functions config."
        }
    }

    private func joinFamily() async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try await groceryStore.joinFamily(familyCode: familyCodeInput)
            dismiss()
        } catch {
            errorMessage = "Could not join family. Check the code and config."
        }
    }
}

