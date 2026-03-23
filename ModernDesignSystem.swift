// ModernDesignSystem.swift
// Petpal - Modern Design System & Components

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Glassmorphism Background

struct GlassmorphicBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: Double = 0.7
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Blur effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(opacity)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Modern Card Style

struct ModernCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var shadowRadius: CGFloat = 15
    var shadowY: CGFloat = 8
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: shadowRadius, x: 0, y: shadowY)
            )
    }
}

// MARK: - Haptic Feedback Manager

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func light() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    func medium() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    func heavy() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        #endif
    }
    
    func soft() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        #endif
    }
    
    func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    func warning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
    
    func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
    
    func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}

// MARK: - Smooth Button Style

struct SmoothButtonStyle: ButtonStyle {
    var color: Color = Color("BrandOrange")
    var haptic: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && haptic {
                    HapticManager.shared.light()
                }
            }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            action()
        }) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 64, height: 64)
                    .blur(radius: 8)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 6)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Modern Pill Button

struct ModernPillButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    init(title: String, icon: String? = nil, color: Color = Color("BrandOrange"), action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.callout)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 400
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func glassmorphic(cornerRadius: CGFloat = 20, opacity: Double = 0.7) -> some View {
        modifier(GlassmorphicBackground(cornerRadius: cornerRadius, opacity: opacity))
    }
    
    func modernCard(cornerRadius: CGFloat = 20, shadowRadius: CGFloat = 15, shadowY: CGFloat = 8) -> some View {
        modifier(ModernCard(cornerRadius: cornerRadius, shadowRadius: shadowRadius, shadowY: shadowY))
    }
    
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Modern Section Header

struct ModernSectionHeader: View {
    let title: String
    let icon: String?
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(_ title: String, icon: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("BrandOrange"), Color("BrandBlue")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("BrandDark"))
            }
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: {
                    HapticManager.shared.selection()
                    action()
                }) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(Color("BrandBlue"))
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Enhanced Feature Tile

struct EnhancedFeatureTile: View {
    let icon: String
    let title: String
    let gradient: [Color]
    var iconSize: CGFloat = 24
    var badge: Int? = nil
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            action()
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 14) {
                    // Icon with enhanced glassmorphism
                    ZStack {
                        // Glow effect
                        RoundedRectangle(cornerRadius: 16)
                            .fill(gradient[0].opacity(0.3))
                            .frame(width: 58, height: 58)
                            .blur(radius: 10)
                        
                        // Main icon background
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 54, height: 54)
                            .shadow(color: gradient[0].opacity(0.5), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: icon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    // Title with better spacing
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("BrandDark"))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 145)
                .background(
                    ZStack {
                        // Base white background
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.white)
                        
                        // Subtle gradient overlay
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        gradient[0].opacity(0.05),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    gradient[0].opacity(0.2),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                
                // Enhanced Badge
                if let count = badge, count > 0 {
                    ZStack {
                        Circle()
                            .fill(.red.opacity(0.3))
                            .frame(width: 26, height: 26)
                            .blur(radius: 4)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                        
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 10, y: -10)
                }
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ModernSectionHeader("Features", icon: "sparkles", actionTitle: "See All") {
            print("See all tapped")
        }
        
        HStack(spacing: 14) {
            EnhancedFeatureTile(
                icon: "airplane.departure",
                title: "Travel Mode",
                gradient: [Color("BrandOrange"), Color("BrandOrange").opacity(0.7)],
                badge: nil
            ) {
                print("Travel tapped")
            }
            
            EnhancedFeatureTile(
                icon: "bell.badge.fill",
                title: "Reminders",
                gradient: [Color("BrandPurple"), Color("BrandPurple").opacity(0.7)],
                badge: 3
            ) {
                print("Reminders tapped")
            }
        }
        
        ModernPillButton(title: "Get Started", icon: "arrow.right", color: Color("BrandOrange")) {
            print("Button tapped")
        }
        
        FloatingActionButton(icon: "plus", color: Color("BrandGreen")) {
            print("FAB tapped")
        }
    }
    .padding()
    .background(Color("BrandCream").opacity(0.3))
}
