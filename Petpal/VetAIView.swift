// VetAIView.swift
// PawPal - AI Vet Chat Interface
 
import SwiftUI
 
struct VetAIView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chatManager = ChatManager()
    @AppStorage("petName") private var petName: String = "Your Pet"
    @AppStorage("petSpecies") private var petSpecies: String = "Dog"
    @AppStorage("petBreed") private var petBreed: String = ""
    @AppStorage("petWeight") private var petWeight: Double = 0.0
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @State private var messageText: String = ""
    @State private var showingAPISettings = false
    @FocusState private var isInputFocused: Bool
 
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color("BrandCream"), Color("BrandSoftBlue").opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
 
                VStack(spacing: 0) {
                    petContextBanner
 
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if chatManager.messages.isEmpty {
                                    emptyStateView
                                } else {
                                    ForEach(chatManager.messages) { message in
                                        MessageBubble(message: message)
                                            .id(message.id)
                                    }
                                }
 
                                if chatManager.isLoading {
                                    HStack {
                                        ProgressView()
                                            .tint(Color("BrandGreen"))
                                        Text("Thinking...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                            }
                            .padding()
                        }
                        .onChange(of: chatManager.messages.count) { _, _ in
                            if let lastMessage = chatManager.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
 
                    inputBar
                }
            }
            .navigationTitle("Ask the Vet AI")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAPISettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(chatManager.hasAPIKey ? Color("BrandGreen") : .secondary)
                    }
                }
            }
            .sheet(isPresented: $showingAPISettings) {
                APISettingsView(chatManager: chatManager)
            }
        }
    }
 
    private var petContextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color("BrandGreen"))
            VStack(alignment: .leading, spacing: 2) {
                Text("Chatting about: \(petName)")
                    .font(.caption)
                    .fontWeight(.semibold)
                HStack(spacing: 4) {
                    if !petBreed.isEmpty {
                        Text("\(petBreed) • \(petSpecies)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(petSpecies)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if petWeight > 0 {
                        Text("• \(Int(petWeight)) \(weightUnit)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color("BrandGreen").opacity(0.1))
    }
 
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope")
                .font(.system(size: 60))
                .foregroundStyle(Color("BrandGreen").opacity(0.5))
            Text("Ask Me Anything!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color("BrandDark"))
            Text("I'm here to help with questions about \(petName)'s health, behavior, nutrition, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
 
            VStack(alignment: .leading, spacing: 8) {
                Text("Try asking:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                SuggestedQuestionButton(text: "What should I feed my \(petSpecies.lowercased())?") {
                    messageText = "What should I feed my \(petSpecies.lowercased())?"
                }
                SuggestedQuestionButton(text: "How much exercise does a \(petSpecies.lowercased()) need?") {
                    messageText = "How much exercise does a \(petSpecies.lowercased()) need?"
                }
                SuggestedQuestionButton(text: "What vaccinations are important?") {
                    messageText = "What vaccinations are important?"
                }
            }
            .padding()
        }
        .padding(.top, 40)
    }
 
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about \(petName)...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isInputFocused)
                .lineLimit(1...5)
 
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .secondary
                            : Color("BrandGreen")
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isLoading)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
 
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !chatManager.isLoading else { return }
 
        var petContext = petBreed.isEmpty ? "\(petSpecies)" : "\(petBreed) \(petSpecies)"
        if petWeight > 0 {
            petContext += " weighing \(Int(petWeight)) \(weightUnit)"
        }
        chatManager.sendMessage(text, petContext: "The user has a \(petContext) named \(petName).")
        messageText = ""
        isInputFocused = false
    }
}
 
// MARK: - API Settings View
 
