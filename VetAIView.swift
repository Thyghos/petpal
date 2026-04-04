// VetAIView - AI Vet Assistant (Anthropic and/or free-tier Gemini from Info.plist)

import SwiftUI
import SwiftData
import Combine
#if os(iOS)
import StoreKit
#endif

struct VetAIView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("petName") private var petName: String = "Your Pet"
    @AppStorage("petSpecies") private var petSpecies: String = "Dog"
    @AppStorage("petBreed") private var petBreed: String = ""
    @AppStorage("petWeight") private var petWeight: Double = 0.0
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

    @Query(sort: \Pet.name) private var swiftDataPets: [Pet]
    @Query(sort: \VetVisitLog.visitDate, order: .reverse) private var vetVisits: [VetVisitLog]
    @Query(sort: \PetInsuranceInfo.providerName) private var insurancePolicies: [PetInsuranceInfo]
    @Query(sort: \PetReminder.nextDueDate) private var petReminders: [PetReminder]
    @Query private var emergencyProfiles: [EmergencyProfile]
    @Query private var petSitterInstructions: [PetSitterInstructions]
    @Query private var recordAttachments: [PetRecordAttachment]

    private var scopedPetId: UUID? {
        FeaturePetScope.resolvedPetId(pets: swiftDataPets)
    }

    /// Profile fields for prompts: resolved SwiftData pet when available, else legacy @AppStorage.
    private var contextProfile: (name: String, species: String, breed: String, weight: Double, unit: String) {
        if let id = scopedPetId, let p = swiftDataPets.first(where: { $0.id == id }) {
            let n = p.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return (n.isEmpty ? "Your Pet" : n, p.species, p.breed, p.weight, p.weightUnit)
        }
        return (petName, petSpecies, petBreed, petWeight, weightUnit)
    }

    private var petsForAIContext: [Pet] {
        guard let id = scopedPetId, let p = swiftDataPets.first(where: { $0.id == id }) else { return [] }
        return [p]
    }
    
    private var scopedVisits: [VetVisitLog] {
        guard let sid = scopedPetId else { return [] }
        return vetVisits.filter { PetRecordFilter.matches($0.petId, selectedPetId: sid) }
    }
    private var scopedPolicies: [PetInsuranceInfo] {
        insurancePolicies.filter { PetRecordFilter.matches($0.petId, selectedPetId: scopedPetId) }
    }
    private var scopedReminders: [PetReminder] {
        petReminders.filter { PetRecordFilter.matches($0.petId, selectedPetId: scopedPetId) }
    }
    private var scopedEmergencyProfiles: [EmergencyProfile] {
        guard let sid = scopedPetId else { return [] }
        return emergencyProfiles.filter {
            guard let lid = $0.linkedPetId else { return false }
            return lid == sid
        }
    }
    private var scopedSitterNotes: [PetSitterInstructions] {
        petSitterInstructions.filter { PetRecordFilter.matches($0.petId, selectedPetId: scopedPetId) }
    }

    @State private var messages: [AIMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showingPlanSheet = false

    @AppStorage("aiVetPlanTier") private var planTierRaw: String = AIVetPlanTier.free.rawValue
    @AppStorage("aiVetUsageCount") private var monthlyUsageCount: Int = 0
    @AppStorage("aiVetUsageMonth") private var usageMonthKey: String = ""
    @AppStorage("aiVetBonusCredits") private var bonusCredits: Int = 0

    private var currentPlan: AIVetPlanTier {
        AIVetPlanTier(rawValue: planTierRaw) ?? .free
    }

    private var remainingThisMonth: Int {
        max(currentPlan.monthlyLimit - monthlyUsageCount, 0) + bonusCredits
    }

    private var providerStatusText: String {
        "Plan: \(currentPlan.displayName) • \(remainingThisMonth) left this month"
    }

    var body: some View {
        NavigationStack {
            chatView
        }
    }
    
    // MARK: - Chat View
    
    private var chatView: some View {
        VStack(spacing: 0) {
            FeaturePetScopeHeader(pets: swiftDataPets)
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("AI is thinking...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack(spacing: 12) {
                TextField("Ask about \(contextProfile.name)'s health...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            inputText.isEmpty ? .gray : Color("BrandGreen")
                        )
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color("BrandCream"), Color("BrandSoftBlue").opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("AI Vet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("AI Vet")
                        .font(.headline)
                    Text(providerStatusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 14) {
                    Button {
                        showingPlanSheet = true
                    } label: {
                        Label("Plan", systemImage: "creditcard")
                    }
                    Button {
                        messages.removeAll()
                        loadWelcomeMessage()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
        }
        .onAppear {
            resetMonthlyUsageIfNeeded()
            if messages.isEmpty {
                loadWelcomeMessage()
            }
        }
        .sheet(isPresented: $showingPlanSheet) {
            AIVetPlanSheet(
                bonusCredits: $bonusCredits,
                monthlyUsageCount: monthlyUsageCount
            )
        }
    }
    
    // MARK: - Functions
    
    private func loadWelcomeMessage() {
        let providerLine = "Powered by Petpal AI. "
        let hasRecords = !scopedVisits.isEmpty || !scopedPolicies.isEmpty
            || !scopedReminders.isEmpty || !scopedEmergencyProfiles.isEmpty || !scopedSitterNotes.isEmpty
        let recordsLine = hasRecords
            ? " I use the health history, reminders, and notes you’ve saved in Petpal to tailor answers—attachment files are listed but not read by the AI.\n\n"
            : " Add visit history and notes in Petpal and I’ll use them in future replies.\n\n"
        messages = [
            AIMessage(
                role: .assistant,
                content: "Hello! I'm your AI veterinary assistant. \(providerLine)I'm here to help with questions about \(contextProfile.name)'s health and care.\(recordsLine)⚠️ Remember: I provide general information only. For emergencies or serious concerns, contact a licensed veterinarian immediately.\n\nYou have \(remainingThisMonth) replies left this month on the \(currentPlan.displayName) plan."
            )
        ]
    }
    
    private func sendMessage() {
        resetMonthlyUsageIfNeeded()
        guard remainingThisMonth > 0 else {
            messages.append(AIMessage(role: .assistant, content: "You’ve reached your AI Vet limit for the \(currentPlan.displayName) plan. Upgrade your plan or grab a top-up (10 replies for $0.99) to keep chatting."))
            showingPlanSheet = true
            return
        }
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        
        messages.append(AIMessage(role: .user, content: userText))
        inputText = ""
        isLoading = true
        
        let cp = contextProfile
        let petContext = VetAIPetContextBuilder.buildContext(
            profileName: cp.name,
            profileSpecies: cp.species,
            profileBreed: cp.breed,
            profileWeight: cp.weight,
            weightUnit: cp.unit,
            pets: petsForAIContext,
            visits: scopedVisits,
            policies: scopedPolicies,
            reminders: scopedReminders,
            emergencyProfiles: scopedEmergencyProfiles,
            petSitterInstructions: scopedSitterNotes,
            attachments: recordAttachments
        )

        Task {
            do {
                let response: String
                if let proxyURL = APIConfiguration.vetAIProxyURL {
                    response = try await callProxyAPI(
                        conversation: messages,
                        proxyURLString: proxyURL,
                        token: APIConfiguration.vetAIProxyToken,
                        petContext: petContext
                    )
                } else if let key = APIConfiguration.anthropicAPIKey {
                    response = try await callClaudeAPI(conversation: messages, apiKey: key, petContext: petContext)
                } else if let key = APIConfiguration.geminiAPIKey {
                    response = try await callGeminiAPI(conversation: messages, apiKey: key, petContext: petContext)
                } else {
                    response = offlineGuidance(for: userText)
                }
                incrementUsage()
                messages.append(AIMessage(role: .assistant, content: response))
            } catch {
                messages.append(AIMessage(role: .assistant, content: "Sorry, I encountered an error: \(error.localizedDescription). Please try again."))
            }
            isLoading = false
        }
    }

    private func resetMonthlyUsageIfNeeded() {
        let key = Self.currentMonthKey()
        if usageMonthKey != key {
            usageMonthKey = key
            monthlyUsageCount = 0
        }
    }

    private func incrementUsage() {
        let planRemaining = max(currentPlan.monthlyLimit - monthlyUsageCount, 0)
        if planRemaining > 0 {
            monthlyUsageCount += 1
        } else if bonusCredits > 0 {
            bonusCredits -= 1
        }
    }

    private static func currentMonthKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private func offlineGuidance(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("emergency") || lower.contains("poison") || lower.contains("choking") || lower.contains("not breathing") {
            return "If this might be an emergency, contact your nearest emergency vet or animal poison control now. This app cannot triage emergencies.\n\nU.S. poison hotline (example): ASPCA Animal Poison Control (fee may apply) — search for the current number. When in doubt, go to an emergency clinic."
        }
        if lower.contains("vomit") || lower.contains("diarrhea") {
            return "Mild stomach upset can happen, but repeated vomiting, blood, lethargy, or refusal to drink needs a vet the same day. Offer small amounts of water; avoid new foods or treats until \(contextProfile.name) is stable."
        }
        if lower.contains("food") || lower.contains("eat") || lower.contains("toxic") {
            return "Many human foods are toxic to pets (e.g. chocolate, grapes, onions, xylitol). When unsure, don’t feed it and ask your vet."
        }
        return "I’m running in offline mode. Until then: keep \(contextProfile.name) on their regular diet, fresh water, and schedule routine care with a licensed veterinarian for any ongoing concerns."
    }

    /// Drops the initial welcome bubble so the API conversation starts with a `user` turn.
    private func trimmedConversationForAPI(_ messages: [AIMessage]) -> [AIMessage] {
        var slice = messages
        while let first = slice.first, first.role == .assistant {
            slice = Array(slice.dropFirst())
        }
        return slice
    }

    private func callClaudeAPI(conversation messages: [AIMessage], apiKey: String, petContext: String) async throws -> String {
        let cp = contextProfile
        let trimmed = trimmedConversationForAPI(messages)
        let anthropicMessages: [[String: Any]] = trimmed.map { msg in
            let role = msg.role == .user ? "user" : "assistant"
            return ["role": role, "content": msg.content]
        }
        guard !anthropicMessages.isEmpty else {
            throw NSError(domain: "VetAI", code: -10, userInfo: [NSLocalizedDescriptionKey: "No messages to send to Claude."])
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let systemPrompt = Self.systemPrompt(petSpecies: cp.species, petName: cp.name, petContext: petContext)

        // Sonnet 4 (replaces retired claude-3-5-sonnet-20241022). List: https://docs.anthropic.com/en/docs/about-claude/models
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": anthropicMessages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = parseClaudeErrorMessage(data) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "VetAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "VetAI", code: -11, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON from Claude"])
        }

        if let errMsg = parseClaudeErrorMessage(data) {
            throw NSError(domain: "VetAI", code: -12, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }

        if let content = json["content"] as? [[String: Any]],
           let firstContent = content.first,
           let text = firstContent["text"] as? String {
            return text
        }

        let snippet = String(data: data, encoding: .utf8) ?? ""
        throw NSError(domain: "VetAI", code: -13, userInfo: [NSLocalizedDescriptionKey: "Unexpected Claude response: \(snippet.prefix(280))"])
    }

    private func parseClaudeErrorMessage(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = json["error"] as? [String: Any], let message = err["message"] as? String {
            return message
        }
        return nil
    }

    /// Builds Gemini `contents` from chat history (drops leading assistant-only welcome so the first turn is `user`).
    private func geminiContents(from messages: [AIMessage]) -> [[String: Any]] {
        let slice = trimmedConversationForAPI(messages)
        return slice.map { msg in
            let role = msg.role == .user ? "user" : "model"
            return [
                "role": role,
                "parts": [["text": msg.content]]
            ] as [String: Any]
        }
    }

    /// Shared system instructions for Claude and Gemini (includes Petpal record summary when present).
    private static func systemPrompt(petSpecies: String, petName: String, petContext: String) -> String {
        let recordsSection: String
        let trimmed = petContext.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            recordsSection = """

            The owner has not entered detailed Petpal records yet (or none are available). Rely on the pet name and species above; ask concise follow-up questions when specifics matter.
            """
        } else {
            recordsSection = """

            ---
            Petpal app data (owner-entered text and metadata). Use this to personalize guidance for \(petName). Rules:
            - Treat this as the owner's self-reported information; it may be incomplete or outdated.
            - Do not invent clinical facts that are not implied by this data or the conversation.
            - If something important is missing, say so and suggest confirming with their veterinarian.
            - Photos and PDFs attached to records are only counted below—their contents are NOT visible to you. If the user refers to a file, ask them to summarize key text (e.g. lab values, vaccine names) or type details into Notes in the app.

            \(trimmed)
            """
        }

        return """
        You are a helpful veterinary information assistant. You are helping with a \(petSpecies) named \(petName). \
        Give accurate, empathetic general guidance. Always encourage consulting a licensed veterinarian for diagnosis, \
        treatment, prescription decisions, and emergencies. Be warm and clear.\(recordsSection)
        """
    }

    private func callProxyAPI(
        conversation messages: [AIMessage],
        proxyURLString: String,
        token: String?,
        petContext: String
    ) async throws -> String {
        let cp = contextProfile
        guard let url = URL(string: proxyURLString) else {
            throw NSError(domain: "VetAI", code: -20, userInfo: [NSLocalizedDescriptionKey: "Invalid proxy URL."])
        }

        let trimmed = trimmedConversationForAPI(messages)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "VetAI", code: -21, userInfo: [NSLocalizedDescriptionKey: "No messages to send."])
        }

        let payloadMessages: [[String: String]] = trimmed.map { msg in
            [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content
            ]
        }

        let body: [String: Any] = [
            "messages": payloadMessages,
            "petName": cp.name,
            "petSpecies": cp.species,
            "petContext": petContext
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "VetAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reply = json["reply"] as? String,
              !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "VetAI", code: -22, userInfo: [NSLocalizedDescriptionKey: "Invalid proxy response."])
        }
        return reply
    }

    private func callGeminiAPI(conversation messages: [AIMessage], apiKey: String, petContext: String) async throws -> String {
        let cp = contextProfile
        // See https://ai.google.dev/gemini-api/docs/models — update if Google renames the model.
        let model = "gemini-2.0-flash"
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw NSError(domain: "VetAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"])
        }

        let systemPrompt = Self.systemPrompt(petSpecies: cp.species, petName: cp.name, petContext: petContext)

        let contents = geminiContents(from: messages)
        guard !contents.isEmpty else {
            throw NSError(domain: "VetAI", code: -4, userInfo: [NSLocalizedDescriptionKey: "No messages to send to Gemini."])
        }

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": contents,
            "generationConfig": [
                "maxOutputTokens": 1024,
                "temperature": 0.7
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = Self.parseGeminiErrorMessage(data) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "VetAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let root = json else {
            throw NSError(domain: "VetAI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON from Gemini"])
        }

        if let errMsg = Self.parseGeminiErrorMessage(data) {
            throw NSError(domain: "VetAI", code: -5, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }

        if let candidates = root["candidates"] as? [[String: Any]],
           let first = candidates.first,
           let content = first["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let part = parts.first,
           let text = part["text"] as? String {
            return text
        }

        if let feedback = root["promptFeedback"] as? [String: Any],
           let block = feedback["blockReason"] as? String {
            throw NSError(domain: "VetAI", code: -6, userInfo: [NSLocalizedDescriptionKey: "Request blocked (\(block)). Try rephrasing your question."])
        }

        let snippet = String(data: data, encoding: .utf8) ?? ""
        throw NSError(domain: "VetAI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unexpected Gemini response: \(snippet.prefix(280))"])
    }

    private static func parseGeminiErrorMessage(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = json["error"] as? [String: Any] else { return nil }
        if let message = err["message"] as? String { return message }
        if let status = err["status"] as? String { return status }
        return nil
    }
}

