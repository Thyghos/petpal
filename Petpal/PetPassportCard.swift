// PetPassportCard.swift
// Portrait shareable layout for ImageRenderer — 1080×1350 (4∶5), clear hierarchy for phone + export.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Passport data (Care Card uses **Edit Pet profile only** — no Health History, certificates, or reminders)

struct PassportData {
    var pet: Pet
}

// MARK: - Card

/// Non-interactive passport artboard. Default export size **1080×1350** points; pass `displayWidth` / `displayHeight` to scale metrics.
struct PetPassportCard: View {
    let data: PassportData
    var fieldSettings: CareCardFieldSettings = .defaults
    var displayWidth: CGFloat = 1080
    var displayHeight: CGFloat = 1350
    /// When set (e.g. Care Card preview), attachment thumbnails are tappable. Omit for export / `ImageRenderer`.
    var onAttachmentTap: ((PetAttachment) -> Void)? = nil

    private var layoutScale: CGFloat {
        max(displayWidth / 1080, 0.001)
    }

    private func ls(_ points: CGFloat) -> CGFloat { points * layoutScale }

    private var w: CGFloat { displayWidth }

    private var primaryText: Color { Color(hex: "1A1A1A") }
    private var detailGray: Color { Color(hex: "aaaaaa") }

    /// Manual vaccines from Edit Pet only, sorted for display.
    private var profileVaccinesSorted: [VaccineEntry] {
        data.pet.vaccinesArray.sorted { $0.dateAdministered > $1.dateAdministered }
    }

    /// Entries with a name; unnamed rows are omitted from the care card.
    private var profileVaccinesForDisplay: [VaccineEntry] {
        Array(
            profileVaccinesSorted
                .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .prefix(6)
        )
    }

    private var showsVaccinesBlock: Bool {
        fieldSettings.showVaccines && !profileVaccinesForDisplay.isEmpty
    }

    private var showsVetColumn: Bool {
        fieldSettings.showVetName || fieldSettings.showVetPhone || fieldSettings.showVetEmail
    }

    private var showsEmergencyContactColumn: Bool {
        let hasName = !data.pet.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPhone = !data.pet.emergencyContactNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (fieldSettings.showEmergencyName && hasName)
            || (fieldSettings.showEmergencyPhone && hasPhone)
    }

