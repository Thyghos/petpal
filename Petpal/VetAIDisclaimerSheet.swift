// VetAIDisclaimerSheet.swift
// Petpal - Vet AI Specific Disclaimer

import SwiftUI

struct VetAIDisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasAcceptedVetAIDisclaimer: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.2), Color.orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.top)
                    
                    VStack(spacing: 12) {
                        Text("Before You Continue")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Please read this important information about AI Vet Assistant")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Critical Warnings
                    VStack(spacing: 16) {
                        WarningCard(
                            icon: "cross.case.fill",
                            title: "NOT a Real Veterinarian",
                            description: "This AI assistant is NOT a licensed veterinarian and cannot diagnose, treat, or prescribe medication for your pet.",
                            severity: .critical
                        )
                        
                        WarningCard(
                            icon: "phone.fill.arrow.up.right",
                            title: "Emergencies: Call Your Vet",
                            description: "If your pet is experiencing an emergency (difficulty breathing, severe bleeding, seizures, collapse, etc.), contact your veterinarian or emergency animal hospital immediately. Do not use this app.",
                            severity: .critical
                        )
                        
                        WarningCard(
                            icon: "brain",
                            title: "AI Can Make Mistakes",
                            description: "Artificial intelligence can provide incorrect, incomplete, or outdated information. Always verify with a real veterinarian before making any health decisions.",
                            severity: .warning
                        )
                        
                        WarningCard(
                            icon: "person.fill.checkmark",
                            title: "Always Consult Your Vet",
                            description: "Use this tool for general pet care questions only. For any health concerns, symptoms, or medical advice, consult with a licensed veterinarian.",
                            severity: .info
                        )
                    }
                    
                    // What You Can Use It For
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Appropriate Uses")
                            .font(.headline)
                            .foregroundStyle(Color("BrandDark"))
                        
                        VStack(spacing: 12) {
                            AppropriateUseRow(icon: "book.fill", text: "General pet care questions")
                            AppropriateUseRow(icon: "fork.knife", text: "Basic nutrition information")
                            AppropriateUseRow(icon: "figure.walk", text: "Exercise recommendations")
                            AppropriateUseRow(icon: "pawprint.fill", text: "Breed characteristics")
                            AppropriateUseRow(icon: "info.circle.fill", text: "Pet behavior insights")
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.08))
                    )
                    
                    // Checkbox
                    VStack(spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: hasAcceptedVetAIDisclaimer ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundStyle(hasAcceptedVetAIDisclaimer ? Color("BrandGreen") : .secondary)
                                .onTapGesture {
                                    hasAcceptedVetAIDisclaimer.toggle()
                                }
                            
                            Text("I understand that this AI assistant is not a replacement for professional veterinary care and should only be used for general information.")
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(hasAcceptedVetAIDisclaimer ? Color("BrandGreen") : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Continue to AI Assistant")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: hasAcceptedVetAIDisclaimer ? 
                                            [Color("BrandGreen"), Color("BrandGreen").opacity(0.8)] :
                                            [Color.gray, Color.gray.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: hasAcceptedVetAIDisclaimer ? Color("BrandGreen").opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!hasAcceptedVetAIDisclaimer)
                    }
                }
                .padding(24)
            }
            .background(Color("BrandCream").opacity(0.3))
            .navigationTitle("AI Assistant Disclaimer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hasAcceptedVetAIDisclaimer = false
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(!hasAcceptedVetAIDisclaimer)
    }
}

// MARK: - Warning Card

struct WarningCard: View {
    let icon: String
    let title: String
    let description: String
    let severity: Severity
    
    enum Severity {
        case critical, warning, info
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(severity.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("BrandDark"))
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(severity.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(severity.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Appropriate Use Row

struct AppropriateUseRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(Color("BrandGreen"))
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    VetAIDisclaimerSheet(hasAcceptedVetAIDisclaimer: .constant(false))
}
