// PublicEmergencyView.swift
// Petpal - Public Emergency Profile View (What scanners see)

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct PublicEmergencyView: View {
    let profile: EmergencyProfile
    @State private var showingCallConfirmation = false
    
    private var systemBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.white
        #endif
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                alertBanner
                petInfoCard
                contactButtons
                if !profile.medications.isEmpty || !profile.allergies.isEmpty || !profile.medicalConditions.isEmpty {
                    medicalInfoCard
                }
                if !profile.vetName.isEmpty {
                    vetInfoCard
                }
                if !profile.feedingInstructions.isEmpty || !profile.specialNeeds.isEmpty {
                    careInstructionsCard
                }
                if !profile.microchipNumber.isEmpty {
                    microchipCard
                }
                petpalBranding
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color("BrandCream"), Color("BrandSoftBlue").opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    
    private var alertBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text(profile.lostPetMessage)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color("BrandDark"))
                .multilineTextAlignment(.center)
            
            if !profile.rewardOffered.isEmpty {
                Text("Reward: \(profile.rewardOffered)")
                    .font(.headline)
                    .foregroundStyle(Color("BrandOrange"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("BrandOrange").opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(systemBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 8)
    }
    
    private var petInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(Color("BrandOrange"))
                Text("Pet Information")
                    .font(.headline)
                    .foregroundStyle(Color("BrandDark"))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                PublicInfoRow(icon: "tag.fill", label: "Name", value: profile.petName)
                if !profile.ownerName.isEmpty {
                    PublicInfoRow(icon: "person.fill", label: "Owner", value: profile.ownerName)
                }
            }
        }
        .padding()
        .background(systemBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8)
    }
    
    private var contactButtons: some View {
        VStack(spacing: 12) {
            if !profile.ownerPhone.isEmpty {
                Link(destination: URL(string: "tel:\(profile.ownerPhone)")!) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Call Owner: \(profile.ownerPhone)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("BrandOrange"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            if !profile.ownerEmail.isEmpty {
                Link(destination: URL(string: "mailto:\(profile.ownerEmail)")!) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Email Owner")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("BrandBlue"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            if !profile.alternateContact.isEmpty {
                Text("Alternate: \(profile.alternateContact)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var medicalInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(.red)
                Text("MEDICAL INFORMATION")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if !profile.allergies.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("ALLERGIES", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                        Text(profile.allergies)
                            .font(.subheadline)
                            .foregroundStyle(Color("BrandDark"))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if !profile.medications.isEmpty {
                    DetailRow(icon: "pills.fill", label: "Medications", value: profile.medications, color: .blue)
                }
                
                if !profile.medicalConditions.isEmpty {
                    DetailRow(icon: "heart.text.square.fill", label: "Medical Conditions", value: profile.medicalConditions, color: .purple)
                }
            }
        }
        .padding()
        .background(systemBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.07), radius: 8)
    }
    
    private var vetInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "stethoscope")
                    .foregroundStyle(Color("BrandGreen"))
                Text("Veterinarian")
                    .font(.headline)
                    .foregroundStyle(Color("BrandDark"))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if !profile.vetName.isEmpty {
                    PublicInfoRow(icon: "building.2.fill", label: "Clinic", value: profile.vetName)
                }
                if !profile.vetPhone.isEmpty {
                    HStack {
                        PublicInfoRow(icon: "phone.fill", label: "Phone", value: profile.vetPhone)
                        Spacer()
                        Link(destination: URL(string: "tel:\(profile.vetPhone)")!) {
                            Image(systemName: "phone.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color("BrandGreen"))
                        }
                    }
                }
                if !profile.vetAddress.isEmpty {
                    PublicInfoRow(icon: "mappin.circle.fill", label: "Address", value: profile.vetAddress)
                }
            }
        }
        .padding()
        .background(systemBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8)
    }
    
    private var careInstructionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color("BrandPurple"))
                Text("Care Instructions")
                    .font(.headline)
                    .foregroundStyle(Color("BrandDark"))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if !profile.feedingInstructions.isEmpty {
                    DetailRow(icon: "fork.knife", label: "Feeding", value: profile.feedingInstructions)
                }
                if !profile.specialNeeds.isEmpty {
                    DetailRow(icon: "star.fill", label: "Special Needs", value: profile.specialNeeds)
                }
            }
        }
        .padding()
        .background(systemBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8)
    }
    
    private var microchipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(Color("BrandBlue"))
                Text("Microchip Number")
                    .font(.headline)
                    .foregroundStyle(Color("BrandDark"))
            }
            
            Text(profile.microchipNumber)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color("BrandDark"))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color("BrandBlue").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(systemBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8)
    }
    
    private var petpalBranding: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 8) {
                Text("🐾")
                    .font(.title2)
                Text("Powered by Petpal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandOrange"))
            }
            
            Text("Keep your pet safe with emergency QR tags")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Link(destination: URL(string: "https://apps.apple.com/app/petpal")!) {
                Text("Download Petpal on the App Store")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("BrandOrange"))
                    .clipShape(Capsule())
            }
            
            Text("Last updated: \(profile.lastUpdated.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(systemBackgroundColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PublicInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color("BrandBlue"))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color("BrandDark"))
            }
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = Color("BrandBlue")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label.uppercased(), systemImage: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color("BrandDark"))
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: EmergencyProfile.self, configurations: config)
    
    let profile = EmergencyProfile(
        petName: "Max",
        ownerName: "John Doe",
        ownerPhone: "(555) 123-4567",
        ownerEmail: "john@example.com",
        medications: "Apoquel 16mg twice daily",
        allergies: "Bee stings, peanuts",
        medicalConditions: "Mild arthritis",
        microchipNumber: "985112345678901",
        vetName: "Happy Paws Veterinary",
        vetPhone: "(555) 987-6543",
        feedingInstructions: "2 cups dry food twice daily",
        lostPetMessage: "I'm lost! Please call my owner ASAP!",
        rewardOffered: "$100"
    )
    
    return PublicEmergencyView(profile: profile)
        .modelContainer(container)
}
