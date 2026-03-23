// PetsListView.swift
// Petpal - Manage Multiple Pets

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.dateAdded, order: .reverse) private var pets: [Pet]
    @State private var showingAddPet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color("BrandCream"), Color("BrandSoftBlue").opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if pets.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 8) {
                        List {
                            ForEach(pets) { pet in
                                PetListRow(
                                    pet: pet,
                                    onSelect: { setActivePet(pet) },
                                    onDelete: { deletePet(pet) }
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deletePet(pet)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)

                        Text("Swipe left on a pet to delete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("My Pets")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("BrandOrange"))
                    }
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color("BrandOrange").opacity(0.5))
            
            Text("No Pets Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color("BrandDark"))
            
            Text("Add your first pet to get started with Petpal!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingAddPet = true
            } label: {
                Label("Add Pet", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color("BrandOrange"))
                    .clipShape(Capsule())
            }
        }
    }
    
    private func setActivePet(_ pet: Pet) {
        for p in pets {
            p.isActive = false
        }
        pet.isActive = true
        pet.syncToLegacyAppStorage()
        try? modelContext.save()
        dismiss()
    }
    
    private func deletePet(_ pet: Pet) {
        let wasActive = pet.isActive
        let others = pets.filter { $0.id != pet.id }
        modelContext.delete(pet)
        if wasActive, let next = others.first {
            for p in others {
                p.isActive = (p.id == next.id)
            }
            next.syncToLegacyAppStorage()
        } else if wasActive {
            UserDefaults.standard.removeObject(forKey: "activePetId")
        }
        try? modelContext.save()
    }
}

struct PetListRow: View {
    let pet: Pet
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
                // Pet Avatar
                ZStack {
                    Circle()
                        .fill(pet.isActive ? Color("BrandOrange") : Color("BrandBlue").opacity(0.3))
                        .frame(width: 60, height: 60)
                    
                    #if os(iOS)
                    if let imageData = pet.profileImage, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Text(petEmoji(for: pet.species))
                            .font(.largeTitle)
                    }
                    #elseif os(macOS)
                    if let imageData = pet.profileImage, let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Text(petEmoji(for: pet.species))
                            .font(.largeTitle)
                    }
                    #endif
                    
                    if pet.isActive {
                        Circle()
                            .fill(.green)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                            .offset(x: 20, y: 20)
                    }
                }
                
                // Pet Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.headline)
                        .foregroundStyle(Color("BrandDark"))
                    
                    if !pet.breed.isEmpty {
                        Text("\(pet.breed) • \(pet.species)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(pet.species)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if pet.weight > 0 {
                        Text("\(Int(pet.weight)) \(pet.weightUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if pet.isActive {
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("BrandOrange"))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
        .contextMenu {
            if !pet.isActive {
                Button {
                    onSelect()
                } label: {
                    Label("Set as Active", systemImage: "checkmark.circle")
                }
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var cardBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.white
        #endif
    }
    
    private func petEmoji(for species: String) -> String {
        switch species.lowercased() {
        case "dog": return "🐕"
        case "cat": return "🐈"
        case "bird": return "🐦"
        case "rabbit": return "🐰"
        case "fish": return "🐠"
        case "reptile": return "🦎"
        default: return "🐾"
        }
    }
}

#Preview {
    PetsListView()
        .modelContainer(for: Pet.self, inMemory: true)
}
