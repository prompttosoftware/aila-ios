# aila-ios

## AI Language Learning Mobile App (iOS)

Aila is an on-device AI-powered language learning application that simulates realistic phone calls with AI contacts. Designed to feel like a native phone app, Aila enables immersive, low-stakes language practice through dynamic conversations — all without requiring internet connectivity.

---

## 🌟 Key Features

### 📞 Realistic Call Interface
- Simulates authentic phone call experience with ringing, speaker toggle, and hang-up controls.
- Each contact has a unique AI-generated personality, history, job, and interests.

### 🧠 Fully On-Device AI
- No network required — all processing happens locally for privacy and reliability.
- AI pipeline:
  1. **Speech-to-Text (ASR)**: Core ML-powered transcription using Whisper Tiny equivalent.
  2. **Text-to-Text (Conversation & Tutoring)**: mT5-small model adapted for Core ML handles dialogue and language instruction.
  3. **Text-to-Speech (TTS)**: Natural-sounding voice output in target language.

### 🗣 Adaptive Learning Engine
- AI adjusts conversation complexity based on user proficiency.
- Implements **spaced repetition (SM-2 algorithm)** to reinforce vocabulary retention.
- Tracks two dynamic word lists:
  - **Proficient Vocabulary**: Words used correctly (after 2 correct uses within 24h).
  - **Struggling List**: Words the user has difficulty with, categorized by severity (1–3). These are prioritized in future conversations.

### 🔄 Dynamic Contact Narratives
- On each call, the app generates a narrative of what the contact has been doing since the last call, based on elapsed time.
- Uses time-aware prompts to create evolving, personalized backstories.

### 🛑 Native Language Fallback
- If the user struggles to understand:
  - First attempt: AI rephrases or suggests corrections.
  - After two failed attempts: AI responds in the user’s native language (set in app settings).

---

## 🛠 Architecture & Technology Stack

### Core Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Data Storage**: CoreData
- **Machine Learning**: Core ML
- **Task Scheduling**: OperationQueue (for SRS review scheduling)

### Data Model
```swift
// Contact Entity
@NSManaged var name: String
@NSManaged var birthday: Date
@NSManaged var personality: String
@NSManaged var voice: String
@NSManaged var language: String
@NSManaged var lastCallTime: Date?

// VocabularyProficient Entity
@NSManaged var word: String
@NSManaged var language: String
@NSManaged var lastPracticed: Date

// VocabularyStruggling Entity
@NSManaged var word: String
@NSManaged var severity: Int16
@NSManaged var retriesNeeded: Int16
```

### Model Strategy
- All AI models are **pre-bundled in app assets** during build.
- No runtime downloads — ensures full offline functionality and compatibility with headless build environments.
- Model size: <100MB total (optimized for mobile CPU execution).

---

## 🔐 Security & Privacy

### Authentication
- None required — fully offline app.
- Relies on device-level security for data protection.

### Input Validation
- **Birthday**: Validated against ISO 8601 format.
- **Language Codes**: Whitelisted from `ContactLanguage.swift`.
- **Voice Input**: Discarded if ASR confidence < 0.7.
- **Text Inputs**: Sanitized using `NSString.folding()` to prevent injection.

### Storage Sanitization
- All vocabulary and contact data automatically escaped via CoreData.
- Personality field strips HTML/JS content in setters.

---

## 📁 Project Structure

```
aila-ios/
├── Aila/
│   ├── Data/                   # CoreData models and DAOs
│   │   ├── Contact+CoreDataClass.swift
│   │   ├── VocabularyProficient+CoreDataClass.swift
│   │   └── VocabularyStruggling+CoreDataClass.swift
│   ├── Domain/                 # Business logic
│   │   ├── ContactManager.swift
│   │   ├── VocabularyTracker.swift
│   │   └── ProficiencyTracker.swift
│   ├── Presentation/           # SwiftUI views
│   │   ├── ContactListView.swift
│   │   ├── ContactModalView.swift
│   │   ├── CallView.swift
│   │   └── HomeView.swift
│   ├── Speech/                 # ASR, TTS, and conversation flow
│   │   ├── ASRProcessor.swift
│   │   ├── TTSClient.swift
│   │   ├── TutorService.swift
│   │   └── ConversationFlow.swift
│   └── Resources/              # Core ML models (.mlmodelc)
│       ├── WhisperTiny.mlmodelc
│       └── mT5-small.mlmodelc
├── Aila.xcodeproj
└── Package.swift
```

---

## 🧪 Testing & Verification

### Module Verification

| Module | Verification Method |
|-------|---------------------|
| `ContactManager.swift` | Unit test: `testRingingNarrativeGeneration()` with stubbed model |
| `VocabularyTracker.swift` | Unit test: `testSM2Model()` for interval accuracy |
| `ConversationFlow.swift` | Manual test with simulated audio; unit test: `testFallbackFlow()` |

### Build Verification
- **Build Command**:  
  ```bash
  xcodebuild -scheme Aila -configuration Debug
  ```
- **Success Criteria**:
  - Exit code: `0`
  - App size < 50MB
  - All `.mlmodelc` assets present in build output

### Stubbing Strategy
- **Stub Service**: `AiServiceStub.swift` implements ASR, Tutor, and TTS protocols with mock responses.
- **Dependency Injection**: Real vs. stub services injected based on build configuration (via Swift DI pattern).
- **Verification**: Unit tests confirm correct service binding using `XCTest` assertions.

---

## ✅ Completion Criteria

The project is considered **100% complete** when:

- [ ] All modules are implemented with non-crashing stubs or real logic.
- [ ] iOS build succeeds with exit code `0`.
- [ ] Key user flows are manually verified:
  - **Contact Flow**: Add → edit → delete contact (data persists).
  - **Call Flow**: Start call → simulate misunderstanding → verify native language fallback.
  - **Vocab Flow**: Use a new word 3 times → confirm it moves to proficient list.
- [ ] Security edge cases pass (e.g., `<script>alert()</script>` in contact name → stored as plain text).
- [ ] SRS algorithm correctly schedules reviews (verified in unit tests).

---

## 🚀 Why Aila?

Aila is the **only mobile language tutor** that combines:
- Realistic phone-call simulation
- Fully offline AI processing
- Spaced repetition in contextual conversation

It provides a safe, adaptive, and engaging way to practice speaking — anytime, anywhere — without relying on servers, internet, or human tutors.

---

## 📄 License

[MIT License](LICENSE) – Free for personal and commercial use.
