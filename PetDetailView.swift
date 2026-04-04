// PetDetailView.swift
// Petpal - Pet Detail View

import SwiftUI
import SwiftData

struct PetDetailView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Pet Header
                    VStack(spacing: 16) {
                        Text(petEmoji(for: pet.species))
                            .font(.system(size: 80))
                        
                        Text(pet.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            Text(pet.species)
                            if !pet.breed.isEmpty {
                                Text("•")
                                Text(pet.breed)
                            }
                        }
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color("BrandCream"), Color("BrandSoftBlue").opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    // Pet Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Information")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            if let birthDate = pet.dateOfBirth {
                                infoRow(icon: "calendar", title: "Date of Birth", value: birthDate.formatted(date: .long, time: .omitted))
                                infoRow(icon: "clock", title: "Age", value: formatAge(from: birthDate))
                            }
                            
                            if pet.weight > 0 {
                                infoRow(icon: "scalemass", title: "Weight", value: "\(Int(pet.weight)) \(pet.weightUnit)")
                            }
                            
                            if !pet.vetName.isEmpty {
                                infoRow(icon: "stethoscope", title: "Veterinarian", value: pet.vetName)
                            }
                            if !pet.vetPhone.isEmpty {
                                PetProfilePhoneRow(title: "Vet phone", phone: pet.vetPhone)
                            }
                            if !pet.vetEmail.isEmpty {
                                PetProfileEmailRow(title: "Vet email", email: pet.vetEmail)
                            }
                            
                            if !pet.groomerName.isEmpty || !pet.groomerPhone.isEmpty {
                                if !pet.groomerName.isEmpty {
                                    infoRow(icon: "scissors", title: "Groomer", value: pet.groomerName)
                                }
                                if !pet.groomerPhone.isEmpty {
                                    infoRow(icon: "phone.fill", title: "Groomer phone", value: pet.groomerPhone)
                                }
                            }

                            if !pet.microchipNumber.isEmpty {
                                infoRow(icon: "dot.radiowaves.left.and.right", title: "Microchip", value: pet.microchipNumber)
                            }
                            if !pet.microchipRegistry.isEmpty {
                                infoRow(icon: "building.columns", title: "Microchip registry", value: pet.microchipRegistry)
                            }
                            
                            infoRow(icon: "plus.circle", title: "Added", value: pet.dateAdded.formatted(date: .long, time: .omitted))
                        }
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color("BrandCream"), Color("BrandSoftBlue")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle(pet.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditPetView(pet: pet)
            }
        }
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color("BrandOrange"))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
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
    
    private func petEmoji(for species: String) -> String {
        switch species.lowercased() {
        case "dog": return "🐕"
        case "cat": return "🐱"
        case "bird": return "🦜"
        case "rabbit": return "🐰"
        case "fish": return "🐠"
        case "reptile": return "🦎"
        default: return "🐾"
        }
    }
}

// MARK: - Edit Pet View
struct EditPetView: View {
    @Bindable var pet: Pet
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var species: String
    @State private var breed: String
    @State private var weight: String
    @State private var weightUnit: String
    @State private var dateOfBirth: Date?
    @State private var showDatePicker: Bool
    @State private var vetName: String
    @State private var vetPhone: String
    @State private var vetEmail: String
    @State private var groomerName: String
    @State private var groomerPhone: String
    @State private var microchipNumber: String
    @State private var microchipRegistry: String
    @State private var editingVetPhone = false
    @State private var editingVetEmail = false
    
    let speciesOptions = ["Dog", "Cat", "Bird", "Rabbit", "Fish", "Reptile", "Other"]
    let weightUnits = ["lbs", "kg", "g"]
    
