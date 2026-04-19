// AddPetView.swift
// Petpal - Add Pet View

import SwiftUI
import SwiftData
struct AddPetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingPets: [Pet]
    @ObservedObject private var pdfImportCoordinator = PDFImportCoordinator.shared
    
    @State private var name = ""
    /// Default to Dog so Save isn’t blocked when the species menu never commits `""` → option (iOS Form quirk).
    @State private var species = "Dog"
    @State private var breed = ""
    @State private var weight = ""
    @State private var weightUnit = "lbs"
    @State private var dateOfBirth: Date?
    @State private var showDatePicker = false
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var vetEmail = ""
    @State private var groomerName = ""
    @State private var groomerPhone = ""
    @State private var microchipNumber = ""
    @State private var microchipRegistry = ""
    
    let speciesOptions = ["Dog", "Cat", "Bird", "Rabbit", "Fish", "Reptile", "Other"]
    let weightUnits = ["lbs", "kg", "g"]
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !species.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                #if os(iOS)
                shelterImportBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                #endif
                Form {
                Section("Pet Information") {
                    TextField("Name", text: $name)
                        .foregroundColor(.black)
                        .tint(.black)
                        .autocorrectionDisabled()
                    
                    Picker("Species", selection: $species) {
                        ForEach(speciesOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    
                    TextField("Breed (Optional)", text: $breed)
                        .foregroundColor(.black)
                        .tint(.black)
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
                            .foregroundColor(.black)
                            .tint(.black)
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
                
                Section("Veterinarian (optional)") {
                    TextField("Vet name", text: $vetName)
                        .foregroundColor(.black)
                        .tint(.black)
                        .autocorrectionDisabled()
                    TextField("Vet phone", text: $vetPhone)
                        .foregroundColor(.black)
                        .tint(.black)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                        .autocorrectionDisabled()
                    TextField("Vet email", text: $vetEmail)
                        .foregroundColor(.black)
                        .tint(.black)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }
                
                Section("Groomer (optional)") {
                    TextField("Groomer name", text: $groomerName)
                        .foregroundColor(.black)
                        .tint(.black)
                        .autocorrectionDisabled()
                    TextField("Groomer phone", text: $groomerPhone)
                        .foregroundColor(.black)
                        .tint(.black)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                        .autocorrectionDisabled()
                }

                Section("Microchip (optional)") {
                    TextField("Microchip number", text: $microchipNumber)
                        .foregroundColor(.black)
                        .tint(.black)
                        .autocorrectionDisabled()
                    TextField("Registry (optional)", text: $microchipRegistry)
                        .foregroundColor(.black)
                        .tint(.black)
                        .autocorrectionDisabled()
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
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: .petpalDismissAddPetAfterShelterImport)) { _ in
                dismiss()
            }
            #endif
        }
    }

    #if os(iOS)
    private var shelterImportBanner: some View {
        Button {
            pdfImportCoordinator.showImportSourceOptionsShelterNewPet()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.title2)
                    .foregroundStyle(Color("BrandBlue"))
                    .frame(width: 44, height: 44)
                    .background(Color("BrandBlue").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("From a breeder or rescue?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("BrandDark"))
                    Text("Take a photo or import a PDF of your papers — we'll create your pet's profile automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color("BrandBlue").opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    #endif
    
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
            dateOfBirth: showDatePicker ? dateOfBirth : nil,
            vetName: vetName.trimmingCharacters(in: .whitespacesAndNewlines),
            vetPhone: vetPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            vetEmail: vetEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            groomerName: groomerName.trimmingCharacters(in: .whitespacesAndNewlines),
            groomerPhone: groomerPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            microchipNumber: microchipNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            microchipRegistry: microchipRegistry.trimmingCharacters(in: .whitespacesAndNewlines)
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
