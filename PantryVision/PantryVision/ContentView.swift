import SwiftUI
import PhotosUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PantryVisionTheme.background.ignoresSafeArea()
                HomeView()
            }
        }
    }
}

private struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PantryVision")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(PantryVisionTheme.textPrimary)

                    Text("Snap your fridge. Build your list. Upgrade your meals.")
                        .font(.subheadline)
                        .foregroundStyle(PantryVisionTheme.textSecondary)

                    HStack(spacing: 10) {
                        Label("Privacy-first scanning", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(PantryVisionTheme.textSecondary)
                        Spacer(minLength: 0)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(PantryVisionTheme.accent.opacity(0.15), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 10)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink(destination: ScanTabView()) {
                        HomeTile(title: "Scan", systemImage: "camera", tint: PantryVisionTheme.accent)
                    }
                    .buttonStyle(TileButtonStyle(tint: PantryVisionTheme.accent))

                    NavigationLink(destination: GroceryListTabView()) {
                        HomeTile(title: "Groceries", systemImage: "list.bullet", tint: PantryVisionTheme.accent2)
                    }
                    .buttonStyle(TileButtonStyle(tint: PantryVisionTheme.accent2))

                    NavigationLink(destination: RecipesTabView()) {
                        HomeTile(title: "Recipes", systemImage: "book", tint: PantryVisionTheme.accent)
                    }
                    .buttonStyle(TileButtonStyle(tint: PantryVisionTheme.accent))

                    NavigationLink(destination: SavingsTabView()) {
                        HomeTile(title: "Savings", systemImage: "chart.line.uptrend.xyaxis", tint: PantryVisionTheme.accent2)
                    }
                    .buttonStyle(TileButtonStyle(tint: PantryVisionTheme.accent2))

                    NavigationLink(destination: ReceiptScanView()) {
                        HomeTile(title: "Receipt", systemImage: "doc.badge.plus", tint: PantryVisionTheme.accent2)
                    }
                    .buttonStyle(TileButtonStyle(tint: PantryVisionTheme.accent2))
                }

                Text("Tip: add items via Scan, then use Receipt scanning to track what you actually bought.")
                    .font(.subheadline)
                    .foregroundStyle(PantryVisionTheme.textSecondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

private struct HomeTile: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(PantryVisionTheme.textPrimary)
                Text("Open")
                    .font(.caption)
                    .foregroundStyle(PantryVisionTheme.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.18), Color.white.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.001))
                .shadow(color: tint.opacity(0.18), radius: 10, x: 0, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct TileButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .offset(y: configuration.isPressed ? 1 : 0)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.10 : 0.0))
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

private struct ScanTabView: View {
    @EnvironmentObject private var groceryStore: GroceryListStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var suggestedItems: [MappedGroceryItem] = []
    @State private var errorMessage: String?

    private let analyzer = PhotoAnalysisService()

    var body: some View {
        Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Snap your fridge, build your list")
                            .font(.headline)
                        Text("Upgrade your meals")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Fridge / Pantry Photo") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose photo", systemImage: "photo")
                    }
                    .disabled(isAnalyzing)

                    Button {
                        Task { await analyze() }
                    } label: {
                        if isAnalyzing {
                            ProgressView()
                        } else {
                            Text("Analyze Photo")
                        }
                    }
                    .disabled(pickerItem == nil || isAnalyzing)
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if !suggestedItems.isEmpty {
                    Section("Suggested Missing Items") {
                        ForEach(Array(suggestedItems.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Button("Add") {
                                    groceryStore.addItem(
                                        name: item.name,
                                        estimatedUnitPrice: item.estimatedUnitPrice
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Button("Add All to Grocery List") {
                            for item in suggestedItems {
                                groceryStore.addItem(
                                    name: item.name,
                                    estimatedUnitPrice: item.estimatedUnitPrice
                                )
                            }
                            suggestedItems = []
                        }
                        .disabled(isAnalyzing)
                    }
                }
        }
        .navigationTitle("Scan")
    }

    private func analyze() async {
        errorMessage = nil
        suggestedItems = []
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            guard let pickerItem else { return }
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else { return }
            guard let image = UIImage(data: data) else { return }
            let result = try await analyzer.analyzeFridgePhoto(image)
            switch result {
            case .items(let items):
                suggestedItems = items
            }
        } catch {
            errorMessage = "Could not analyze photo yet. Please try again."
        }
    }
}

