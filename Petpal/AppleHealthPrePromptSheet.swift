// AppleHealthPrePromptSheet.swift
// Pre-permission education + Settings detail for Apple Health (iOS).

import SwiftUI

#if os(iOS)

// MARK: - First-time pre-prompt (Health tab / Settings)

struct AppleHealthPrePromptSheet: View {
    let petName: String
    var onConnect: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color("BrandSoftBlue").opacity(0.35))
                        .frame(width: 100, height: 100)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 44, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("BrandBlue"), Color("BrandPurple")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("BrandOrange"))
                        .offset(x: 30, y: 28)
                }
                .padding(.top, 8)

                VStack(spacing: 10) {
                    Text("Track walks with \(petName)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color("BrandDark"))
                        .multilineTextAlignment(.center)

                    Text("Petpal can read your iPhone's step and activity data to automatically track walks with your pet. We never write to Health or share your data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.light()
                        onConnect()
                    } label: {
                        Text("Connect Apple Health")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("BrandOrange"))
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        HapticManager.shared.soft()
                        onNotNow()
                    } label: {
                        Text("Not now")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color("BrandDark"))
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                }
                .padding(14)
                .modernCard(cornerRadius: 18, shadowRadius: 10, shadowY: 4)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onNotNow()
                    }
                }
            }
        }
    }
}

// MARK: - Settings — connected detail

struct AppleHealthSettingsDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var service: AppleHealthService
    var onDisconnect: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent {
                        Text("Connected")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.green)
                    } label: {
                        Text("Status")
                    }
                    if let last = service.lastSyncDate {
                        LabeledContent("Last synced", value: last.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        LabeledContent("Last synced", value: "—")
                    }
                }

                Section("This year (from Apple Health)") {
                    if let s = service.summary {
                        LabeledContent("Miles (walking & running)", value: String(format: "%.1f mi", s.totalMilesThisYear))
                        LabeledContent("Steps", value: "\(s.totalStepsThisYear)")
                        LabeledContent("Active minutes", value: "\(s.totalActiveMinutesThisYear)")
                        LabeledContent("Active calories", value: "\(s.totalCaloriesThisYear) kcal")
                    } else {
                        Text("No summary yet. Open the Health tab after connecting to refresh.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        HapticManager.shared.warning()
                        service.disconnect()
                        onDisconnect()
                        dismiss()
                    } label: {
                        Text("Disconnect")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await service.refreshSummaryIfStale()
            }
        }
    }
}

#endif
