// HealthTipPreferences.swift
// Petpal - Health Tip Preferences and Service

import Foundation
import SwiftData

@Model
final class HealthTipPreferences {
    var id: UUID = UUID()
    var isEnabled: Bool = true
    var frequency: TipFrequency = TipFrequency.daily // daily or weekly
    var lastShownDate: Date?
    var currentTipIndex: Int = 0
    var petSpecies: String = "Dog" // To show species-specific tips
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        frequency: TipFrequency = TipFrequency.daily,
        lastShownDate: Date? = nil,
        currentTipIndex: Int = 0,
        petSpecies: String = "Dog"
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.frequency = frequency
        self.lastShownDate = lastShownDate
        self.currentTipIndex = currentTipIndex
        self.petSpecies = petSpecies
    }
}

enum TipFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case never = "Never"
}

// MARK: - Health Tip Model

struct HealthTip: Identifiable {
    let id = UUID()
    let species: [String] // ["Dog", "Cat", "All"]
    let title: String
    let tip: String
    let icon: String
    let category: TipCategory
}

enum TipCategory: String, CaseIterable {
    case nutrition = "Nutrition"
    case exercise = "Exercise"
    case grooming = "Grooming"
    case health = "Health"
    case safety = "Safety"
    case training = "Training"
    case dental = "Dental Care"
    case mental = "Mental Health"
}

// MARK: - Health Tip Service

class HealthTipService {
    
