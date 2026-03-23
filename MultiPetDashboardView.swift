// MultiPetDashboardView.swift
// Petpal - Multi-Pet Dashboard
 
import SwiftUI
import SwiftData

struct MultiPetDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var pets: [Pet]
    @Query(sort: \PetReminder.nextDueDate) private var allReminders: [PetReminder]
    
    @State private var selectedPet: Pet?
    @State private var showingAddPet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color("BrandCream"), Color("BrandSoftBlue")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if pets.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("View all pets at a glance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        emptyState
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("View all pets at a glance")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                            // Summary Cards
                            summarySection
                            
                            // Pet Cards
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Pets")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                ForEach(pets) { pet in
                                    petDashboardCard(pet: pet)
                                        .onTapGesture {
                                            selectedPet = pet
                                        }
                                }
                            }
                            
                            // Upcoming Care Across All Pets
                            upcomingCareSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
            .sheet(item: $selectedPet) { pet in
                PetDetailView(pet: pet)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 80))
                .foregroundStyle(Color("BrandOrange").opacity(0.5))
            
            Text("No Pets Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Add your first pet to get started with the multi-pet dashboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingAddPet = true
            } label: {
                Text("Add Pet")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color("BrandOrange"))
                    .clipShape(Capsule())
            }
            .padding(.top)
        }
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryCard(
                    title: "Total Pets",
                    value: "\(pets.count)",
                    icon: "pawprint.fill",
                    color: Color("BrandOrange")
                )
                
                summaryCard(
                    title: "Upcoming Care",
                    value: "\(upcomingRemindersCount)",
                    icon: "bell.badge.fill",
                    color: Color("BrandPurple")
                )
            }
            
            HStack(spacing: 12) {
                summaryCard(
                    title: "This Week",
                    value: "\(thisWeekRemindersCount)",
                    icon: "calendar",
                    color: Color("BrandBlue")
                )
                
                summaryCard(
                    title: "Overdue",
                    value: "\(overdueRemindersCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: Color("BrandGreen")
                )
            }
        }
        .padding(.horizontal)
    }
    
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
    
    // MARK: - Pet Dashboard Card
    private func petDashboardCard(pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pet Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    HStack(spacing: 4) {
                        Text(pet.species)
                        if !pet.breed.isEmpty {
                            Text("•")
                            Text(pet.breed)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                
                // Pet emoji/icon
                Text(petEmoji(for: pet.species))
                    .font(.system(size: 48))
            }
            
            Divider()
            
            // Quick Stats for this pet
            HStack(spacing: 24) {
                petStat(icon: "bell.badge", value: "\(remindersCount(for: pet))", label: "Reminders")
                petStat(icon: "calendar", value: "\(age(for: pet))", label: "Age")
                if pet.weight > 0 {
                    petStat(icon: "scalemass", value: "\(Int(pet.weight))", label: "lbs")
                }
            }
            
            // Next upcoming reminder
            if let nextReminder = nextReminder(for: pet) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Care Item")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextReminder.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(nextReminder.nextDueDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if nextReminder.isOverdue {
                            Text("OVERDUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                    .background(Color("BrandPurple").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 12)
    }
    
    private func petStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color("BrandOrange"))
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Upcoming Care Section
    private var upcomingCareSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Care (All Pets)")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ForEach(upcomingReminders.prefix(5)) { reminder in
                upcomingCareCard(reminder: reminder)
            }
            
            if upcomingReminders.isEmpty {
                Text("No upcoming care items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func upcomingCareCard(reminder: PetReminder) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(reminder.nextDueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let petName = petName(for: reminder) {
                    Text("For: \(petName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if reminder.isOverdue {
                Text("OVERDUE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(Capsule())
            } else {
                Text(daysUntil(reminder.nextDueDate))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandPurple"))
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
    
    // MARK: - Helper Computed Properties
    private var upcomingRemindersCount: Int {
        allReminders.filter { !$0.isOverdue }.count
    }
    
    private var overdueRemindersCount: Int {
        allReminders.filter { $0.isOverdue }.count
    }
    
    private var thisWeekRemindersCount: Int {
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return allReminders.filter { $0.nextDueDate <= weekFromNow && !$0.isOverdue }.count
    }
    
    private var upcomingReminders: [PetReminder] {
        allReminders.filter { !$0.isOverdue }.sorted { $0.nextDueDate < $1.nextDueDate }
    }
    
    // MARK: - Helper Functions
    private func remindersCount(for pet: Pet) -> Int {
        // This would need proper relationship - placeholder for now
        0
    }
    
    private func age(for pet: Pet) -> String {
        guard let birthDate = pet.dateOfBirth else { return "N/A" }
        let components = Calendar.current.dateComponents([.year, .month], from: birthDate, to: Date())
        
        if let years = components.year, years > 0 {
            return "\(years)y"
        } else if let months = components.month, months > 0 {
            return "\(months)mo"
        } else {
            return "New"
        }
    }
    
    private func nextReminder(for pet: Pet) -> PetReminder? {
        // This would need proper relationship - placeholder for now
        nil
    }
    
    private func petName(for reminder: PetReminder) -> String? {
        // This would need proper relationship - placeholder for now
        nil
    }
    
    private func petEmoji(for species: String) -> String {
        switch species.lowercased() {
        case "dog": return "🐕"
        case "cat": return "🐱"
        case "bird": return "🦜"
        case "rabbit": return "🐰"
        case "fish": return "🐠"
        case "reptile": return "🦎"
        default: return "🐾"
        }
    }
    
    private func daysUntil(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else {
            return "in \(days) days"
        }
    }
}

#Preview {
    MultiPetDashboardView()
        .modelContainer(for: Pet.self, inMemory: true)
}
