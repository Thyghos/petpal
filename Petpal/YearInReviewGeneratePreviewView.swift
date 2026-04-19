// Preview what will go into a Year in Review before running AI generation and saving.

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
struct YearInReviewGeneratePreviewView: View {
    let pet: Pet
    let year: Int

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var appleHealth = AppleHealthService.shared

    @State private var previewStats: YearInReviewRecord?
    @State private var loadError: String?
    @State private var isLoadingStats = true
    @State private var isGenerating = false
    @State private var generateError: String?
    @State private var generatedRecord: YearInReviewRecord?
    @State private var navigateToFullPreview = false

    private var petDisplayName: String {
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your pet" : n
    }

    var body: some View {
        Group {
            if isLoadingStats {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading your \(String(year)) stats…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = loadError, previewStats == nil {
                ContentUnavailableView(
                    "Couldn’t load preview",
                    systemImage: "exclamationmark.triangle",
                    description: Text(err)
                )
            } else if let stats = previewStats {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Review what we’ll include. Nothing is saved until you generate. Headlines and personality lines are created by AI when you tap Generate.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Included from Petpal")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color("BrandOrange"))
                            statBlock(stats: stats)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )

                        if let g = generateError {
                            Text(g)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await runGeneration() }
                        } label: {
                            Group {
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Label("Generate \(String(year)) in Review", systemImage: "wand.and.stars")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("BrandOrange"))
                        .disabled(isGenerating)

                        Text("After generating, you’ll open the full slide preview—customize slides, then share or save.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToFullPreview) {
            if let r = generatedRecord {
                YearInReviewPreviewView(pet: pet, record: r)
            }
        }
        .task {
            await loadPreviewStats()
        }
    }

    private func statBlock(stats: YearInReviewRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            statRow("Vet visits logged", "\(stats.vetVisitsCount)")
            statRow("Milestones in \(String(year))", "\(stats.milestonesCount)")
            statRow("Walks logged with \(petDisplayName)", "\(stats.totalWalksWithPet)")
            statRow("Miles walked together (logged)", formatMiles(stats.totalMilesWithPet))
            statRow("Vaccine certificate updates (year)", "\(stats.vaccinesCompletedCount)")
            statRow("Medication reminders added (year)", "\(stats.medicationsLoggedCount)")
            if let w = stats.weightChangeText, !w.isEmpty {
                statRow("Weight trend", w)
            }
            if appleHealth.isConnected && (stats.totalMiles > 0 || stats.totalSteps > 0) {
                Divider().padding(.vertical, 4)
                Text("Apple Health (your activity in \(String(year)))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                statRow("Walking + running (mi)", formatMiles(stats.totalMiles))
                statRow("Steps (approx.)", NumberFormatter.localizedString(from: NSNumber(value: stats.totalSteps), number: .decimal))
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("BrandDark"))
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatMiles(_ m: Double) -> String {
        String(format: "%.1f mi", m)
    }

    @MainActor
    private func loadPreviewStats() async {
        isLoadingStats = true
        loadError = nil
        await appleHealth.refreshSummaryIfStale()
        do {
            previewStats = try YearInReviewDataService.aggregateStats(
                pet: pet,
                year: year,
                modelContext: modelContext,
                appleHealthSummary: appleHealth.summary
            )
        } catch {
            loadError = error.localizedDescription
            previewStats = nil
        }
        isLoadingStats = false
    }

    @MainActor
    private func runGeneration() async {
        generateError = nil
        isGenerating = true
        await appleHealth.refreshSummaryIfStale()
        do {
            let record = try await YearInReviewDataService.generateOrUpdate(
                pet: pet,
                year: year,
                modelContext: modelContext,
                appleHealthSummary: appleHealth.summary,
                forceRefreshAI: false
            )
            generatedRecord = record
            navigateToFullPreview = true
        } catch {
            generateError = error.localizedDescription
        }
        isGenerating = false
    }
}
#endif
