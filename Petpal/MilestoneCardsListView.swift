// MilestoneCardsListView.swift
// All milestone records for the active pet + manual generator entry point.

import SwiftUI
import SwiftData

struct MilestoneCardsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MilestoneRecord.triggeredDate, order: .reverse) private var allMilestones: [MilestoneRecord]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var showGenerator = false
    @State private var selectedDetailRecordId: UUID?
    @State private var deleteCandidate: MilestoneRecord?

    private var sortedPets: [Pet] {
        pets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var activePetId: UUID? {
        ActivePetResolver.resolvedPetId(pets: sortedPets)
    }

    private var scopedMilestones: [MilestoneRecord] {
        guard let pid = activePetId else { return [] }
        return allMilestones.filter { $0.petId == pid }
    }

    var body: some View {
        List {
            if scopedMilestones.isEmpty {
                ContentUnavailableView(
                    "No milestones yet",
                    systemImage: "sparkles",
                    description: Text("They appear automatically when your pet hits a milestone.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(scopedMilestones, id: \.id) { record in
                    Button {
                        HapticManager.shared.light()
                        selectedDetailRecordId = record.id
                    } label: {
                        HStack(spacing: 14) {
                            Text(MilestoneType(rawValue: record.milestoneType)?.emoji ?? "🐾")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(MilestoneType(rawValue: record.milestoneType)?.displayName ?? "Milestone")
                                    .font(.headline)
                                    .foregroundStyle(Color("BrandDark"))
                                Text(record.triggeredDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteCandidate = record
                        } label: {
                            Label("Delete Card", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteCandidate = record
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Section {
                Button {
                    HapticManager.shared.medium()
                    showGenerator = true
                } label: {
                    Label("Generate a Card", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color("BrandOrange"))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Milestone Cards")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGenerator) {
            MilestoneGeneratorSheet(
                onFinished: { record in
                    showGenerator = false
                    selectedDetailRecordId = record.id
                },
                onCancel: { showGenerator = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { selectedDetailRecordId != nil },
            set: { if !$0 { selectedDetailRecordId = nil } }
        )) {
            if let id = selectedDetailRecordId,
               let record = scopedMilestones.first(where: { $0.id == id }) {
                MilestoneCardDetailView(record: record)
                    .id(id)
            } else {
                ProgressView()
                    .task { selectedDetailRecordId = nil }
            }
        }
        .alert("Delete this card?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let r = deleteCandidate {
                    modelContext.delete(r)
                    try? modelContext.save()
                    if selectedDetailRecordId == r.id {
                        selectedDetailRecordId = nil
                    }
                }
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
}
