// VetAIView - AI Vet Assistant (Anthropic and/or free-tier Gemini from Info.plist)

import SwiftUI
import SwiftData

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
        ActivePetStorage.activePetUUID
    }
    
    private var scopedVisits: [VetVisitLog] {
        guard let sid = scopedPetId else {
            return vetVisits.filter { $0.petId == nil }
        }
        return vetVisits.filter { $0.petId == sid }
    }
    private var scopedPolicies: [PetInsuranceInfo] {
        insurancePolicies.filter { PetRecordFilter.matches($0.petId, selectedPetId: scopedPetId) }
    }
    private var scopedReminders: [PetReminder] {
        petReminders.filter { PetRecordFilter.matches($0.petId, selectedPetId: scopedPetId) }
    }
    private var scopedEmergencyProfiles: [EmergencyProfile] {
        guard let sid = scopedPetId else {
            return emergencyProfiles.filter { $0.linkedPetId == nil }
        }
        return emergencyProfiles.filter { $0.linkedPetId == sid }
    }
    private var scopedSitterNotes: [PetSitterInstructions] {
        petSitterInstructions.filter { PetRecordFilter.matches($0.petId, selectedPetId: scopedPetId) }
    }

    @State private var messages: [AIMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false

    /// Claude (Anthropic) is preferred when `Claude_API_Key` is set; Gemini is the fallback.
    private var activeProviderDescription: String {
        if APIConfiguration.anthropicAPIKey != nil { return "Claude" }
        if APIConfiguration.geminiAPIKey != nil { return "Gemini" }
        return ""
    }

    var body: some View {
        NavigationStack {
            chatView
        }
    }
    
    // MARK: - Chat View
    
    private var chatView: some View {
        VStack(spacing: 0) {
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
                TextField("Ask about \(petName)'s health...", text: $inputText, axis: .vertical)
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
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    messages.removeAll()
                    loadWelcomeMessage()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
        }
        .onAppear {
            if messages.isEmpty {
                loadWelcomeMessage()
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadWelcomeMessage() {
        let providerLine: String
        if !activeProviderDescription.isEmpty {
            providerLine = "Powered by \(activeProviderDescription). "
        } else {
            providerLine = "Add Claude_API_Key (or GEMINI_API_KEY) in Info.plist to enable AI replies. "
        }
        let hasRecords = !scopedVisits.isEmpty || !scopedPolicies.isEmpty
            || !scopedReminders.isEmpty || !scopedEmergencyProfiles.isEmpty || !scopedSitterNotes.isEmpty
            || !swiftDataPets.isEmpty
        let recordsLine = hasRecords
            ? " I use the health history, reminders, and notes you’ve saved in Petpal to tailor answers—attachment files are listed but not read by the AI.\n\n"
            : " Add visit history and notes in Petpal and I’ll use them in future replies.\n\n"
        messages = [
            AIMessage(
                role: .assistant,
                content: "Hello! I'm your AI veterinary assistant. \(providerLine)I'm here to help with questions about \(petName)'s health and care.\(recordsLine)⚠️ Remember: I provide general information only. For emergencies or serious concerns, contact a licensed veterinarian immediately."
            )
        ]
    }
    
    private func sendMessage() {
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        
        messages.append(AIMessage(role: .user, content: userText))
        inputText = ""
        isLoading = true
        
        let petContext = VetAIPetContextBuilder.buildContext(
            profileName: petName,
            profileSpecies: petSpecies,
            profileBreed: petBreed,
            profileWeight: petWeight,
            weightUnit: weightUnit,
            pets: swiftDataPets,
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
                if let key = APIConfiguration.anthropicAPIKey {
                    response = try await callClaudeAPI(conversation: messages, apiKey: key, petContext: petContext)
                } else if let key = APIConfiguration.geminiAPIKey {
                    response = try await callGeminiAPI(conversation: messages, apiKey: key, petContext: petContext)
                } else {
                    response = offlineGuidance(for: userText)
                }
                messages.append(AIMessage(role: .assistant, content: response))
            } catch {
                messages.append(AIMessage(role: .assistant, content: "Sorry, I encountered an error: \(error.localizedDescription). Please try again."))
            }
            isLoading = false
        }
    }

    private func offlineGuidance(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("emergency") || lower.contains("poison") || lower.contains("choking") || lower.contains("not breathing") {
            return "If this might be an emergency, contact your nearest emergency vet or animal poison control now. This app cannot triage emergencies.\n\nU.S. poison hotline (example): ASPCA Animal Poison Control (fee may apply) — search for the current number. When in doubt, go to an emergency clinic."
        }
        if lower.contains("vomit") || lower.contains("diarrhea") {
            return "Mild stomach upset can happen, but repeated vomiting, blood, lethargy, or refusal to drink needs a vet the same day. Offer small amounts of water; avoid new foods or treats until \(petName) is stable.\n\nTo get tailored AI answers, add **Claude_API_Key** (Anthropic) or **GEMINI_API_KEY** in your app’s Info.plist."
        }
        if lower.contains("food") || lower.contains("eat") || lower.contains("toxic") {
            return "Many human foods are toxic to pets (e.g. chocolate, grapes, onions, xylitol). When unsure, don’t feed it and ask your vet.\n\nFor interactive AI help, add **Claude_API_Key** or **GEMINI_API_KEY** in Info.plist — see APIConfiguration.swift."
        }
        return "I’m running in offline mode. Add **Claude_API_Key** (Anthropic) or **GEMINI_API_KEY** in Info.plist for full AI chat.\n\nUntil then: keep \(petName) on their regular diet, fresh water, and schedule routine care with a licensed veterinarian for any ongoing concerns."
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

        let systemPrompt = Self.systemPrompt(petSpecies: petSpecies, petName: petName, petContext: petContext)

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

    private func callGeminiAPI(conversation messages: [AIMessage], apiKey: String, petContext: String) async throws -> String {
        // See https://ai.google.dev/gemini-api/docs/models — update if Google renames the model.
        let model = "gemini-2.0-flash"
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw NSError(domain: "VetAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"])
        }

        let systemPrompt = Self.systemPrompt(petSpecies: petSpecies, petName: petName, petContext: petContext)

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