private struct GroceryListTabView: View {
    @EnvironmentObject private var groceryStore: GroceryListStore
    @State private var showAddItem = false
    @State private var showAllItems = true
    @State private var showFamilySetup = false
    @State private var showStorePicker = false
    @State private var showReceiptScanner = false
    @State private var showIdentitySetup = false

    private var formatMoney: (Double) -> String = { value in
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private var purchaseNudges: [String] {
        let now = Date()
        let nudges: [String] = groceryStore.items.compactMap { item in
            guard !item.isCrossedOff else { return nil } // only nudge unpurchased items
            guard let last = item.lastPurchasedAt else { return nil }
            guard item.purchaseIntervalsCount > 0 else { return nil }

            let avgDays = item.purchaseIntervalsSumDays / Double(item.purchaseIntervalsCount)
            let daysSince = now.timeIntervalSince(last) / (60 * 60 * 24)
            guard daysSince >= (avgDays + 1) else { return nil }

            let avgRounded = max(1, Int(avgDays.rounded()))
            let daysRounded = max(0, Int(daysSince.rounded()))
            return "You usually buy \(item.name) about every \(avgRounded) days. It's been \(daysRounded) days."
        }
        return nudges.prefix(3).map { $0 }
    }

    private var visibleItems: [GroceryItem] {
        if showAllItems { return groceryStore.items }
        return groceryStore.items.filter { !$0.isCrossedOff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                if !purchaseNudges.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Helpful nudge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(purchaseNudges, id: \.self) { nudge in
                            Text(nudge)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Store: \(groceryStore.selectedStore.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Aisle hints are attached to each item.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showIdentitySetup = true
                    } label: {
                        Label("You: \(PantryVisionIdentity.displayName)", systemImage: "person.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.top, 4)

                if let syncFamilyId = groceryStore.syncFamilyId {
                    Text("Synced with family: \(syncFamilyId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        showFamilySetup = true
                    } label: {
                        Label("Connect Family (Spouse Sync)", systemImage: "person.2.fill")
                    }
                }

                HStack {
                    Text("Estimated total (missing items):")
                        .font(.subheadline)
                    Spacer()
                    Text(formatMoney(groceryStore.estimatedTotal))
                        .font(.headline)
                }

                Toggle("Show crossed off items", isOn: $showAllItems)

                if groceryStore.items.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "cart")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Your list is empty")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(visibleItems) { item in
                            GroceryRow(item: item) {
                                groceryStore.toggleCrossOff(item.id)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    groceryStore.removeItem(id: item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Grocery List")
            .background(PantryVisionTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddItem = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFamilySetup = true
                    } label: {
                        Label("Family", systemImage: "person.2.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showStorePicker = true
                    } label: {
                        Label("Store", systemImage: "building.2")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showReceiptScanner = true
                    } label: {
                        Label("Receipt", systemImage: "doc.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddItemSheet { name, quantity, price, note, healthTags in
                    groceryStore.addItem(
                        name: name,
                        quantity: quantity,
                        note: note,
                        estimatedUnitPrice: price,
                        healthTags: healthTags
                    )
                    showAddItem = false
                }
            }
            .sheet(isPresented: $showFamilySetup) {
                FamilySetupView()
            }
            .sheet(isPresented: $showStorePicker) {
                StorePickerView()
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScanView()
            }
            .sheet(isPresented: $showIdentitySetup) {
                IdentitySetupView()
            }
        }
    }

private struct GroceryRow: View {
    let item: GroceryItem
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggle) {
                Image(systemName: item.isCrossedOff ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCrossedOff ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isCrossedOff)

                Text("Added by \(item.addedBy) · \(relativeDateString(item.addedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if item.isCrossedOff {
                    let by = item.lastPurchasedBy ?? item.addedBy
                    let at = item.lastPurchasedAt ?? item.addedAt
                    Text("Bought by \(by) · \(relativeDateString(at))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not purchased yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let last = item.lastPurchasedAt {
                        Text("Last bought \(relativeDateString(last))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let aisle = item.aisleName, !aisle.isEmpty {
                    Text("Aisle: \(aisle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !item.healthTags.isEmpty {
                    Text("Benefits: \(item.healthTags.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let unit = item.estimatedUnitPrice {
                    let qty = item.quantity ?? 1
                    Text("Est. $\(unit, specifier: "%.2f") x \(qty) = $\(unit * Double(qty), specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onAdd: (_ name: String, _ quantity: Int?, _ price: Double?, _ note: String?, _ healthTags: [String]) -> Void

    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var includeQuantity: Bool = false
    @State private var estimatedPriceText: String = ""
    @State private var note: String = ""
    @State private var suggestedBenefits: [String] = []
    @State private var selectedBenefits: Set<String> = []

    private func suggestedBenefits(for rawName: String) -> [String] {
        let lower = rawName.lowercased()
        if lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }

        var results: [String] = []
        func add(_ tag: String) {
            if !results.contains(tag) { results.append(tag) }
        }

        // Light-weight heuristics for MVP (no network / no AI yet).
        if lower.contains("egg") {
            add("High Protein")
            add("Omega-3 / Healthy Fats")
        }
        if lower.contains("yogurt") || lower.contains("kefir") {
            add("Probiotics")
            add("Calcium Boost")
        }
        if lower.contains("milk") || lower.contains("cheese") {
            add("Calcium Boost")
        }
        if lower.contains("spinach") || lower.contains("lettuce") || lower.contains("kale") || lower.contains("broccoli") || lower.contains("zucchini") || lower.contains("cucumber") {
            add("Fiber Rich")
            add("Antioxidants")
            add("Vitamin-Rich")
        }
        if lower.contains("berries") || lower.contains("blueberry") || lower.contains("strawberry") || lower.contains("raspberry") {
            add("Antioxidants")
            add("Fiber Rich")
        }
        if lower.contains("beans") || lower.contains("lentil") || lower.contains("chickpea") {
            add("High Fiber")
            add("Plant Protein")
        }
        if lower.contains("chicken") || lower.contains("turkey") || lower.contains("tofu") || lower.contains("shrimp") || lower.contains("salmon") {
            add("High Protein")
        }
        if lower.contains("salmon") {
            add("Omega-3 / Healthy Fats")
        }
        if lower.contains("oat") || lower.contains("oats") || lower.contains("quinoa") {
            add("High Fiber")
            add("Heart Healthy")
        }
        if lower.contains("olive oil") || lower.contains("olive") {
            add("Heart Healthy")
            add("Antioxidants")
        }

        // Fallback for unknown items: keep it subtle.
        if results.isEmpty {
            add("Good for a balanced meal")
        }
        return results.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("e.g., Apples", text: $name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { newValue in
                            let next = suggestedBenefits(for: newValue)
                            suggestedBenefits = next
                            selectedBenefits = Set(next) // default ON for suggested benefits
                        }
                }

                Section("Quantity (optional)") {
                    Toggle("Add quantity", isOn: $includeQuantity)
                    if includeQuantity {
                        Stepper("Quantity: \(quantity)", value: $quantity, in: 1...100)
                    }
                }

                Section("Estimated Unit Price (optional)") {
                    TextField("e.g., 2.49", text: $estimatedPriceText)
                        .keyboardType(.decimalPad)
                }

                Section("Notes (optional)") {
                    TextField("e.g., bought last week, check expiration", text: $note, axis: .vertical)
                }

                Section("Health Benefits") {
                    if suggestedBenefits.isEmpty {
                        Text("Type an item to see suggested benefits.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(suggestedBenefits, id: \.self) { benefit in
                            Toggle(
                                benefit,
                                isOn: Binding(
                                    get: { selectedBenefits.contains(benefit) },
                                    set: { on in
                                        if on {
                                            selectedBenefits.insert(benefit)
                                        } else {
                                            selectedBenefits.remove(benefit)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else { return }

                        let q: Int? = includeQuantity ? quantity : nil
                        let price: Double? = Double(estimatedPriceText)
                        let n: String? = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
                        let tags = selectedBenefits.sorted()
                        onAdd(trimmedName, q, price, n, tags)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct RecipeMatch: Identifiable {
    let recipe: Recipe
    let missing: [String]
    var id: String { recipe.id }
}

private struct RecipesTabView: View {
    @EnvironmentObject private var groceryStore: GroceryListStore
    @State private var showOnlyTwoAway = true
    @State private var upgradeMessage: String?

    private var allRecipes: [Recipe] {
        [
            Recipe(id: "omelet", title: "Quick Veggie Omelet", ingredients: ["Eggs", "Spinach", "Onions"]),
            Recipe(id: "stirfry", title: "Easy Veggie Stir-Fry", ingredients: ["Onions", "Garlic", "Spinach", "Rice"]),
            Recipe(id: "pasta", title: "Creamy Garlic Pasta", ingredients: ["Pasta", "Garlic", "Cheese", "Butter"]),
            Recipe(id: "tacos", title: "Simple Pantry Tacos", ingredients: ["Tortillas", "Cheese", "Onions", "Salsa"]),
            Recipe(id: "salad", title: "Fresh Side Salad", ingredients: ["Lettuce", "Tomato", "Onions", "Olive Oil"])
        ]
    }

    private var ownedIngredientSet: Set<String> {
        Set(
            groceryStore.items
                .filter { $0.isCrossedOff }
                .map { normalizedIngredient($0.name) }
        )
    }

    private func normalizedIngredient(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lettersOnly = String(trimmed.filter { $0.isLetter })
        guard lettersOnly.count > 3 else { return lettersOnly }
        if lettersOnly.hasSuffix("s") {
            return String(lettersOnly.dropLast())
        }
        return lettersOnly
    }

    private func missingIngredients(for recipe: Recipe) -> [String] {
        recipe.ingredients.filter { ingredient in
            !ownedIngredientSet.contains(normalizedIngredient(ingredient))
        }
    }

    private var matches: [RecipeMatch] {
        allRecipes
            .map { recipe in
                RecipeMatch(recipe: recipe, missing: missingIngredients(for: recipe))
            }
            .sorted { lhs, rhs in
                // Closest recipes first.
                lhs.missing.count < rhs.missing.count
            }
    }

    private var recommended: [RecipeMatch] {
        matches.filter { $0.missing.count <= 2 }
    }

    private enum UpgradeKind {
        case veggies
        case protein
    }

    private func sneakyCandidates(missing: [String], kind: UpgradeKind) -> [String] {
        // MVP: rule-based "subtle upgrades" picked using what you DON'T have yet (missing ingredients).
        // This keeps suggestions context-aware without requiring AI yet.
        let missingSet = Set(missing.map { normalizedIngredient($0) })

        func hasAny(_ candidates: [String]) -> Bool {
            candidates.contains(where: { missingSet.contains($0) })
        }

        let veggieFallback = ["Spinach", "Bell pepper", "Mushrooms", "Zucchini", "Cherry tomatoes", "Broccoli"]
        let proteinFallback = ["Chicken", "Tofu", "Turkey", "Greek yogurt", "Eggs", "Shrimp"]

        switch kind {
        case .veggies:
            // If the base meal is carb-heavy, push more color + crunch.
            if hasAny(["pasta", "rice", "tortilla"]) {
                return ["Zucchini", "Cherry tomatoes", "Spinach", "Bell pepper"]
            }
            // If the base meal is protein-y, add mushrooms + greens.
            if hasAny(["chicken", "beef", "pork", "turkey", "tofu", "shrimp"]) {
                return ["Mushrooms", "Spinach", "Broccoli", "Snap peas"]
            }
            // If the base meal leans dairy/cheese, brighten with fresh produce.
            if hasAny(["cheese", "milk", "yogurt"]) {
                return ["Tomato", "Cucumber", "Bell pepper", "Onion"]
            }
            // If it's bean/legume based, add savory veg.
            if hasAny(["bean", "lentil"]) {
                return ["Onion", "Bell pepper", "Spinach", "Carrots"]
            }
            return veggieFallback
        case .protein:
            // If you're missing legumes, add a more substantial protein.
            if hasAny(["bean", "lentil"]) {
                return ["Chicken", "Turkey", "Tofu", "Greek yogurt"]
            }
            // If you're missing cheese/dairy, try lean proteins.
            if hasAny(["cheese", "milk", "yogurt"]) {
                return ["Turkey", "Chicken", "Ham", "Tofu"]
            }
            // If the meal is veggie-forward, add the easiest proteins.
            if hasAny(["spinach", "lettuce", "broccoli", "zucchini"]) {
                return ["Eggs", "Chicken", "Tofu", "Shrimp"]
            }
            // If it's carb-based, add protein that pairs well.
            if hasAny(["pasta", "rice", "tortilla"]) {
                return ["Chicken", "Salmon", "Tofu", "Greek yogurt"]
            }
            return proteinFallback
        }
    }

    private func sneak(kind: UpgradeKind, match: RecipeMatch) {
        let owned = ownedIngredientSet
        let recipeIngredientSet = Set(match.recipe.ingredients.map { normalizedIngredient($0) })

        let candidates = sneakyCandidates(missing: match.missing, kind: kind)
        let suggestions = candidates
            .filter { !owned.contains(normalizedIngredient($0)) }
            .filter { !recipeIngredientSet.contains(normalizedIngredient($0)) }
            .prefix(2)
            .map { $0 }

        guard !suggestions.isEmpty else {
            upgradeMessage = "You already have the upgrade ingredients."
            return
        }

        for item in suggestions {
            groceryStore.addItemIfMissing(name: item)
        }

        upgradeMessage = "Added: \(suggestions.joined(separator: ", "))"
    }

    var body: some View {
        List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Snap your fridge, build your list")
                            .font(.headline)
                        Text("Upgrade your meals")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sneak in upgrades") {
                    let bestMatch = matches.first

                    Button {
                        guard let bestMatch else { return }
                        sneak(kind: .veggies, match: bestMatch)
                    } label: {
                        Label("Sneak in veggies", systemImage: "leaf")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(bestMatch == nil)

                    Button {
                        guard let bestMatch else { return }
                        sneak(kind: .protein, match: bestMatch)
                    } label: {
                        Label("Sneak in protein", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .tint(PantryVisionTheme.accent2)
                    .buttonStyle(.borderedProminent)
                    .disabled(bestMatch == nil)
                }

                if let upgradeMessage {
                    Section("Added") {
                        Text(upgradeMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reverse Recipe Builder") {
                    if recommended.isEmpty {
                        Text("Add a couple items to your list (cross off after shopping) to unlock more recipes.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recommended) { match in
                            recipeCard(match: match)
                        }
                    }
                }

                if !showOnlyTwoAway {
                    Section("More ideas") {
                        ForEach(matches.filter { $0.missing.count > 2 }) { match in
                            recipeCard(match: match)
                        }
                    }
                }

                Section {
                    Toggle("Show recipes that are 0-2 items away only", isOn: $showOnlyTwoAway)
                }
            }
            .navigationTitle("Recipes")
        }
    }

    @ViewBuilder
    private func recipeCard(match: RecipeMatch) -> some View {
        RecipeCardView(match: match)
    }

private struct RecipeCardView: View {
    @EnvironmentObject private var groceryStore: GroceryListStore
    let match: RecipeMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.recipe.title)
                        .font(.headline)

                    if match.missing.isEmpty {
                        Text("All set. Ingredients ready!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You're \(match.missing.count) ingredients away from this meal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if !match.missing.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Missing:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(Array(match.missing.enumerated()), id: \.offset) { _, ingredient in
                        HStack {
                            Text(ingredient)
                                .font(.body)
                            Spacer()
                            if let aisle = groceryStore.aisleHint(for: ingredient) {
                                Text("Aisle: \(aisle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button {
                    for ingredient in match.missing {
                        groceryStore.addItemIfMissing(name: ingredient)
                    }
                } label: {
                    Label("Add missing to grocery list", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct Recipe: Identifiable, Equatable {
    let id: String
    let title: String
    let ingredients: [String]
}

private func relativeDateString(_ date: Date, reference: Date = Date()) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: reference)
}

private struct SavingsTabView: View {
    @EnvironmentObject private var groceryStore: GroceryListStore

    var body: some View {
        VStack(spacing: 16) {
            Text("Savings (MVP)")
                .font(.largeTitle)
                .padding(.top, 24)

            Text("Estimated grocery spend for missing items: \(formatMoney(groceryStore.estimatedTotal))")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Next: track waste + eating-out vs home cooking to show real dollar saved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("Savings")
    }

    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

