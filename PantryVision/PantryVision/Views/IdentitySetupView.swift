import SwiftUI

struct IdentitySetupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String

    init() {
        _name = State(initialValue: PantryVisionIdentity.displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your name") {
                    TextField("e.g., Matt", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        PantryVisionIdentity.setDisplayName(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

