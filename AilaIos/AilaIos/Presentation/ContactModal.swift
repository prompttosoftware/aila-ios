import SwiftUI

struct ContactModal: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var birthday = Date()
    @State private var personality = ""
    @State private var selectedVoiceGender = "female"
    @State private var targetLanguage = "es"
    @State private var errorMessage: String?
    
    private let knownLanguageCodes = ["es", "fr", "ja", "de", "en", "it", "ko", "pt", "ru", "zh"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                }
                
                Section("AI Settings") {
                    Picker("Voice", selection: $selectedVoiceGender) {
                        Text("Female").tag("female")
                        Text("Male").tag("male")
                        Text("Neutral").tag("neutral")
                    }
                    
                    Picker("Language", selection: $targetLanguage) {
                        ForEach(knownLanguageCodes, id: \.self) { code in
                            Text(languageName(from: code)).tag(code)
                        }
                    }
                    
                    TextEditor(text: $personality)
                        .frame(minHeight: 100)
                        .overlay(
                            GeometryReader { _ in
                                if self.personality.isEmpty {
                                    Text("E.g. Software engineer who loves hiking...")
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                }
                            }
                        )
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Button("Save") {
                    if validateInputs() {
                        ContactManager.shared.createOrUpdate(
                            name: name,
                            birthday: birthday,
                            personality: stripXSS(personality),
                            voice: selectedVoiceGender,
                            language: targetLanguage
                        )
                        isPresented = false
                    } else {
                        errorMessage = "Please fix errors"
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle("Contact Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func validateInputs() -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Validate birthday is a valid date (DatePicker ensures this, but check reasonable range)
        let calendar = Calendar.current
        let minDate = calendar.date(byAdding: .year, value: -120, to: Date())!
        let maxDate = Date()
        guard birthday >= minDate && birthday <= maxDate else {
            return false
        }
        
        // Personality can be empty, but if present, must be stripped
        // No further validation needed beyond XSS stripping
        
        guard knownLanguageCodes.contains(targetLanguage) else {
            return false
        }
        
        return true
    }
    
    private func languageName(from code: String) -> String {
        let languageMap: [String: String] = [
            "es": "Spanish",
            "fr": "French",
            "ja": "Japanese",
            "de": "German",
            "en": "English",
            "it": "Italian",
            "ko": "Korean",
            "pt": "Portuguese",
            "ru": "Russian",
            "zh": "Chinese"
        ]
        return languageMap[code] ?? code.uppercased()
    }
    
    private func stripXSS(_ input: String) -> String {
        var result = input
        
        // Simple XSS stripping: remove script tags and common injection patterns
        result = result.replacingOccurrences(of: "<script.*?</script>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "javascript:", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "onload=", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "onerror=", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<iframe.*?</iframe>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "<.*?>", with: "", options: .regularExpression) // Strip remaining HTML tags
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