    private var profileMedicationsForDisplay: [MedicationEntry] {
        data.pet.medicationsArray
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var profileAttachmentsForDisplay: [PetAttachment] {
        data.pet.attachmentsArray.sorted { $0.dateAdded > $1.dateAdded }
    }

    /// Shown whenever the user enables attachments on the card (including empty, for export/layout consistency).
    private var showsAttachmentsSection: Bool {
        fieldSettings.showAttachments
    }

    /// Same ordering as `profileAttachmentsForDisplay` — explicit name for the attachment grid.
    private var sortedAttachments: [PetAttachment] {
        profileAttachmentsForDisplay
    }

    private func attachmentGridRow(_ atts: [PetAttachment], rowIndex: Int) -> [PetAttachment] {
        let start = rowIndex * 3
        guard start < atts.count else { return [] }
        return Array(atts[start..<min(start + 3, atts.count)])
    }

    private var specialNotesTrimmed: String {
        data.pet.specialNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showsSpecialNotesBlock: Bool {
        fieldSettings.showSpecialNotes && !specialNotesTrimmed.isEmpty
    }

    private var showsCareCardAttachmentImage: Bool {
        fieldSettings.showCareCardPhoto
            && data.pet.careCardAttachmentImageData.map { !$0.isEmpty } ?? false
    }

    /// Strip with warning (not the section below) — substantive allergy text only.
    private var showsAllergyStrip: Bool {
        guard fieldSettings.showAllergies else { return false }
        let t = allergiesDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let lower = t.lowercased()
        if lower == "none" || lower == "none known" { return false }
        return true
    }

    /// ALLERGIES section when the strip is not shown (same eligibility as before, minus strip).
    private var showsAllergiesSectionBelowGrid: Bool {
        guard fieldSettings.showAllergies, !showsAllergyStrip else { return false }
        let t = allergiesDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        return t.caseInsensitiveCompare("None known") != .orderedSame
    }

    private var showsNextVisitInfoRow: Bool {
        fieldSettings.showNextVetAppointment && data.pet.nextVetAppointmentDate != nil
    }

    private var microchipEffectivelyEmptyForSpayedRule: Bool {
        guard fieldSettings.showMicrochip else { return true }
        let v = microchipLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty || v == "Not on file"
    }

    private var showsSpayedInfoRow: Bool {
        guard fieldSettings.showSpayedNeutered else { return false }
        if spayedNeuteredDisplay.text == "Unknown", microchipEffectivelyEmptyForSpayedRule {
            return false
        }
        return true
    }

    private var showsInfoStack: Bool {
        showsVetColumn
            || showsEmergencyContactColumn
            || fieldSettings.showWeight
            || fieldSettings.showMicrochip
            || showsSpayedInfoRow
            || showsNextVisitInfoRow
    }

    private var hasBodySectionsAfterInfoStack: Bool {
        showsVaccinesBlock
            || (fieldSettings.showMedications && !medicationLinesEffective.isEmpty)
            || showsAllergiesSectionBelowGrid
            || showsSpecialNotesBlock
            || showsCareCardAttachmentImage
            || showsAttachmentsSection
    }

    /// Space above the footer chrome (line + watermark).
    private var footerTopPadding: CGFloat { ls(8) }

    var body: some View {
        passportContentColumn
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: w, alignment: .top)
            .background(Color.white)
    }

    /// Single vertical column; grows with content (no fixed card height). Parent scroll (e.g. Care Card) can also scroll the whole card.
    private var passportContentColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBlock

            if let line = breedSpeciesAgeSubtitle {
                breedSpeciesAgeStrip(text: line)
            }

            if showsAllergyStrip {
                allergyStripBlock
            }

            bodyContentStack

            footerSection
                .padding(.top, footerTopPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Body: 16pt horizontal / 10pt vertical insets; min 16pt from card edge at 1×.
    private var bodyContentStack: some View {
        VStack(alignment: .leading, spacing: ls(16)) {
            if showsInfoStack {
                infoStackedRows
            }

            if showsInfoStack && hasBodySectionsAfterInfoStack {
                thinDividerEEEEEE
            }

            if showsVaccinesBlock {
                vaccinesListSection
            }

            if fieldSettings.showMedications && !medicationLinesEffective.isEmpty {
                medicationsBlock
            }

            if showsAllergiesSectionBelowGrid {
                allergiesSection
            }

            if showsSpecialNotesBlock {
                specialNotesSection
            }

            if showsCareCardAttachmentImage {
                careCardAttachmentImageSection
            }

            if showsAttachmentsSection {
                attachmentsListSection
            }
        }
        .padding(.horizontal, ls(16))
        .padding(.vertical, ls(10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }

    private var allergyStripBlock: some View {
        HStack(alignment: .center, spacing: ls(8)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: ls(16), weight: .semibold))
            Text("Allergies: \(allergiesDisplay)")
                .font(.system(size: ls(14), weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(hex: "c0522a"))
        .padding(.horizontal, ls(14))
        .padding(.vertical, ls(8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "fffbf5"))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: "f5e0bb"))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }

    private var thinDividerEEEEEE: some View {
        Rectangle()
            .fill(Color(hex: "eeeeee"))
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
    }

    // MARK: Section 1 — Header (gradient band)

    private var headerBlock: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "F4845F"), Color(hex: "4A90D9")],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: ls(10)) {
                if fieldSettings.showPhoto {
                    Group {
                        photoOrPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: ls(60), height: ls(60))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: ls(2.5)))
                }

                if fieldSettings.showPetName {
                    Text(petDisplayName)
                        .font(.system(size: ls(24), weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: w * 0.92)
                }
            }
            .padding(.top, ls(16))
            .padding(.bottom, ls(16))
        }
        .frame(maxWidth: .infinity)
    }

    private var petDisplayName: String {
        let n = data.pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your Pet" : n
    }

    private func breedSpeciesAgeStrip(text: String) -> some View {
        Text(text)
            .font(.system(size: ls(16), weight: .medium, design: .rounded))
            .foregroundStyle(Color(hex: "6E6E6E"))
            .multilineTextAlignment(.center)
            .lineLimit(5)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, ls(16))
            .padding(.vertical, ls(10))
            .frame(maxWidth: .infinity)
            .background(Color(hex: "f2f2f2"))
    }

    // MARK: Info rows (single-line [Label — detail] stack)

    private var infoRowDividerLine: some View {
        Rectangle()
            .fill(Color(hex: "eeeeee"))
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
    }

    private var infoStackedRows: some View {
        VStack(spacing: 0) {
            if showsVetColumn {
                vetSingleLineRow
            }
            if dividerAfterVet {
                infoRowDividerLine
            }
            if showsEmergencyContactColumn {
                emergencySingleLineRow
            }
            if dividerAfterEmergency {
                infoRowDividerLine
            }
            if fieldSettings.showWeight {
                weightSingleLineRow
            }
            if dividerAfterWeight {
                infoRowDividerLine
            }
            if fieldSettings.showMicrochip {
                microchipSingleLineRow
            }
            if dividerAfterMicrochip {
                infoRowDividerLine
            }
            if showsSpayedInfoRow {
                spayedSingleLineRow
            }
            if dividerAfterSpayed {
                infoRowDividerLine
            }
            if showsNextVisitInfoRow, let d = data.pet.nextVetAppointmentDate {
                nextVisitSingleLineRow(date: d)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dividerAfterVet: Bool {
        showsVetColumn
            && (showsEmergencyContactColumn || fieldSettings.showWeight || fieldSettings.showMicrochip || showsSpayedInfoRow || showsNextVisitInfoRow)
    }

    private var dividerAfterEmergency: Bool {
        showsEmergencyContactColumn
            && (fieldSettings.showWeight || fieldSettings.showMicrochip || showsSpayedInfoRow || showsNextVisitInfoRow)
    }

    private var dividerAfterWeight: Bool {
        fieldSettings.showWeight && (fieldSettings.showMicrochip || showsSpayedInfoRow || showsNextVisitInfoRow)
    }

    private var dividerAfterMicrochip: Bool {
        fieldSettings.showMicrochip && (showsSpayedInfoRow || showsNextVisitInfoRow)
    }

    private var dividerAfterSpayed: Bool {
        showsSpayedInfoRow && showsNextVisitInfoRow
    }

    private var vetSingleLineRow: some View {
        dashSeparatedText(segments: vetLineSegments)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, ls(6))
            .padding(.leading, ls(10))
    }

    private var vetLineSegments: [(text: String, muted: Bool)] {
        var s: [(String, Bool)] = []
        if fieldSettings.showVetName { s.append((vetNameDisplay, vetNameMuted)) }
        if fieldSettings.showVetPhone { s.append((vetPhoneDisplay, vetPhoneMuted)) }
        if fieldSettings.showVetEmail { s.append((vetEmailDisplay, vetEmailMuted)) }
        return s
    }

    private var emergencySingleLineRow: some View {
        dashSeparatedText(segments: emergencyLineSegments)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, ls(6))
            .padding(.leading, ls(10))
    }

    private var emergencyLineSegments: [(text: String, muted: Bool)] {
        var s: [(String, Bool)] = []
        if fieldSettings.showEmergencyName { s.append((emergencyNameDisplay, emergencyNameMuted)) }
        if fieldSettings.showEmergencyPhone { s.append((emergencyPhoneDisplay, emergencyPhoneMuted)) }
        return s
    }

    /// First segment medium (primary when not muted); em dashes and following segments #aaaaaa regular — wraps as one flow.
    private func dashSeparatedText(segments: [(text: String, muted: Bool)]) -> Text {
        Text(dashSeparatedAttributed(segments: segments))
    }

    private func dashSeparatedAttributed(segments: [(text: String, muted: Bool)]) -> AttributedString {
        guard let firstSeg = segments.first else { return AttributedString("") }
        var combined = AttributedString()
        var firstRun = AttributedString(firstSeg.text)
        firstRun.font = .system(size: ls(15), weight: .medium, design: .rounded)
        firstRun.foregroundColor = firstSeg.muted ? detailGray : primaryText
        combined.append(firstRun)
        for i in 1..<segments.count {
            var sep = AttributedString(" — ")
            sep.font = .system(size: ls(15), weight: .regular, design: .rounded)
            sep.foregroundColor = detailGray
            combined.append(sep)
            var part = AttributedString(segments[i].text)
            part.font = .system(size: ls(15), weight: .regular, design: .rounded)
            part.foregroundColor = detailGray
            combined.append(part)
        }
        return combined
    }

    private func vaccineNameDateAttributed(name: String, dateString: String) -> AttributedString {
        var combined = AttributedString()
        var nameRun = AttributedString(name)
        nameRun.font = .system(size: ls(15), weight: .medium, design: .rounded)
        nameRun.foregroundColor = primaryText
        combined.append(nameRun)
        var sep = AttributedString(" — ")
        sep.font = .system(size: ls(15), weight: .regular, design: .rounded)
        sep.foregroundColor = detailGray
        combined.append(sep)
        var dateRun = AttributedString(dateString)
        dateRun.font = .system(size: ls(15), weight: .regular, design: .rounded)
        dateRun.foregroundColor = detailGray
        combined.append(dateRun)
        return combined
    }

    private var weightSingleLineRow: some View {
        let v = weightLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = v.isEmpty ? "—" : v
        return HStack(alignment: .firstTextBaseline, spacing: ls(4)) {
            Text("Weight")
                .font(.system(size: ls(15), weight: .medium, design: .rounded))
                .foregroundStyle(detailGray)
                .textCase(.uppercase)
            Text("—")
                .font(.system(size: ls(15), weight: .regular, design: .rounded))
                .foregroundStyle(detailGray)
            Text(value)
                .font(.system(size: ls(15), weight: .regular, design: .rounded))
                .foregroundStyle(detailGray)
            Spacer(minLength: 0)
        }
        .padding(.vertical, ls(6))
        .padding(.leading, ls(10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var microchipSingleLineRow: some View {
        let raw = microchipLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = raw.isEmpty ? "—" : raw
        return HStack(alignment: .firstTextBaseline, spacing: ls(4)) {
            Text("Microchip")
                .font(.system(size: ls(15), weight: .medium, design: .rounded))
                .foregroundStyle(detailGray)
            Text("—")
                .font(.system(size: ls(15), weight: .regular, design: .rounded))
                .foregroundStyle(detailGray)
            Text(display)
                .font(.system(size: ls(15), weight: .regular, design: .rounded))
                .foregroundStyle(detailGray)
            Spacer(minLength: 0)
        }
        .padding(.vertical, ls(6))
        .padding(.leading, ls(10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spayedSingleLineRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: ls(4)) {
            Text("Spayed")
                .font(.system(size: ls(15), weight: .medium, design: .rounded))
                .foregroundStyle(detailGray)
            Text("—")
                .font(.system(size: ls(15), weight: .regular, design: .rounded))
                .foregroundStyle(detailGray)
            Text(spayedNeuteredDisplay.text)
                .font(.system(size: ls(15), weight: .regular, design: .rounded))
                .foregroundStyle(detailGray)
            Spacer(minLength: 0)
        }
        .padding(.vertical, ls(6))
        .padding(.leading, ls(10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nextVisitSingleLineRow(date: Date) -> some View {
        let formatted = date.formatted(date: .abbreviated, time: .omitted)
        return HStack(alignment: .firstTextBaseline, spacing: ls(4)) {
            Text("Next Visit")
                .font(.system(size: ls(15), weight: .medium, design: .rounded))
                .foregroundStyle(detailGray)
            Text("—")
                .font(.system(size: ls(15), weight: .regular, design: .rounded))
                .foregroundStyle(detailGray)
            Text(formatted)
                .font(.system(size: ls(15), weight: .regular, design: .rounded))
                .foregroundStyle(detailGray)
            Spacer(minLength: 0)
        }
        .padding(.vertical, ls(6))
        .padding(.leading, ls(10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vetNameMuted: Bool { vetNameIsPlaceholder }
    private var vetPhoneMuted: Bool { vetPhoneIsPlaceholder }
    private var vetEmailMuted: Bool { vetEmailIsPlaceholder }
    private var emergencyNameMuted: Bool { emergencyNameIsPlaceholder }
    private var emergencyPhoneMuted: Bool { emergencyPhoneIsPlaceholder }

    // MARK: Section — Vaccines (manual Edit Pet entries only)

    private func sectionAccentTitle(_ title: String) -> some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color(hex: "F4845F"))
                .frame(width: ls(3), height: ls(20))
            Text(title)
                .font(.system(size: ls(12), weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "F4845F"))
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.leading, ls(6))
        }
    }

    private var vaccinesListSection: some View {
        VStack(alignment: .leading, spacing: ls(10)) {
            sectionAccentTitle("VACCINES")

            ForEach(Array(profileVaccinesForDisplay.enumerated()), id: \.element.id) { index, entry in
                profileVaccineRow(entry)
                if index < profileVaccinesForDisplay.count - 1 {
                    Rectangle()
                        .fill(Color(hex: "eeeeee"))
                        .frame(height: 0.5)
                        .padding(.vertical, ls(6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vaccineCurrentBadge: some View {
        Text("CURRENT")
            .font(.system(size: ls(14), weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, ls(5))
            .padding(.vertical, ls(2))
            .background(Capsule().fill(Color(hex: "34C759")))
    }

    private func vaccineIsCurrent(_ entry: VaccineEntry) -> Bool {
        if let exp = entry.dateExpires {
            return exp >= Calendar.current.startOfDay(for: Date())
        }
        return true
    }

    private func profileVaccineRow(_ entry: VaccineEntry) -> some View {
        let n = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let admin = entry.dateAdministered.formatted(date: .abbreviated, time: .omitted)
        let dateString: String = {
            if let exp = entry.dateExpires {
                return "Given \(admin) · Exp \(exp.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Given \(admin)"
        }()
        let showCurrent = vaccineIsCurrent(entry)
        return Group {
            if showCurrent {
                HStack(alignment: .firstTextBaseline, spacing: ls(4)) {
                    Text(n)
                        .font(.system(size: ls(15), weight: .medium, design: .rounded))
                        .foregroundStyle(primaryText)
                    vaccineCurrentBadge
                    Text("—")
                        .font(.system(size: ls(15), weight: .regular, design: .rounded))
                        .foregroundStyle(detailGray)
                    Text(dateString)
                        .font(.system(size: ls(15), weight: .regular, design: .rounded))
                        .foregroundStyle(detailGray)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            } else {
                Text(vaccineNameDateAttributed(name: n, dateString: dateString))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, ls(6))
        .padding(.leading, ls(10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medicationsBlock: some View {
        VStack(alignment: .leading, spacing: ls(10)) {
            sectionAccentTitle("MEDICATIONS")
            if let c = fieldSettings.customMedications?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
                let customLines = c.split(whereSeparator: \.isNewline).map(String.init).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                VStack(spacing: 0) {
                    ForEach(Array(customLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: ls(15), weight: .medium, design: .rounded))
                            .foregroundStyle(primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, ls(6))
                            .padding(.leading, ls(10))
                        if index < customLines.count - 1 {
                            Rectangle()
                                .fill(Color(hex: "eeeeee"))
                                .frame(height: 0.5)
                        }
                    }
                }
            } else {
                ForEach(Array(profileMedicationsForDisplay.enumerated()), id: \.element.id) { index, entry in
                    profileMedicationRow(entry)
                    if index < profileMedicationsForDisplay.count - 1 {
                        Rectangle()
                            .fill(Color(hex: "eeeeee"))
                            .frame(height: 0.5)
                            .padding(.vertical, ls(6))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var allergiesSection: some View {
        VStack(alignment: .leading, spacing: ls(8)) {
            sectionAccentTitle("ALLERGIES")
            Text(allergiesDisplay)
                .font(.system(size: ls(18), weight: .medium, design: .rounded))
                .foregroundStyle(primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileMedicationRow(_ entry: MedicationEntry) -> some View {
        let n = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = entry.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        let f = entry.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = n.isEmpty ? "Medication" : n
        let detail = [a, f].filter { !$0.isEmpty }.joined(separator: " · ")
        return Group {
            if detail.isEmpty {
                HStack(alignment: .center, spacing: ls(4)) {
                    Text(title)
                        .font(.system(size: ls(15), weight: .medium, design: .rounded))
                        .foregroundStyle(primaryText)
                    Spacer(minLength: 0)
                }
            } else {
                HStack(alignment: .center, spacing: ls(4)) {
                    Text(title)
                        .font(.system(size: ls(15), weight: .medium, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text("—")
                        .font(.system(size: ls(15), weight: .regular, design: .rounded))
                        .foregroundStyle(detailGray)
                    Text(detail)
                        .font(.system(size: ls(15), weight: .regular, design: .rounded))
                        .foregroundStyle(detailGray)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, ls(6))
        .padding(.leading, ls(10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var specialNotesSection: some View {
        VStack(alignment: .leading, spacing: ls(8)) {
            sectionAccentTitle("SPECIAL NOTES")
            Text(specialNotesTrimmed)
                .font(.system(size: ls(14), weight: .medium, design: .rounded))
                .italic()
                .foregroundStyle(primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(ls(10))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ls(8), style: .continuous)
                        .fill(Color(hex: "fffbf5"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ls(8), style: .continuous)
                        .strokeBorder(Color(hex: "f5e6cc"), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var careCardAttachmentImageSection: some View {
        Group {
            #if canImport(UIKit)
            if let d = data.pet.careCardAttachmentImageData, !d.isEmpty, let ui = UIImage(data: d) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: ls(12), style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ls(12), style: .continuous)
                            .strokeBorder(Color(hex: "E8E4DE"), lineWidth: 0.5)
                    )
            }
            #endif
        }
    }

    @ViewBuilder
    private var attachmentsListSection: some View {
        let atts = sortedAttachments
        if atts.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: ls(8)) {
                sectionAccentTitle("ATTACHMENTS")
                ForEach(0..<((atts.count + 2) / 3), id: \.self) { ri in
                    let row = attachmentGridRow(atts, rowIndex: ri)
                    HStack(spacing: ls(8)) {
                        ForEach(row, id: \.id) { att in
                            attachmentThumbnailCell(att)
                                .frame(width: ls(72))
                        }
                        if row.count < 3 {
                            ForEach(0..<(3 - row.count), id: \.self) { _ in
                                Color.clear
                                    .frame(width: ls(52), height: ls(52))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: ls(60))
        }
    }

    private func attachmentDisplayFileName(_ att: PetAttachment) -> String {
        let n = att.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Attachment" : n
    }

    @ViewBuilder
    private func attachmentThumbnailCell(_ att: PetAttachment) -> some View {
        let label = attachmentDisplayFileName(att)
        let inner = VStack(spacing: ls(4)) {
            attachmentThumbnailVisual(att)
            Text(label)
                .font(.system(size: ls(14), weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "888888"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: ls(72))
        }
        .frame(width: ls(72))

        if let onTap = onAttachmentTap {
            Button {
                onTap(att)
            } label: {
                inner
            }
            .buttonStyle(.plain)
        } else {
            inner
        }
    }

    /// Synchronous `UIImage(data: att.data)` only — `ImageRenderer` export needs immediate pixels (`PetAttachment.data`).
    private func attachmentThumbnailVisual(_ att: PetAttachment) -> AnyView {
        #if canImport(UIKit)
        let isPDF = att.careCardIsLikelyPDF()
        if !isPDF,
           !att.data.isEmpty,
           let uiImage = UIImage(data: att.data) {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: ls(52), height: ls(52))
                    .clipShape(RoundedRectangle(cornerRadius: ls(8), style: .continuous))
            )
        } else {
            return AnyView(attachmentDocPlaceholder)
        }
        #else
        return AnyView(attachmentDocPlaceholder)
        #endif
    }

    private var attachmentDocPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ls(8), style: .continuous)
                .fill(Color(hex: "f0f0f0"))
            Image(systemName: "doc.fill")
                .font(.system(size: ls(32), weight: .medium))
                .foregroundStyle(Color(hex: "757575"))
        }
        .frame(width: ls(52), height: ls(52))
    }

    // MARK: Footer (always last; never overlaps body content)

    private var footerSection: some View {
        VStack(spacing: ls(10)) {
            Rectangle()
                .fill(Color(hex: "F4845F"))
                .frame(height: ls(1.5))
                .frame(maxWidth: .infinity)

            HStack(spacing: ls(8)) {
                PetpalAppIconThumbnail(size: ls(28))
                Text("Made with Petpal App")
                    .font(.system(size: ls(14), weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "F4845F"))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, ls(8))
    }

    // MARK: Photo

    @ViewBuilder
    private var photoOrPlaceholder: some View {
        #if canImport(UIKit)
        if let d = data.pet.profileImage, !d.isEmpty, let ui = UIImage(data: d) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            gradientPawPlaceholderCircle
        }
        #else
        gradientPawPlaceholderCircle
        #endif
    }

    private var gradientPawPlaceholderCircle: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "E8622A").opacity(0.85),
                            Color(hex: "4A90D9").opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "pawprint.fill")
                .font(.system(size: ls(64), weight: .medium))
                .foregroundStyle(Color.white.opacity(0.95))
        }
    }

    private var breedSpeciesAgeSubtitle: String? {
        let species = data.pet.species.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedFromModel = data.pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedFromCustom = fieldSettings.customBreed?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let breed = breedFromCustom.isEmpty ? breedFromModel : breedFromCustom

        var segments: [String] = []

        if fieldSettings.showBreed {
            if !breed.isEmpty && !species.isEmpty {
                segments.append("\(breed) · \(species)")
            } else if !breed.isEmpty {
                segments.append(breed)
            } else if !species.isEmpty {
                segments.append(species)
            }
        }

        if fieldSettings.showAge {
            segments.append(ageShortDescription(from: data.pet.dateOfBirth))
        }

        if let dob = data.pet.dateOfBirth {
            segments.append("Born \(dob.formatted(date: .abbreviated, time: .omitted))")
        }

        let joined = segments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "—" }
        guard !joined.isEmpty else { return nil }
        return joined.joined(separator: " · ")
    }

    private func ageShortDescription(from birth: Date?) -> String {
        guard let birth else { return "—" }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: cal.startOfDay(for: birth), to: cal.startOfDay(for: Date()))
        if let y = comps.year, y > 0 {
            return "\(y) yr\(y == 1 ? "" : "s")"
        }
        if let m = comps.month, m > 0 {
            return "\(m) mo"
        }
        return "< 1 mo"
    }

    private var weightLine: String {
        if let c = fieldSettings.customWeight?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        if data.pet.weight > 0 {
            let unit = WeightUnit(rawValue: data.pet.weightUnit.lowercased()) ?? .lbs
            let v = data.pet.weight
            return String(format: "%.1f %@", v, unit.shortSymbol)
        }
        return "Not on file"
    }

    private var microchipLine: String {
        if let c = fieldSettings.customMicrochip?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        let s = data.pet.microchipNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Not on file" : s
    }

    private var vetNameDisplay: String {
        if let c = fieldSettings.customVetName?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        let n = data.pet.vetName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Not on file" : n
    }

    private var vetPhoneDisplay: String {
        if let c = fieldSettings.customVetPhone?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        let p = data.pet.vetPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        return p.isEmpty ? "Not on file" : p
    }

    private var vetEmailDisplay: String {
        if let c = fieldSettings.customVetEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        let e = data.pet.vetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.isEmpty ? "Not on file" : e
    }

    private var vetNameIsPlaceholder: Bool { vetNameDisplay == "Not on file" }
    private var vetPhoneIsPlaceholder: Bool { vetPhoneDisplay == "Not on file" }
    private var vetEmailIsPlaceholder: Bool { vetEmailDisplay == "Not on file" }

    private var emergencyNameDisplay: String {
        if let c = fieldSettings.customEmergencyName?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        let pn = data.pet.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines)
        return pn.isEmpty ? "Not on file" : pn
    }

    private var emergencyPhoneDisplay: String {
        if let c = fieldSettings.customEmergencyPhone?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        let pp = data.pet.emergencyContactNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return pp.isEmpty ? "Not on file" : pp
    }

    private var emergencyNameIsPlaceholder: Bool { emergencyNameDisplay == "Not on file" }
    private var emergencyPhoneIsPlaceholder: Bool { emergencyPhoneDisplay == "Not on file" }

    private var allergiesDisplay: String {
        if let c = fieldSettings.customAllergies?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        let profileA = data.pet.allergies.trimmingCharacters(in: .whitespacesAndNewlines)
        return profileA.isEmpty ? "None known" : profileA
    }

    private var medicationLinesEffective: [String] {
        if let c = fieldSettings.customMedications?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c.split(whereSeparator: \.isNewline).map(String.init).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return data.pet.medicationsArray.map { m -> String in
            let n = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = m.amount.trimmingCharacters(in: .whitespacesAndNewlines)
            let f = m.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = n.isEmpty ? "Medication" : n
            if a.isEmpty && f.isEmpty { return name }
            if f.isEmpty { return "\(name) — \(a)" }
            if a.isEmpty { return "\(name) — \(f)" }
            return "\(name) — \(a) · \(f)"
        }
    }

    private var spayedNeuteredDisplay: (text: String, muted: Bool) {
        if let c = fieldSettings.customSpayedNeutered?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            let u = c.lowercased()
            if u == "yes" { return ("Yes", false) }
            if u == "no" { return ("No", false) }
            if u == "unknown" { return ("Unknown", true) }
            return (c, false)
        }
        switch data.pet.isSpayedNeutered {
        case true: return ("Yes", false)
        case false: return ("No", false)
        case nil: return ("Unknown", true)
        }
    }

}

extension PetAttachment {
    /// PDF vs image routing for Care Card thumbnails (file type, extension, or `%PDF-` header).
    func careCardIsLikelyPDF() -> Bool {
        if fileType.lowercased() == "pdf" { return true }
        if name.lowercased().hasSuffix(".pdf") { return true }
        if data.count >= 5, String(data: data.prefix(5), encoding: .ascii) == "%PDF-" { return true }
        return false
    }
}
