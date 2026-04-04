// PetpalSwiftDataStore.swift
// Single, stable on-disk location for SwiftData + CloudKit (see `PetpalApp` `ModelConfiguration`) so upgrades never open a second store by mistake.
// Also moves a lone legacy "*.store" bundle into the canonical name when upgrading from builds that omitted an explicit URL.

import Foundation

/// Set from `PetpalApp` when the on-disk store cannot be opened (so the UI can warn the user).
enum PetpalPersistenceDiagnostics {
    static var isUsingInMemoryStore = false
    static var lastDiskPersistenceFailureSummary: String?
    /// `true` when CloudKit-backed open failed and the app fell back to a local-only store (data still saves on device).
    static var openedWithLocalStoreOnlyAfterCloudFailure = false

    private static let suppressInMemoryAlertKey = "PetpalSuppressInMemoryStoreAlert"

    static var suppressInMemoryStoreAlert: Bool {
        get { UserDefaults.standard.bool(forKey: suppressInMemoryAlertKey) }
        set { UserDefaults.standard.set(newValue, forKey: suppressInMemoryAlertKey) }
    }

    private static let acknowledgedLocalOnlyKey = "PetpalUserAcknowledgedLocalOnlyStore"

    /// After CloudKit open fails once, we fall back to local disk; explain that at most once unless the user asks again.
    static var userAcknowledgedLocalOnlyFallback: Bool {
        get { UserDefaults.standard.bool(forKey: acknowledgedLocalOnlyKey) }
        set { UserDefaults.standard.set(newValue, forKey: acknowledgedLocalOnlyKey) }
    }
}

/// Tracks “we recreated the store file” so the reset alert shows **once per recovery**, not on every `onAppear`.
enum PetpalStoreRecoveryNotice {
    private static let eventKey = "PetpalStoreRecoveryEventTimestamp"
    private static let ackKey = "PetpalUserAcknowledgedStoreRecoveryTimestamp"
    private static let suppressResetAlertKey = "PetpalSuppressStoreResetAlert"

    static func registerRecoveryEvent() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: eventKey)
    }

    static var shouldShowRecoveryNotice: Bool {
        if UserDefaults.standard.bool(forKey: suppressResetAlertKey) { return false }
        let event = UserDefaults.standard.double(forKey: eventKey)
        let ack = UserDefaults.standard.double(forKey: ackKey)
        return event > ack + 0.000_001
    }

    static func suppressRecoveryNoticeForever() {
        UserDefaults.standard.set(true, forKey: suppressResetAlertKey)
        markRecoveryNoticeAcknowledged()
    }

    static func markRecoveryNoticeAcknowledged() {
        let event = UserDefaults.standard.double(forKey: eventKey)
        UserDefaults.standard.set(event, forKey: ackKey)
    }
}

enum PetpalSwiftDataStore {
    /// Matches SwiftData’s usual default on-disk name so existing installs keep the same file when possible.
    private static let canonicalFileName = "default.store"

    static func storeURL() -> URL {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable.")
        }
        if !fm.fileExists(atPath: appSupport.path) {
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        let canonical = appSupport.appendingPathComponent(canonicalFileName, isDirectory: false)
        migrateSingleLegacyStoreIfNeeded(applicationSupport: appSupport, canonical: canonical, fileManager: fm)
        return canonical
    }

    /// If there is no `default.store` yet but exactly one other `*.store` exists, rename/move it to `default.store`.
    private static func migrateSingleLegacyStoreIfNeeded(
        applicationSupport: URL,
        canonical: URL,
        fileManager fm: FileManager
    ) {
        guard !fm.fileExists(atPath: canonical.path) else { return }
        guard let names = try? fm.contentsOfDirectory(atPath: applicationSupport.path) else { return }
        let storeBundles = names.filter { $0.hasSuffix(".store") }
        guard storeBundles.count == 1, let sole = storeBundles.first, sole != canonicalFileName else { return }
        let legacy = applicationSupport.appendingPathComponent(sole)
        do {
            try fm.moveItem(at: legacy, to: canonical)
        } catch {
            // Keep legacy file; opening `canonical` will create a new store — user may need support.
            // Avoid deleting or copying to prevent duplicate/conflicting stores.
        }
    }

    /// Removes the canonical SwiftData package and common SQLite sidecars so the next open creates a clean store.
    /// Use only when opening the store has already failed (likely corruption or a half-finished CloudKit migration).
    static func removeCanonicalStoreArtifacts() throws {
        let safeName = canonicalFileName
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let items = (try? fm.contentsOfDirectory(atPath: appSupport.path)) ?? []
        for name in items {
            guard name == safeName || name.hasPrefix(safeName + "-") || name.hasPrefix(safeName + ".") else { continue }
            try fm.removeItem(at: appSupport.appendingPathComponent(name))
        }
    }
}
