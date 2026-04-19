// VaccineReminderSetupSheet.swift
// Configure per-vaccine renewal reminders after a vet visit is saved.

#if os(iOS)
import SwiftData
import SwiftUI

struct VaccineReminderConfig: Identifiable {
    let id: UUID
    var vaccineName: String
    var isEnabled: Bool = true
    var dueDate: Date
    var leadTimeDays: Int = 30
    /// True when the certificate has no expiration and no parsed due date was available — user must pick the due date.
    var requiresManualDueDatePicker: Bool

    var reminderDate: Date {
        Calendar.current.date(byAdding: .day, value: -leadTimeDays, to: dueDate) ?? dueDate
    }

    static let leadTimeOptions: [(days: Int, label: String)] = [
        (14, "2 weeks before"),
        (30, "1 month before"),
        (60, "2 months before"),
        (90, "3 months before"),
        (180, "6 months before"),
        (0, "On the due date"),
    ]
}

struct VaccineReminderSetupSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vaccines: [String]
    let visitDate: Date
    let clinicName: String
    let certificates: [PetCertificate]
    var parsedDueHints: [ParsedVaccineDue] = []
    let activePet: Pet
    let onComplete: (_ remindersCreated: Int) -> Void

    @State private var configs: [VaccineReminderConfig]

    init(
        vaccines: [String],
        visitDate: Date,
        clinicName: String,
        certificates: [PetCertificate],
        parsedDueHints: [ParsedVaccineDue] = [],
        activePet: Pet,
        onComplete: @escaping (_ remindersCreated: Int) -> Void
    ) {
        self.vaccines = vaccines
        self.visitDate = visitDate
        self.clinicName = clinicName
        self.certificates = certificates
        self.parsedDueHints = parsedDueHints
        self.activePet = activePet
        self.onComplete = onComplete
        _configs = State(
            initialValue: Self.buildConfigs(
                vaccines: vaccines,
                visitDate: visitDate,
                certificates: certificates,
                parsedDueHints: parsedDueHints
            )
        )
    }

    private var enabledCount: Int {
        configs.filter(\.isEnabled).count
    }

    private static func normalizedKey(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func certificate(
        at index: Int,
        vaccineName: String,
        vaccines: [String],
        certificates: [PetCertificate]
    ) -> PetCertificate? {
        if certificates.count == vaccines.count, index < certificates.count {
            return certificates[index]
        }
        let key = normalizedKey(vaccineName)
        return certificates.first { normalizedKey($0.title) == key }
    }

    private static func parsedDue(for vaccineName: String, hints: [ParsedVaccineDue]) -> Date? {
        let key = normalizedKey(vaccineName)
        return hints.first { normalizedKey($0.name) == key }?.dueDate
    }

    private static func defaultDueDate(visitDate: Date) -> Date {
        Calendar.current.date(byAdding: .year, value: 1, to: visitDate) ?? visitDate
    }

    private static func buildConfigs(
        vaccines: [String],
        visitDate: Date,
        certificates: [PetCertificate],
        parsedDueHints: [ParsedVaccineDue]
    ) -> [VaccineReminderConfig] {
        vaccines.enumerated().map { index, name in
            let cert = certificate(at: index, vaccineName: name, vaccines: vaccines, certificates: certificates)
            let certExp = cert?.expirationDate
            let parsed = parsedDue(for: name, hints: parsedDueHints)
            let requiresManual = certExp == nil && parsed == nil
            let due = certExp ?? parsed ?? defaultDueDate(visitDate: visitDate)
            return VaccineReminderConfig(
                id: UUID(),
                vaccineName: name,
                isEnabled: true,
                dueDate: due,
                leadTimeDays: 30,
                requiresManualDueDatePicker: requiresManual
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Choose when to be reminded for each vaccine")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach($configs) { $config in
                        vaccineCard(config: $config)
                    }

                    VStack(spacing: 12) {
                        Button {
                            commitReminders()
                        } label: {
                            Text("Set \(enabledCount) Reminder\(enabledCount == 1 ? "" : "s")")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color("BrandOrange").opacity(enabledCount > 0 ? 1 : 0.4))
                                )
                        }
                        .disabled(enabledCount == 0)

                        Button("Skip", role: .cancel) {
                            onComplete(0)
                            dismiss()
                        }
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color("BrandDark").opacity(0.65))
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Set Vaccine Reminders")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func vaccineCard(config: Binding<VaccineReminderConfig>) -> some View {
        let c = config.wrappedValue
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(c.vaccineName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color("BrandDark"))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 12)
                Toggle("", isOn: config.isEnabled)
                    .labelsHidden()
                    .tint(Color("BrandOrange"))
            }

            if c.isEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    if c.requiresManualDueDatePicker {
                        DatePicker(
                            "When is this vaccine due?",
                            selection: config.dueDate,
                            displayedComponents: .date
                        )
                        .font(.subheadline)
                    }

                    HStack {
                        Text("Remind me")
                            .font(.subheadline)
                            .foregroundStyle(Color("BrandDark"))
                        Spacer()
                        Picker("Remind me", selection: config.leadTimeDays) {
                            ForEach(VaccineReminderConfig.leadTimeOptions, id: \.days) { opt in
                                Text(opt.label).tag(opt.days)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Text("Reminder set for \(c.reminderDate.formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("No reminder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .modernCard(cornerRadius: 18)
        .animation(.easeInOut(duration: 0.22), value: c.isEnabled)
    }

    private func notes(for config: VaccineReminderConfig) -> String {
        let dueStr = config.dueDate.formatted(date: .long, time: .omitted)
        let visitStr = visitDate.formatted(date: .long, time: .omitted)
        return "Due date: \(dueStr). From vet visit at \(clinicName) on \(visitStr)."
    }

    private func commitReminders() {
        let enabled = configs.filter(\.isEnabled)
        let pid = activePet.id
        for cfg in enabled {
            let reminder = PetReminder(
                petId: pid,
                title: "\(cfg.vaccineName) renewal due",
                notes: notes(for: cfg),
                category: "Vaccine",
                nextDueDate: cfg.reminderDate,
                recurring: false,
                recurrenceInterval: 1,
                recurrenceUnit: "month"
            )
            modelContext.insert(reminder)
        }
        do {
            try modelContext.save()
        } catch {
            onComplete(0)
            dismiss()
            return
        }
        PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
        onComplete(enabled.count)
        dismiss()
    }
}

#endif
