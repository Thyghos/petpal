// AddPetView.swift
// Petpal - Add Pet View

import SwiftUI
import SwiftData

struct AddPetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingPets: [Pet]
    
    @State private var name = ""
    /// Default to Dog so Save isn’t blocked when the species menu never commits `""` → option (iOS Form quirk).
    @State private var species = "Dog"
    @State private var breed = ""
    @State private var weight = ""
    @State private var weightUnit = "lbs"
    @State private var dateOfBirth: Date?
    @State private var showDatePicker = false
    
    let speciesOptions = ["Dog", "Cat", "Bird", "Rabbit", "Fish", "Reptile", "Other"]
    let weightUnits = ["lbs", "kg"]
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !species.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Pet Information") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                    
                    Picker("Species", selection: $species) {
                        ForEach(speciesOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    
                    TextField("Breed (Optional)", text: $breed)
                        .autocorrectionDisabled()
                }
                
                Section("Date of Birth") {
                    Toggle("Set Birth Date", isOn: $showDatePicker)
                    
                    if showDatePicker {
                        DatePicker(
                            "Birth Date",
                            selection: Binding(
                                get: { dateOfBirth ?? birthDatePickerFallback },
                                set: { dateOfBirth = $0 }
                            ),
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        
                        if let birthDate = dateOfBirth {
                            HStack {
                                Text("Age:")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatAge(from: birthDate))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                
                Section("Weight") {
                    HStack {
                        TextField("Weight", text: $weight)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        
                        Picker("Unit", selection: $weightUnit) {
                            ForEach(weightUnits, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }
            }
            .navigationTitle("Add Pet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePet()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: showDatePicker) { _, isOn in
                if isOn && dateOfBirth == nil {
                    dateOfBirth = birthDatePickerFallback
                }
            }
        }
    }
    
    /// Stable default for the picker (not “today”), so the binding never snaps back to the current month.
    private var birthDatePickerFallback: Date {
        Self.defaultBirthDateForPicker()
    }
    
    private static func defaultBirthDateForPicker() -> Date {
        let cal = Calendar.current
        let base = cal.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
    }
    
    private func savePet() {
        let weightValue = Double(weight) ?? 0.0
        
        let newPet = Pet(
            name: name.trimmingCharacters(in: .whitespaces),
            species: species,
            breed: breed.trimmingCharacters(in: .whitespaces),
            weight: weightValue,
            weightUnit: weightUnit,
            dateOfBirth: showDatePicker ? dateOfBirth : nil
        )
        
        modelContext.insert(newPet)
        for p in existingPets {
            p.isActive = false
        }
        newPet.isActive = true
        newPet.syncToLegacyAppStorage()
        try? modelContext.save()
        dismiss()
    }
    
    private func formatAge(from birthDate: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: birthDate, to: Date())
        
        var parts: [String] = []
        
        if let years = components.year, years > 0 {
            parts.append("\(years) year\(years == 1 ? "" : "s")")
        }
        
        if let months = components.month, months > 0 {
            parts.append("\(months) month\(months == 1 ? "" : "s")")
        }
        
        if parts.isEmpty {
            return "Less than a month"
        }
        
        return parts.joined(separator: ", ")
    }
}

#Preview {
    AddPetView()
        .modelContainer(for: Pet.self, inMemory: true)
}