    static func shouldShowTip(preferences: HealthTipPreferences) -> Bool {
        guard preferences.isEnabled else { return false }
        if preferences.frequency == .never { return false }
        
        guard let lastShown = preferences.lastShownDate else {
            return true // Never shown before
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        switch preferences.frequency {
        case .daily:
            return !calendar.isDateInToday(lastShown)
        case .weekly:
            let daysSince = calendar.dateComponents([.day], from: lastShown, to: now).day ?? 0
            return daysSince >= 7
        case .never:
            return false
        }
    }
    
    static func getTipForToday(preferences: HealthTipPreferences) -> HealthTip {
        let tips = allTips.filter { tip in
            tip.species.contains(preferences.petSpecies) || tip.species.contains("All")
        }
        
        guard !tips.isEmpty else {
            return HealthTip(
                species: ["All"],
                title: "Welcome to Petpal!",
                tip: "Keep your pet's health records organized and accessible.",
                icon: "heart.fill",
                category: .health
            )
        }
        
        let index = preferences.currentTipIndex % tips.count
        return tips[index]
    }
    
    static func markTipAsShown(preferences: inout HealthTipPreferences) {
        preferences.lastShownDate = Date()
        preferences.currentTipIndex += 1
    }
    
    // MARK: - Health Tips Database
    
    static let allTips: [HealthTip] = [
        // Dog Tips
        HealthTip(
            species: ["Dog"],
            title: "Daily Exercise",
            tip: "Most dogs need at least 30-60 minutes of exercise daily. Regular walks help maintain a healthy weight and mental stimulation.",
            icon: "figure.walk",
            category: .exercise
        ),
        HealthTip(
            species: ["Dog"],
            title: "Dental Health",
            tip: "Brush your dog's teeth 2-3 times per week to prevent dental disease. Use dog-specific toothpaste only!",
            icon: "mouth.fill",
            category: .dental
        ),
        HealthTip(
            species: ["Dog"],
            title: "Hydration Matters",
            tip: "Dogs should drink about 1 ounce of water per pound of body weight daily. Always keep fresh water available.",
            icon: "drop.fill",
            category: .nutrition
        ),
        HealthTip(
            species: ["Dog"],
            title: "Toxic Foods Alert",
            tip: "Never feed your dog chocolate, grapes, raisins, onions, garlic, or xylitol. These can be deadly!",
            icon: "exclamationmark.triangle.fill",
            category: .safety
        ),
        HealthTip(
            species: ["Dog"],
            title: "Nail Trimming",
            tip: "Trim your dog's nails every 3-4 weeks. If you hear clicking on the floor, they're too long!",
            icon: "scissors",
            category: .grooming
        ),
        HealthTip(
            species: ["Dog"],
            title: "Mental Stimulation",
            tip: "Use puzzle toys and training sessions to keep your dog mentally sharp. A tired mind equals a happy dog!",
            icon: "brain.filled.head.profile",
            category: .mental
        ),
        HealthTip(
            species: ["Dog"],
            title: "Regular Vet Visits",
            tip: "Adult dogs should visit the vet at least once a year. Senior dogs (7+) should go twice yearly.",
            icon: "stethoscope",
            category: .health
        ),
        HealthTip(
            species: ["Dog"],
            title: "Socialization",
            tip: "Expose your dog to different people, animals, and environments regularly to build confidence and reduce anxiety.",
            icon: "person.2.fill",
            category: .training
        ),
        HealthTip(
            species: ["Dog"],
            title: "Grooming Routine",
            tip: "Brush your dog regularly based on coat type. Long-haired breeds need daily brushing to prevent matting.",
            icon: "comb.fill",
            category: .grooming
        ),
        HealthTip(
            species: ["Dog"],
            title: "Portion Control",
            tip: "Measure your dog's food to prevent obesity. Follow feeding guidelines based on weight and activity level.",
            icon: "chart.bar.fill",
            category: .nutrition
        ),
        
        // Cat Tips
        HealthTip(
            species: ["Cat"],
            title: "Litter Box Rule",
            tip: "Have one litter box per cat, plus one extra. Clean daily to keep your cat happy and your home fresh!",
            icon: "tray.fill",
            category: .health
        ),
        HealthTip(
            species: ["Cat"],
            title: "Water Intake",
            tip: "Cats often don't drink enough water. Try a cat water fountain to encourage hydration and prevent kidney issues.",
            icon: "drop.fill",
            category: .nutrition
        ),
        HealthTip(
            species: ["Cat"],
            title: "Indoor Enrichment",
            tip: "Indoor cats need vertical space! Cat trees and shelves let them climb and observe from high perches.",
            icon: "stairs",
            category: .mental
        ),
        HealthTip(
            species: ["Cat"],
            title: "Scratching Posts",
            tip: "Provide multiple scratching posts in different areas. Cats need to scratch to maintain healthy claws and mark territory.",
            icon: "hand.raised.fill",
            category: .grooming
        ),
        HealthTip(
            species: ["Cat"],
            title: "Play Time",
            tip: "Play with your cat for 10-15 minutes, 2-3 times daily. This prevents boredom and maintains a healthy weight.",
            icon: "sportscourt.fill",
            category: .exercise
        ),
        HealthTip(
            species: ["Cat"],
            title: "Dental Care",
            tip: "Dental disease affects 70% of cats by age 3. Annual dental check-ups are essential for cat health.",
            icon: "mouth.fill",
            category: .dental
        ),
        HealthTip(
            species: ["Cat"],
            title: "Toxic Plants",
            tip: "Lilies are extremely toxic to cats! Remove all lily plants from your home. Other dangers: aloe, ivy, and tulips.",
            icon: "leaf.fill",
            category: .safety
        ),
        HealthTip(
            species: ["Cat"],
            title: "Grooming Matters",
            tip: "Even short-haired cats benefit from weekly brushing. It reduces hairballs and strengthens your bond!",
            icon: "comb.fill",
            category: .grooming
        ),
        HealthTip(
            species: ["Cat"],
            title: "Stress Reduction",
            tip: "Cats thrive on routine. Keep feeding times, play sessions, and cleaning schedules consistent.",
            icon: "heart.circle.fill",
            category: .mental
        ),
        HealthTip(
            species: ["Cat"],
            title: "Weight Monitoring",
            tip: "Weigh your cat monthly. Even a pound of weight gain is significant for cats and can indicate health issues.",
            icon: "scalemass.fill",
            category: .health
        ),
        
        // Bird Tips
        HealthTip(
            species: ["Bird"],
            title: "Mental Stimulation",
            tip: "Birds are highly intelligent! Provide puzzle toys and rotate them weekly to prevent boredom.",
            icon: "brain.filled.head.profile",
            category: .mental
        ),
        HealthTip(
            species: ["Bird"],
            title: "Fresh Food Daily",
            tip: "Offer fresh fruits and vegetables daily. Remove uneaten fresh food after 2 hours to prevent spoilage.",
            icon: "leaf.fill",
            category: .nutrition
        ),
        HealthTip(
            species: ["Bird"],
            title: "Cage Hygiene",
            tip: "Clean food and water bowls daily. Deep clean the entire cage weekly to prevent bacterial growth.",
            icon: "sparkles",
            category: .health
        ),
        
        // Rabbit Tips
        HealthTip(
            species: ["Rabbit"],
            title: "Unlimited Hay",
            tip: "Rabbits need unlimited timothy hay! It's essential for digestive health and dental wear.",
            icon: "leaf.fill",
            category: .nutrition
        ),
        HealthTip(
            species: ["Rabbit"],
            title: "Exercise Time",
            tip: "Rabbits need at least 3-4 hours of supervised exercise outside their enclosure daily.",
            icon: "hare.fill",
            category: .exercise
        ),
        HealthTip(
            species: ["Rabbit"],
            title: "Bunny-Proof Your Home",
            tip: "Hide electrical cords and remove toxic plants. Rabbits love to chew everything!",
            icon: "exclamationmark.shield.fill",
            category: .safety
        ),
        
        // Universal Tips (All Pets)
        HealthTip(
            species: ["All"],
            title: "Emergency Preparedness",
            tip: "Keep a pet first-aid kit handy and know the location of your nearest 24/7 emergency vet.",
            icon: "cross.case.fill",
            category: .safety
        ),
        HealthTip(
            species: ["All"],
            title: "Identification",
            tip: "Ensure your pet has ID tags and a microchip. Update registration info if you move or change numbers!",
            icon: "qrcode",
            category: .safety
        ),
        HealthTip(
            species: ["All"],
            title: "Temperature Safety",
            tip: "Never leave pets in hot cars! Even on mild days, car temps can reach deadly levels in minutes.",
            icon: "thermometer.sun.fill",
            category: .safety
        ),
        HealthTip(
            species: ["All"],
            title: "Record Keeping",
            tip: "Keep all vet records, vaccination history, and medication info organized in one place (like Petpal!).",
            icon: "doc.text.fill",
            category: .health
        ),
        HealthTip(
            species: ["All"],
            title: "Quality Time",
            tip: "Spend dedicated one-on-one time with your pet daily. It strengthens your bond and improves their well-being.",
            icon: "heart.fill",
            category: .mental
        ),
        HealthTip(
            species: ["All"],
            title: "Watch for Changes",
            tip: "Monitor eating, drinking, and bathroom habits. Sudden changes can be early warning signs of illness.",
            icon: "eyes",
            category: .health
        ),
        HealthTip(
            species: ["All"],
            title: "Medication Safety",
            tip: "Never give human medications to pets without vet approval. Many common drugs are toxic to animals!",
            icon: "pills.fill",
            category: .safety
        ),
        HealthTip(
            species: ["All"],
            title: "Travel Preparation",
            tip: "Get your pet comfortable with carriers early. Practice short trips before long journeys.",
            icon: "airplane",
            category: .training
        ),
    ]
}