// MARK: - Top-Up Store (Consumable IAP)

#if os(iOS)
@MainActor
final class AIVetTopUpStore: ObservableObject {
    static let productID = "com.thyghos.petpalapp.aivet.topup"
    static let creditsPerTopUp = 10

    @Published private(set) var product: Product?
    @Published private(set) var isLoading = true
    @Published var purchaseError: String?
    @Published var showSuccess = false

    func loadProduct() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: [Self.productID])
            product = loaded.first
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else { return }
        purchaseError = nil
        showSuccess = false
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    let current = UserDefaults.standard.integer(forKey: "aiVetBonusCredits")
                    UserDefaults.standard.set(current + Self.creditsPerTopUp, forKey: "aiVetBonusCredits")
                    showSuccess = true
                case .unverified(_, let error):
                    purchaseError = error.localizedDescription
                }
            case .userCancelled: break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default: break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}
#endif

enum AIVetPlanTier: String, CaseIterable, Identifiable {
    case free
    case plus
    case pro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Plus"
        case .pro: return "Pro"
        }
    }

    var monthlyLimit: Int {
        switch self {
        case .free: return 5
        case .plus: return 75
        case .pro: return 250
        }
    }

    var priceLabel: String {
        switch self {
        case .free: return "$0"
        case .plus: return "$3.99 / month"
        case .pro: return "$9.99 / month"
        }
    }
}