struct APISettingsView: View {
    var chatManager: ChatManager
    @Environment(\.dismiss) private var dismiss
    @State private var tempClaudeKey: String = ""
    @State private var tempGeminiKey: String = ""
    @State private var tempGroqKey: String = ""
    @State private var tempOpenAIKey: String = ""
    @State private var selectedProvider: AIProvider = .groq
 
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("AI Provider", selection: $selectedProvider) {
                        Label("Groq (FREE!)", systemImage: "bolt.fill").tag(AIProvider.groq)
                        Label("OpenAI", systemImage: "brain").tag(AIProvider.openai)
                        Label("Claude", systemImage: "sparkles").tag(AIProvider.claude)
                        Label("Gemini", systemImage: "star.fill").tag(AIProvider.gemini)
                    }
                } header: {
                    Text("Choose Your AI")
                } footer: {
                    Text("Groq is FREE and super fast! No credit card required.")
                }
 
                if selectedProvider == .groq {
                    Section {
                        SecureField("API Key", text: $tempGroqKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Groq API Key")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get your FREE API key at console.groq.com")
                            if !chatManager.groqAPIKey.isEmpty {
                                Label("Key saved ✓", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                } else if selectedProvider == .openai {
                    Section {
                        SecureField("API Key", text: $tempOpenAIKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("OpenAI API Key")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get your API key at platform.openai.com")
                            if !chatManager.openaiAPIKey.isEmpty {
                                Label("Key saved ✓", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                } else if selectedProvider == .claude {
                    Section {
                        SecureField("API Key", text: $tempClaudeKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Claude API Key")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get your API key at console.anthropic.com")
                            if !chatManager.claudeAPIKey.isEmpty {
                                Label("Key saved ✓", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    Section {
                        SecureField("API Key", text: $tempGeminiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Gemini API Key")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get your FREE API key at ai.google.dev")
                            if !chatManager.geminiAPIKey.isEmpty {
                                Label("Key saved ✓", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        chatManager.selectedProvider = selectedProvider
                        switch selectedProvider {
                        case .claude: chatManager.claudeAPIKey = tempClaudeKey
                        case .gemini: chatManager.geminiAPIKey = tempGeminiKey
                        case .groq: chatManager.groqAPIKey = tempGroqKey
                        case .openai: chatManager.openaiAPIKey = tempOpenAIKey
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedProvider = chatManager.selectedProvider
                tempClaudeKey = chatManager.claudeAPIKey
                tempGeminiKey = chatManager.geminiAPIKey
                tempGroqKey = chatManager.groqAPIKey
                tempOpenAIKey = chatManager.openaiAPIKey
            }
        }
    }
}
 
// MARK: - Suggested Question Button
 
struct SuggestedQuestionButton: View {
    let text: String
    let action: () -> Void
 
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "bubble.left.fill")
                    .font(.caption)
                    .foregroundStyle(Color("BrandGreen"))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color("BrandDark"))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
 
// MARK: - Message Bubble
 
struct MessageBubble: View {
    let message: ChatMessage
 
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer() }
 
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? .white : Color("BrandDark"))
                    .padding(12)
                    .background(
                        message.role == .user
                            ? Color("BrandGreen")
                            : Color(.systemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
 
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
 
            if message.role == .assistant { Spacer() }
        }
    }
}
 
// MARK: - Chat Manager
 
enum AIProvider: String, Codable {
    case claude, gemini, groq, openai
}
 
@Observable
class ChatManager {
    var messages: [ChatMessage] = []
    var isLoading: Bool = false
 
    var selectedProvider: AIProvider = AIProvider(
        rawValue: UserDefaults.standard.string(forKey: "ai_provider") ?? "groq"
    ) ?? .groq {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "ai_provider") }
    }
 
    var claudeAPIKey: String = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? "" {
        didSet { UserDefaults.standard.set(claudeAPIKey, forKey: "anthropic_api_key") }
    }
 
    var geminiAPIKey: String = UserDefaults.standard.string(forKey: "gemini_api_key") ?? "" {
        didSet { UserDefaults.standard.set(geminiAPIKey, forKey: "gemini_api_key") }
    }
 
    var groqAPIKey: String = UserDefaults.standard.string(forKey: "groq_api_key") ?? "" {
        didSet { UserDefaults.standard.set(groqAPIKey, forKey: "groq_api_key") }
    }
 
    var openaiAPIKey: String = UserDefaults.standard.string(forKey: "openai_api_key") ?? "" {
        didSet { UserDefaults.standard.set(openaiAPIKey, forKey: "openai_api_key") }
    }
 
    var hasAPIKey: Bool {
        switch selectedProvider {
        case .claude: return !claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .gemini: return !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .groq: return !groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openai: return !openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
 
    func sendMessage(_ content: String, petContext: String) {
        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        Task { await fetchAIResponse(petContext: petContext) }
    }
 
    @MainActor
    private func fetchAIResponse(petContext: String) async {
        isLoading = true
        defer { isLoading = false }
 
        guard hasAPIKey else {
            let name: String
            switch selectedProvider {
            case .claude: name = "Claude"
            case .gemini: name = "Gemini"
            case .groq: name = "Groq"
            case .openai: name = "OpenAI"
            }
            messages.append(ChatMessage(role: .assistant, content: "⚠️ Please set your \(name) API key. Tap the gear icon in the top right."))
            return
        }
 
        do {
            let response: String
            switch selectedProvider {
            case .claude: response = try await callClaudeAPI(petContext: petContext)
            case .gemini: response = try await callGeminiAPI(petContext: petContext)
            case .groq:   response = try await callGroqAPI(petContext: petContext)
            case .openai: response = try await callOpenAIAPI(petContext: petContext)
            }
            messages.append(ChatMessage(role: .assistant, content: response))
        } catch {
            messages.append(ChatMessage(role: .assistant, content: "I'm sorry, I encountered an error: \(error.localizedDescription)\n\nPlease check your API key and internet connection."))
        }
    }
 
    private func systemPrompt(petContext: String) -> String {
        """
        You are a knowledgeable and compassionate veterinary AI assistant. \(petContext)
        
        Provide helpful, accurate information about pet health, nutrition, behavior, and care. Always remind users to consult with a licensed veterinarian for serious health concerns or emergencies.
        
        Be warm, friendly, and supportive. Use clear, accessible language.
        """
    }
 
    private func callClaudeAPI(petContext: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
 
        let conversationMessages = messages.map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }
        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 1024,
            "system": systemPrompt(petContext: petContext),
            "messages": conversationMessages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
 
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ChatError.apiError("HTTP error")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw ChatError.invalidResponse
        }
        return text
    }
 
    private func callGeminiAPI(petContext: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(geminiAPIKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
 
        var contents: [[String: Any]] = []
        for (index, message) in messages.enumerated() {
            var text = message.content
            if index == 0 && message.role == .user { text = systemPrompt(petContext: petContext) + text }
            contents.append(["role": message.role == .user ? "user" : "model", "parts": [["text": text]]])
        }
 
        let body: [String: Any] = ["contents": contents, "generationConfig": ["temperature": 0.7, "maxOutputTokens": 1024]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
 
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw ChatError.apiError("HTTP error") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { throw ChatError.invalidResponse }
        return text
    }
 
    private func callGroqAPI(petContext: String) async throws -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
 
        var apiMessages: [[String: Any]] = [["role": "system", "content": systemPrompt(petContext: petContext)]]
        apiMessages += messages.map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }
 
        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 1024
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
 
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let msg = error["message"] as? String { throw ChatError.apiError(msg) }
            throw ChatError.apiError("HTTP error")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else { throw ChatError.invalidResponse }
        return text
    }
 
    private func callOpenAIAPI(petContext: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
 
        var apiMessages: [[String: Any]] = [["role": "system", "content": systemPrompt(petContext: petContext)]]
        apiMessages += messages.map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }
 
        let body: [String: Any] = ["model": "gpt-3.5-turbo", "messages": apiMessages, "temperature": 0.7, "max_tokens": 1024]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
 
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw ChatError.apiError("HTTP error") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else { throw ChatError.invalidResponse }
        return text
    }
}
 
// MARK: - Models
 
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()
}
 
enum MessageRole {
    case user, assistant
}
 
enum ChatError: LocalizedError {
    case invalidResponse
    case apiError(String)
 
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from API"
        case .apiError(let message): return message
        }
    }
}
 
#Preview {
    VetAIView()
}