    init(pet: Pet) {
        self.pet = pet
        _name = State(initialValue: pet.name)
        _species = State(initialValue: pet.species)
        _breed = State(initialValue: pet.breed)
        _weight = State(initialValue: pet.weight > 0 ? String(Int(pet.weight)) : "")
        _weightUnit = State(initialValue: pet.weightUnit)
        _dateOfBirth = State(initialValue: pet.dateOfBirth)
        _showDatePicker = State(initialValue: pet.dateOfBirth != nil)
        _vetName = State(initialValue: pet.vetName)
        _vetPhone = State(initialValue: pet.vetPhone)
        _vetEmail = State(initialValue: pet.vetEmail)
        _groomerName = State(initialValue: pet.groomerName)
        _groomerPhone = State(initialValue: pet.groomerPhone)
        _microchipNumber = State(initialValue: pet.microchipNumber)
        _microchipRegistry = State(initialValue: pet.microchipRegistry)
    }
    
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
                
                Section("Veterinarian (optional)") {
                    TextField("Vet name", text: $vetName)
                        .autocorrectionDisabled()
                    if vetPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Add vet phone") { editingVetPhone = true }
                    } else {
                        PetProfilePhoneRow(title: "Vet phone", phone: vetPhone)
                        HStack {
                            Button("Edit phone") { editingVetPhone = true }
                            Spacer()
                            Button("Remove", role: .destructive) { vetPhone = "" }
                        }
                        .font(.caption)
                    }
                    if vetEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Add vet email") { editingVetEmail = true }
                    } else {
                        PetProfileEmailRow(title: "Vet email", email: vetEmail)
                        HStack {
                            Button("Edit email") { editingVetEmail = true }
                            Spacer()
                            Button("Remove", role: .destructive) { vetEmail = "" }
                        }
                        .font(.caption)
                    }
                }
                
                Section("Groomer (optional)") {
                    TextField("Groomer name", text: $groomerName)
                        .autocorrectionDisabled()
                    TextField("Groomer phone", text: $groomerPhone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                        .autocorrectionDisabled()
                }

                Section("Microchip (optional)") {
                    TextField("Microchip number", text: $microchipNumber)
                        .autocorrectionDisabled()
                    TextField("Registry (optional)", text: $microchipRegistry)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Edit Pet")
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
            .sheet(isPresented: $editingVetPhone) {
                NavigationStack {
                    Form {
                        TextField("Vet phone", text: $vetPhone)
                            #if os(iOS)
                            .keyboardType(.phonePad)
                            #endif
                    }
                    .navigationTitle("Vet Phone")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { editingVetPhone = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $editingVetEmail) {
                NavigationStack {
                    Form {
                        TextField("Vet email", text: $vetEmail)
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    .navigationTitle("Vet Email")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { editingVetEmail = false }
                        }
                    }
                }
            }
        }
    }
    
    private var birthDatePickerFallback: Date {
        EditPetView.defaultBirthDateForPicker()
    }
    
    private static func defaultBirthDateForPicker() -> Date {
        let cal = Calendar.current
        let base = cal.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
    }
    
    private func savePet() {
        pet.name = name.trimmingCharacters(in: .whitespaces)
        pet.species = species
        pet.breed = breed.trimmingCharacters(in: .whitespaces)
        pet.weight = Double(weight) ?? 0.0
        pet.weightUnit = weightUnit
        pet.dateOfBirth = showDatePicker ? dateOfBirth : nil
        pet.vetName = vetName.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.vetPhone = vetPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.vetEmail = vetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.groomerName = groomerName.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.groomerPhone = groomerPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.microchipNumber = microchipNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.microchipRegistry = microchipRegistry.trimmingCharacters(in: .whitespacesAndNewlines)
        
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container: ModelContainer = try! ModelContainer(for: Pet.self, configurations: config)
    
    let samplePet = Pet(
        name: "Buddy",
        species: "Dog",
        breed: "Golden Retriever",
        weight: 65,
        dateOfBirth: Calendar.current.date(byAdding: .year, value: -3, to: Date())
    )
    container.mainContext.insert(samplePet)
    
    return PetDetailView(pet: samplePet)
        .modelContainer(container)
}
