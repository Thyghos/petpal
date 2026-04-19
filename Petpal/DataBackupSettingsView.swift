// DataBackupSettingsView.swift
// Export / import Petpal data (JSON). iOS: share sheet + file importer.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

#if os(iOS)
struct DataBackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selection = BackupSelection.allOn
    @State private var exportFormat: PetpalBackupExportFormat = .zip
    @State private var sharePayload: ShareSheetPayload?
    @State private var showImportPicker = false
    @State private var importMode: PetpalBackupImportMode = .mergeSkipExisting
    @State private var showImportConfirm = false
    @State private var pendingImportData: Data?
    @State private var alertMessage: String?
    @State private var isWorking = false

    var body: some View {
        List {
            Section {
                Text("With iCloud signed in on your devices, Petpal usually syncs your data automatically (allow time—open the app on Wi‑Fi or cellular). Use backup to move data without iCloud or for an extra copy. Export to Mail, AirDrop, or Files; on another device use Import. ZIP wraps the same JSON. Large photos and PDFs make exports bigger.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Export format", selection: $exportFormat) {
                    ForEach(PetpalBackupExportFormat.allCases) { fmt in
                        Text(fmt.pickerTitle).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Select all", isOn: Binding(
                    get: { selection == .allOn },
                    set: { selection.setAll($0) }
                ))
            }

            Section("Include in backup") {
                Toggle("Pet profiles (names, photos, vet/groomer)", isOn: $selection.includePets)
                Toggle("Reminders", isOn: $selection.includeReminders)
                Toggle("Health history (visits + visit attachments)", isOn: $selection.includeHealthHistory)
                Toggle("Emergency QR profiles", isOn: $selection.includeEmergencyProfiles)
                Toggle("Insurance (policies + policy attachments)", isOn: $selection.includeInsurance)
                Toggle("Pet Care Notes (sitter)", isOn: $selection.includeSitterInstructions)
                Toggle("Certificates (records + attachments)", isOn: $selection.includeCertificates)
                Toggle("Stored vet documents + attachments", isOn: $selection.includeStoredVetDocuments)
                Toggle("Home & tips preferences", isOn: $selection.includeAppPreferences)
            }

            Section {
                Button {
                    exportTapped()
                } label: {
                    if isWorking {
                        HStack {
                            ProgressView()
                            Text("Preparing…")
                        }
                    } else {
                        Label("Export backup…", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isWorking || !selection.hasAnySelection)
            } footer: {
                Text("If you turn off Pet profiles but include reminders or visits, pets those rows reference are still included so the backup stays consistent.")
            }

            Section {
                Picker("When importing", selection: $importMode) {
                    ForEach(PetpalBackupImportMode.allCases) { mode in
                        Text(mode.pickerTitle).tag(mode)
                    }
                }
                .pickerStyle(.inline)

                Button {
                    showImportPicker = true
                } label: {
                    Label("Import backup…", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
            } footer: {
                Text("Replace all deletes every Petpal record on this device before loading the file. “Keep existing” merge skips rows when IDs match. “Update existing” overwrites matching rows with values from the backup.")
            }
        }
        .navigationTitle("Backup & restore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json, .zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    if importMode == .replaceAll {
                        pendingImportData = data
                        showImportConfirm = true
                    } else {
                        runImport(data: data)
                    }
                } catch {
                    alertMessage = error.localizedDescription
                }
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
        .alert("Replace all data?", isPresented: $showImportConfirm) {
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
            }
            Button("Replace all", role: .destructive) {
                if let data = pendingImportData {
                    runImport(data: data)
                }
                pendingImportData = nil
            }
        } message: {
            Text("This removes all Petpal data on this device and replaces it with the backup. This cannot be undone.")
        }
        .alert("Backup", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func exportTapped() {
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                let jsonData = try PetpalBackup.exportJSON(selection: selection, modelContext: modelContext)
                let outData: Data
                switch exportFormat {
                case .json:
                    outData = jsonData
                case .zip:
                    outData = PetpalBackupZip.zipJSON(jsonData)
                }
                let ext = exportFormat.fileExtension
                let name = "\(PetpalBackup.fileNamePrefix)-\(ISO8601DateFormatter().string(from: Date()).prefix(10)).\(ext)"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try outData.write(to: url, options: .atomic)
                sharePayload = ShareSheetPayload(items: [url])
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    private func runImport(data: Data) {
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try PetpalBackup.importJSON(data, mode: importMode, modelContext: modelContext)
                switch importMode {
                case .replaceAll:
                    alertMessage = "Restore complete."
                case .mergeSkipExisting:
                    alertMessage = "Import complete. Existing records were kept when IDs matched."
                case .mergeUpdateExisting:
                    alertMessage = "Import complete. Matching records were updated from the backup."
                }
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }
}
#endif