struct AIVetPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Binding var bonusCredits: Int
    let monthlyUsageCount: Int

    #if os(iOS)
    @ObservedObject private var store = PetpalStore.shared
    @StateObject private var topUpStore = AIVetTopUpStore()
    @State private var isPurchasing = false
    #endif

    private var activeTier: AIVetPlanTier {
        #if os(iOS)
        store.activeTier
        #else
        .free
        #endif
    }

    private var remainingThisMonth: Int {
        max(activeTier.monthlyLimit - monthlyUsageCount, 0) + bonusCredits
    }

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                #if os(iOS)
                topUpSection
                #endif
                statusSection
                #if os(iOS)
                manageSection
                #endif
            }
            .navigationTitle("AI Vet Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .task {
            await store.loadProducts()
            await store.refreshSubscriptionStatus()
            await topUpStore.loadProduct()
        }
        .onChange(of: topUpStore.showSuccess) { _, success in
            if success {
                bonusCredits = UserDefaults.standard.integer(forKey: "aiVetBonusCredits")
            }
        }
        #endif
    }

    // MARK: - Subscription Tiers

    private var subscriptionSection: some View {
        Section("AI Vet plans") {
            ForEach(AIVetPlanTier.allCases) { tier in
                planRow(for: tier)
            }

            #if os(iOS)
            if let err = store.purchaseError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            #endif
        }
    }

    @ViewBuilder
    private func planRow(for tier: AIVetPlanTier) -> some View {
        let isCurrent = activeTier == tier

        Button {
            #if os(iOS)
            guard tier != .free, !isCurrent else { return }
            guard let product = store.product(for: tier) else { return }
            Task {
                isPurchasing = true
                await store.purchase(product)
                isPurchasing = false
            }
            #endif
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(tier.displayName) \u{2022} \(tier.monthlyLimit) replies/month")
                        .foregroundStyle(Color("BrandDark"))

                    #if os(iOS)
                    if let product = store.product(for: tier) {
                        Text("\(product.displayPrice) / month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(tier.priceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    #else
                    Text(tier.priceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #endif
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("BrandGreen"))
                }
            }
        }
        .disabled(isCurrent || isPurchasing)
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack {
                Label("Replies left", systemImage: "bubble.left.and.bubble.right")
                Spacer()
                Text("\(remainingThisMonth)")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandGreen"))
            }
            .font(.subheadline)

            if bonusCredits > 0 {
                HStack {
                    Label("Bonus credits", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(bonusCredits)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Manage Subscription

    #if os(iOS)
    @ViewBuilder
    private var manageSection: some View {
        if activeTier != .free {
            Section {
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                } label: {
                    Label("Manage Subscription", systemImage: "arrow.up.forward.app")
                }
            } footer: {
                Text("Cancel or change your plan anytime through Apple\u{2019}s subscription settings.")
            }
        }
    }
    #endif

    // MARK: - Top Up

    #if os(iOS)
    @ViewBuilder
    private var topUpSection: some View {
        Section("Top up") {
            if topUpStore.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading\u{2026}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let product = topUpStore.product {
                Button {
                    Task { await topUpStore.purchase() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("10 bonus replies")
                                .foregroundStyle(Color("BrandDark"))
                            Text("One-time purchase \u{2022} never expires")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(product.displayPrice)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("BrandGreen"))
                    }
                }

                if topUpStore.showSuccess {
                    Label("10 replies added!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color("BrandGreen"))
                }
            } else {
                Text("Top-ups aren\u{2019}t available yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let err = topUpStore.purchaseError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
    #endif
}

// MARK: - AI Message Model

struct AIMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    
    enum Role {
        case user
        case assistant
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? .white : Color("BrandDark"))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                message.role == .user ?
                                LinearGradient(
                                    colors: [Color("BrandGreen"), Color("BrandBlue")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.white, .white],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
}
