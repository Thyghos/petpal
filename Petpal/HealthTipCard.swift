// HealthTipCard.swift
// Petpal - Health Tip of the Day/Week Card

import SwiftUI

struct HealthTipCard: View {
    let tip: HealthTip
    let frequency: TipFrequency
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color("BrandBlue").opacity(0.2), Color("BrandPurple").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: tip.icon)
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("BrandBlue"), Color("BrandPurple")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("💡 Health Tip")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(frequency.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color("BrandBlue").opacity(0.6))
                            .clipShape(Capsule())
                    }
                    
                    Text(tip.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color("BrandDark"))
                        .lineLimit(isExpanded ? nil : 1)
                }
            }
            
            // Tip Content
            Text(tip.tip)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            
            // Category Badge & Expand Button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                    Text(tip.category.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color("BrandOrange"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color("BrandOrange").opacity(0.15))
                .clipShape(Capsule())
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Read More")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color("BrandBlue"))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color("BrandBlue").opacity(0.3), Color("BrandPurple").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    HealthTipCard(
        tip: HealthTip(
            species: ["Dog"],
            title: "Daily Exercise",
            tip: "Most dogs need at least 30-60 minutes of exercise daily. Regular walks help maintain a healthy weight and mental stimulation.",
            icon: "figure.walk",
            category: .exercise
        ),
        frequency: .daily
    )
    .padding()
    .background(Color("BrandCream").opacity(0.3))
}
