import Foundation
import CoreML
import AVFoundation

/// Shared executor for on-device machine learning models.
/// Handles loading, preprocessing, inference, and postprocessing for bundled models.
@MainActor
class MLModelExecutor: ObservableObject {
    
    /// Shared singleton instance for global access.
    static let shared = MLModelExecutor()
    
    /// Private instance of the mT5-small model for text-to-text generation.
    private var mt5Model: MT5_Model?
    
    /// Private instance of the WhisperTiny model for audio-to-text transcription.
    private var whisperModel: Whisper_Tiny?
    
    /// Private initializer to enforce singleton pattern and load models at launch.
    private init() {
        loadModels()
    }
    
    /// Loads bundled Core ML models asynchronously during initialization.
    /// Models are configured for CPU execution to ensure compatibility and thermal efficiency.
    private func loadModels() {
        Task {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuOnly // Ensure models run on CPU to stay under size and thermal limits
                
                // Load mT5-small model
                if let mt5URL = Bundle.main.url(forResource: "mt5_small", withExtension: "mlmodelc") {
                    mt5Model = try? MT5_Model(contentsOf: mt5URL, configuration: config)
                }
                
                // Load WhisperTiny model
                if let whisperURL = Bundle.main.url(forResource: "whisper_tiny", withExtension: "mlmodelc") {
                    whisperModel = try? Whisper_Tiny(contentsOf: whisperURL, configuration: config)
                }
            } catch {
                print("Failed to load models: $error)")
            }
        }
    }
    
    /// Generates text from a given prompt using the mT5-small model.
    /// - Parameter prompt: Input text to condition generation.
    /// - Returns: Generated text response, or nil on failure.
    func generateText(from prompt: String) async -> String? {
        guard let model = mt5Model else { return nil }
        
        let processedPrompt = prompt.preprocessedForMT5()
        let input = MT5_ModelInput(text: processedPrompt)
        
        do {
            let output = try model.prediction(input: input)
            return output.text.decodedFromBPE()
        } catch {
            print("MT5 prediction failed: $error)")
            return nil
        }
    }
    
    /// Transcribes speech from audio data using the WhisperTiny model.
    /// - Parameter audio: Raw audio data (assumed to be 16kHz, mono, PCM).
    /// - Returns: Transcribed text, or nil on failure.
    func transcribe(audio: Data) async -> String? {
        guard let model = whisperModel else { return nil }
        
        // Convert Data to Float32 buffer expected by model
        let floatBuffer = audio.toFloatBuffer()
        let input = Whisper_TinyInput(audioBuffer: floatBuffer)
        
        do {
            let output = try model.prediction(input: input)
            return output.transcription
        } catch {
            print("Whisper prediction failed: $error)")
            return nil
        }
    }
}

// MARK: - Preprocessing Extensions

private extension String {
    /// Preprocesses text input for mT5 model compatibility.
    /// - Returns: Lowercased, trimmed text formatted for mT5.
    func preprocessedForMT5() -> String {
        return self.lowercased().trimmed()
    }
}

private extension String {
    /// Removes leading/trailing whitespace and newlines.
    /// - Returns: Trimmed string.
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    /// Applies Byte-Pair Encoding (BPE) decoding logic after model output.
    /// Placeholder for actual BPE merge rules; in practice, this may involve lookup tables.
    /// - Returns: Decoded string with BPE merges applied.
    func decodedFromBPE() -> String {
        // Placeholder implementation. In production, integrate with BPE merge rules
        // from the model's tokenizer (e.g., from a merges.txt file).
        return self.replacingOccurrences(of: "▁", with: " ").replacingOccurrences(of: " $", with: "").trimmed()
    }
}

private extension Data {
    /// Converts PCM audio data to a Float32 array for model input.
    /// Assumes 16-bit signed integer PCM, converts to Float32 in [-1.0, 1.0].
    /// - Returns: Array of Float32 values.
    func toFloatBuffer() -> [Float32] {
        return withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Float32] in
            let int16Pointer = pointer.bindMemory(to: Int16.self)
            return Array(int16Pointer).map { Float32($0) / 32768.0 }
        }
    }
}
