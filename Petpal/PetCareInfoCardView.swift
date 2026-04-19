// PetCareInfoCardView.swift
// Tall 1080×1920 shareable care-instructions card for ImageRenderer — fixed colors.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Non-interactive export layout for pet sitter / boarder instructions.
struct PetCareInfoCardView: View {
    let pet: Pet
    let instructions: PetSitterInstructions
    let emergencyProfile: EmergencyProfile?
    let medicationLines: [String]

    private let w: CGFloat = 1080
    private let h: CGFloat = 1920

    @Environment(\.displayScale) private var displayScale

    private var layoutScale: CGFloat { max(w / 1080, 0.001) }
    private func sz(_ p: CGFloat) -> CGFloat { p * layoutScale }

    private var primaryText: Color { Color(hex: "1A1A1A") }
    private var creamBg: Color { Color(hex: "FAFAF7") }

    private var petDisplayName: String {
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your Pet" : n
    }

    private var breedAgeLine: String? {
        let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let species = pet.species.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedPart = breed.isEmpty ? species : breed
        guard let birth = pet.dateOfBirth else {
            return breedPart.isEmpty ? nil : breedPart
        }
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month], from: cal.startOfDay(for: birth), to: cal.startOfDay(for: Date()))
        let y = c.year ?? 0
        let m = c.month ?? 0
        let age = y > 0 ? "\(y) yr\(y == 1 ? "" : "s")" : (m > 0 ? "\(m) mo" : "")
        if breedPart.isEmpty { return age.isEmpty ? nil : age }
        return age.isEmpty ? breedPart : "\(breedPart) · \(age)"
    }

    var body: some View {
        let _ = displayScale
        ZStack(alignment: .top) {
            creamBg

            VStack(alignment: .leading, spacing: 0) {
                careHeader

                VStack(alignment: .leading, spacing: sz(20)) {
                    sectionCard(title: "FEEDING") {
                        careLine("Food", value: joinNonEmpty(instructions.favoriteFood, instructions.foodAmount))
                        careLine("Schedule", value: nonEmpty(instructions.foodSchedule))
                        careLine("Add-ons", value: instructions.foodAddons)
                        careLine("Treats", value: joinNonEmpty(instructions.favoriteTreats, instructions.treatAmount))
                        careLine("Treat schedule", value: nonEmpty(instructions.treatSchedule))
                    }

                    sectionCard(title: "ROUTINE") {
                        careLine("Walk schedule", value: nonEmpty(instructions.walkSchedule))
                        careLine("Exercise / duration", value: nonEmpty(instructions.walkDuration))
                    }

                    sectionCard(title: "MEDICAL") {
                        if medicationLines.isEmpty {
                            Text("No medications in Edit Pet profile.")
                                .font(.system(size: sz(13)))
                                .foregroundStyle(Color(hex: "AAAAAA"))
                        } else {
                            ForEach(medicationLines, id: \.self) { line in
                                Text("• \(line)")
                                    .font(.system(size: sz(13), weight: .regular))
                                    .foregroundStyle(primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        careLine("Allergies", value: instructions.allergies)
                        careLine("Vet", value: joinNonEmpty(instructions.vetName, instructions.vetPhone))
                    }

                    sectionCard(title: "BEHAVIOR") {
                        VStack(alignment: .leading, spacing: sz(10)) {
                            if !pet.specialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                VStack(alignment: .leading, spacing: sz(4)) {
                                    Text("Special notes")
                                        .font(.system(size: sz(11), weight: .semibold))
                                        .foregroundStyle(Color(hex: "888888"))
                                    Text(pet.specialNotes)
                                        .font(.system(size: sz(13)))
                                        .foregroundStyle(primaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Text(nonEmpty(instructions.specialInstructions) ?? "—")
                                .font(.system(size: sz(13)))
                                .foregroundStyle(primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    sectionCard(title: "EMERGENCY") {
                        if let em = emergencyProfile {
                            careLine("Contact", value: joinNonEmpty(em.ownerName, em.ownerPhone))
                            careLine("Backup", value: nonEmpty(em.alternateContact))
                            careLine("Vet on record", value: joinNonEmpty(em.vetName, em.vetPhone))
                        } else {
                            Text("Add emergency contacts in the Emergency QR profile.")
                                .font(.system(size: sz(13)))
                                .foregroundStyle(Color(hex: "AAAAAA"))
                        }
                    }
                }
                .padding(.horizontal, sz(24))
                .padding(.top, sz(16))
                .padding(.bottom, sz(80))

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                careFooter
            }
            .frame(width: w, height: h)
        }
        .frame(width: w, height: h)
        .clipped()
    }

    private var careHeader: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [Color(hex: "E8622A"), Color(hex: "C0392B")],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: h * 0.14)

            HStack(alignment: .center, spacing: sz(18)) {
                petPhoto
                    .frame(width: sz(100), height: sz(100))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: sz(3)))
                    .padding(.leading, max(0, w * 0.22 - sz(50)))

                VStack(alignment: .leading, spacing: sz(6)) {
                    Text("\(petDisplayName)'s Care Instructions")
                        .font(.system(size: w * 0.042, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let b = breedAgeLine {
                        Text(b)
                            .font(.system(size: w * 0.026, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }
                Spacer(minLength: sz(16))
            }
            .padding(.trailing, sz(24))
        }
        .frame(height: h * 0.14)
    }

    @ViewBuilder
    private var petPhoto: some View {
        #if canImport(UIKit)
        if let d = pet.profileImage, !d.isEmpty, let ui = UIImage(data: d) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "E8622A"), Color(hex: "4A90D9")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
        }
        #else
        Color(hex: "4A90D9")
        #endif
    }

    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: sz(10)) {
            Text(title)
                .font(.system(size: sz(10), weight: .bold))
                .foregroundStyle(Color(hex: "E8622A"))
                .tracking(1)
            VStack(alignment: .leading, spacing: sz(8)) {
                content()
            }
            .padding(sz(14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: sz(12), style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: sz(8), x: 0, y: sz(2))
            )
        }
    }

    private func careLine(_ label: String, value: String?) -> some View {
        Group {
            if let v = value, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: sz(4)) {
                    Text(label.uppercased())
                        .font(.system(size: sz(10), weight: .semibold))
                        .foregroundStyle(Color(hex: "AAAAAA"))
                    Text(v)
                        .font(.system(size: sz(13), weight: .regular))
                        .foregroundStyle(primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var careFooter: some View {
        PetpalBrandMark(size: w * 0.040, style: .lightBackground)
            .padding(.horizontal, sz(12))
            .padding(.vertical, sz(8))
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: sz(4), x: 0, y: sz(2))
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, sz(24))
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    private func joinNonEmpty(_ a: String?, _ b: String?) -> String? {
        let x = a?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let y = b?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if x.isEmpty && y.isEmpty { return nil }
        if x.isEmpty { return y }
        if y.isEmpty { return x }
        return "\(x) · \(y)"
    }
}
