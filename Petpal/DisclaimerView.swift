// DisclaimerView.swift
// Petpal - Legal Disclaimers and Compliance

import SwiftUI

struct DisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Important Medical Disclaimer")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Please read carefully before using Petpal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    // Main Disclaimers
                    DisclaimerSection(
                        icon: "stethoscope",
                        title: "Not a Substitute for Veterinary Care",
                        color: .red
                    ) {
                        Text("Petpal is **not a replacement** for professional veterinary medical advice, diagnosis, or treatment. The AI assistant provides general information only and should not be used for medical emergencies or as a substitute for consultation with a licensed veterinarian.")
                    }
                    
                    DisclaimerSection(
                        icon: "exclamationmark.octagon.fill",
                        title: "Medical Emergencies",
                        color: .red
                    ) {
                        Text("**IF YOUR PET IS EXPERIENCING A MEDICAL EMERGENCY, CALL YOUR VETERINARIAN OR EMERGENCY ANIMAL HOSPITAL IMMEDIATELY.** Do not rely on this app for emergency situations.")
                    }
                    
                    DisclaimerSection(
                        icon: "brain.head.profile",
                        title: "AI Limitations",
                        color: .orange
                    ) {
                        Text("The AI assistant uses artificial intelligence which may produce inaccurate, incomplete, or outdated information. Always verify any health-related information with a qualified veterinarian before making decisions about your pet's care.")
                    }
                    
                    DisclaimerSection(
                        icon: "person.fill.checkmark",
                        title: "Professional Consultation Required",
                        color: .blue
                    ) {
                        Text("Always seek the advice of your veterinarian or other qualified animal health provider with any questions you may have regarding your pet's medical condition. Never disregard professional veterinary advice or delay in seeking it because of something you have read in this app.")
                    }
                    
                    DisclaimerSection(
                        icon: "shield.fill",
                        title: "No Liability",
                        color: .purple
                    ) {
                        Text("Petpal and its developers assume no liability for any decisions made based on information provided by this app. Use of this app is at your own risk.")
                    }
                    
                    DisclaimerSection(
                        icon: "doc.text.fill",
                        title: "Educational Purposes Only",
                        color: .green
                    ) {
                        Text("Information provided through Petpal is for educational and informational purposes only. It is not intended to be veterinary advice and should not be relied upon as such.")
                    }
                    
                    DisclaimerSection(
                        icon: "calendar",
                        title: "Medication and Treatment Reminders",
                        color: .indigo
                    ) {
                        Text("Reminder features are provided as a convenience only. We are not responsible if you miss a dose or appointment. Always follow your veterinarian's instructions and maintain your own records.")
                    }
                    
                    // Additional Legal Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Additional Information")
                            .font(.headline)
                            .padding(.top)
                        
                        Group {
                            InfoRow(
                                icon: "building.2",
                                text: "Petpal is not affiliated with any veterinary organization or medical institution."
                            )
                            
                            InfoRow(
                                icon: "globe",
                                text: "Information may not be applicable to all regions or jurisdictions."
                            )
                            
                            InfoRow(
                                icon: "checkmark.shield.fill",
                                text: "By using this app, you acknowledge that you have read and understood these disclaimers."
                            )
                        }
                    }
                    .padding(.vertical)
                }
                .padding(24)
            }
            .background(Color("BrandCream").opacity(0.3))
            .navigationTitle("Medical Disclaimer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("I Understand") {
                        hasAcceptedDisclaimer = true
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Disclaimer Section

struct DisclaimerSection<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 32)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("BrandDark"))
            }
            
            content
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    DisclaimerView()
}
