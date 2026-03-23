// EmergencyProfileEditor.swift
// Petpal - Emergency Profile Editor

import SwiftUI
import SwiftData

struct EmergencyProfileEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("petName") private var defaultPetName: String = "Your Pet"
    
    let profile: EmergencyProfile?
    
    @State private var petName: String = ""
    @State private var ownerName: String = ""
    @State private var ownerPhone: String = ""
    @State private var ownerEmail: String = ""
    @State private var alternateContact: String = ""
    @State private var medications: String = ""
    @State private var allergies: String = ""
    @State private var medicalConditions: String = ""
    @State private var microchipNumber: String = ""
    @State private var vetName: String = ""
    @State private var vetPhone: String = ""
    @State private var vetAddress: String = ""
    @State private var feedingInstructions: String = ""
    @State private var specialNeeds: String = ""
    @State private var lostPetMessage: String = "I'm lost! Please call my owner ASAP!"
    @State private var rewardOffered: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Pet Information") {
                    TextField("Pet Name", text: $petName)
                    TextField("Owner Name", text: $ownerName)
                }
                
                Section("Emergency Contact") {
                    TextField("Owner Phone", text: $ownerPhone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                    TextField("Owner Email", text: $ownerEmail)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        #endif
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Alternate Contact (Optional)", text: $alternateContact)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                }
                
                Section("Medical Information") {
                    TextField("Medications", text: $medications, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Allergies", text: $allergies, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Medical Conditions", text: $medicalConditions, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Veterinarian") {
                    TextField("Vet Clinic Name", text: $vetName)
                    TextField("Vet Phone", text: $vetPhone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                    TextField("Vet Address (Optional)", text: $vetAddress, axis: .vertical)
                        .lineLimit(2...3)
                }
                
                Section("Care Instructions") {
                    TextField("Feeding Instructions", text: $feedingInstructions, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Special Needs", text: $specialNeeds, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Identification") {
                    TextField("Microchip Number", text: $microchipNumber)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                
                Section("Lost Pet Message") {
                    TextField("Message to Finder", text: $lostPetMessage, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Reward Offered (Optional)", text: $rewardOffered)
                }
            }
            .navigationTitle(profile == nil ? "Create Profile" : "Edit Profile")
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
                        saveProfile()
                    }
                    .disabled(petName.isEmpty || ownerPhone.isEmpty)
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }
    
    private func loadProfile() {
        if let profile = profile {
            petName = profile.petName
            ownerName = profile.ownerName
            ownerPhone = profile.ownerPhone
            ownerEmail = profile.ownerEmail
            alternateContact = profile.alternateContact
            medications = profile.medications
            allergies = profile.allergies
            medicalConditions = profile.medicalConditions
            microchipNumber = profile.microchipNumber
            vetName = profile.vetName
            vetPhone = profile.vetPhone
            vetAddress = profile.vetAddress
            feedingInstructions = profile.feedingInstructions
            specialNeeds = profile.specialNeeds
            lostPetMessage = profile.lostPetMessage
            rewardOffered = profile.rewardOffered
        } else {
            // Set defaults for new profile
            petName = defaultPetName
        }
    }
    
    private func saveProfile() {
        if let existingProfile = profile {
            // Update existing profile
            if existingProfile.linkedPetId == nil, let aid = ActivePetStorage.activePetUUID {
                existingProfile.linkedPetId = aid
            }
            existingProfile.petName = petName
            existingProfile.ownerName = ownerName
            existingProfile.ownerPhone = ownerPhone
            existingProfile.ownerEmail = ownerEmail
            existingProfile.alternateContact = alternateContact
            existingProfile.medications = medications
            existingProfile.allergies = allergies
            existingProfile.medicalConditions = medicalConditions
            existingProfile.microchipNumber = microchipNumber
            existingProfile.vetName = vetName
            existingProfile.vetPhone = vetPhone
            existingProfile.vetAddress = vetAddress
            existingProfile.feedingInstructions = feedingInstructions
            existingProfile.specialNeeds = specialNeeds
            existingProfile.lostPetMessage = lostPetMessage
            existingProfile.rewardOffered = rewardOffered
            existingProfile.lastUpdated = Date()
        } else {
            // Create new profile
            let newProfile = EmergencyProfile(
                linkedPetId: ActivePetStorage.activePetUUID,
                petName: petName,
                ownerName: ownerName,
                ownerPhone: ownerPhone,
                ownerEmail: ownerEmail,
                alternateContact: alternateContact,
                medications: medications,
                allergies: allergies,
                medicalConditions: medicalConditions,
                microchipNumber: microchipNumber,
                vetName: vetName,
                vetPhone: vetPhone,
                vetAddress: vetAddress,
                feedingInstructions: feedingInstructions,
                specialNeeds: specialNeeds,
                lostPetMessage: lostPetMessage,
                rewardOffered: rewardOffered,
                isActive: true,
                lastUpdated: Date()
            )
            modelContext.insert(newProfile)
        }
        
        dismiss()
    }
}

#Preview {
    EmergencyProfileEditor(profile: nil)
        .modelContainer(for: EmergencyProfile.self, inMemory: true)
}
