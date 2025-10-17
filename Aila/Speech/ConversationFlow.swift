import AVFoundation
import Combine
import Foundation

@MainActor
class ConversationFlow: ObservableObject {
    static let shared = ConversationFlow()
    
    @Published var isActive = false
    @Published var activeContact: Contact?
    
    private var recorder: AVAudioRecorder?
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var consecutiveFailures = 0
    private let maxFailuresUntilFallback = 2
    private let userNativeLanguage = "en" // Assumed user's native language; replace with dynamic fetch if needed
    
    private var audioInputTask: Task<Void, Error>?
    
    private init() {}
    
    func startConversation(contact: Contact) {
        self.activeContact = contact
        self.isActive = true
        self.consecutiveFailures = 0
        Self.shared.objectWillChange.send()
        
        Task {
            guard let intro = await ContactManager.shared.generateRingingNarrative(for: contact) else {
                print("Failed to generate ringing narrative")
                return
            }
            
            let targetLanguage = contact.language ?? "en"
            await speak(text: intro, language: targetLanguage)
            beginListening()
        }
    }
    
    func endConversation() {
        stopRecording()
        audioInputTask?.cancel()
        audioInputTask = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        isActive = false
        activeContact = nil
        consecutiveFailures = 0
        ConversationFlow.shared.objectWillChange.send()
    }
    
    private func beginListening() {
        guard let contactLang = activeContact?.language else { return }
        
        Task {
            do {
                try startRecording()
                // Simulate periodic processing; in practice, this would use real-time audio buffers
                try await Task.sleep(nanoseconds: 3_000_000_000) // Wait 3s for user response
                stopRecording()
                
                // In a real app, recorded audio data would be passed here from the buffer
                // For now, simulate handling recorded data
                guard let audioURL = recorder?.url,
                      let audioData = try? Data(contentsOf: audioURL) else {
                    await handleMisunderstanding()
                    return
                }
                await handleUserSpeech(audioData)
            } catch {
                print("Failed to record or process audio: $error)")
                await handleMisunderstanding()
            }
        }
    }
    
    func handleUserSpeech(_ audio: Data) async {
        guard let transcript = await ASRProcessor.transcribe(audio),
              !transcript.isEmpty else {
            await handleMisunderstanding()
            return
        }
        
        // Log vocabulary from user utterance
        if let contactLang = activeContact?.language {
            VocabularyTracker.shared.processUtterance(transcript, language: contactLang)
        }
        
        // Build context with conversation history and current input
        let context = buildConversationHistory(with: transcript)
        let shouldUseNative = consecutiveFailures >= maxFailuresUntilFallback
        let targetLanguage = shouldUseNative ? userNativeLanguage : (activeContact?.language ?? "en")
        
        guard let response = await MLModelExecutor.shared.generateResponse(
            context: context,
            targetLanguage: targetLanguage
        ), !response.isEmpty else {
            await handleMisunderstanding()
            return
        }
        
        await speak(text: response, language: targetLanguage)
        addToHistory(userText: transcript, aiText: response)
    }
    
    private func handleMisunderstanding() async {
        consecutiveFailures += 1
        let useNative = consecutiveFailures >= maxFailuresUntilFallback
        let response = useNative
            ? "Let me repeat in your language. How are you?"
            : "I didn’t catch that. Did you mean 'yes' or 'no'?"
        
        let language = useNative ? userNativeLanguage : (activeContact?.language ?? "en")
        await speak(text: response, language: language)
        
        // After speaking, continue listening unless max failures reached
        if useNative {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                beginListening()
            }
        } else {
            beginListening()
        }
    }
    
    // MARK: - Audio Recording
    
    private func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)
        
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documents.appendingPathComponent("recording.wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        recorder = try AVAudioRecorder(url: audioURL, settings: settings)
        recorder?.prepareToRecord()
        recorder?.record()
    }
    
    private func stopRecording() {
        recorder?.stop()
        recorder = nil
    }
    
    // MARK: - Speech Synthesis
    
    private func speak(text: String, language: String) async {
        await MainActor.run {
            // Cancel any ongoing speech
            speechSynthesizer.stopSpeaking(at: .immediate)
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            
            // Slight delay before speaking to avoid audio conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.speechSynthesizer.speak(utterance)
            }
            
            // Estimate duration to avoid overlapping speech
            let estimatedDuration = text.split(separator: " ").count * 0.4 // Approx 0.4s per word
            try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1_000_000_000))
        }
    }
    
    // MARK: - Conversation History Management
    
    private func buildConversationHistory(with newTranscript: String) -> String {
        var context = ""
        // In a real app, this would pull from an in-memory history list
        // For now, simulate a simple back-and-forth
        context += "User: $newTranscript)\n"
        return context
    }
    
    private func addToHistory(userText: String, aiText: String) {
        // In a real implementation, append to an in-memory array limited by context window
        print("Conversation history updated - User: '$userText)', AI: '$aiText)'")
    }
}

// Placeholder for ASRProcessor using Core ML (WhisperTiny-equivalent)
@MainActor
enum ASRProcessor {
    static func transcribe(_ audioData: Data) async -> String? {
        // Simulate Core ML inference delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // In reality: run WhisperTiny model via Core ML
        // This is a simulation based on predefined logic
        let sampleResponses = [
            "hello how are you",
            "i am fine thank you",
            "what is your name",
            "goodbye"
        ]
        return sampleResponses.randomElement()
    }
}
