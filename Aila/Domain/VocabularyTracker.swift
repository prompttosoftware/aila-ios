import Foundation
import CoreData

class VocabularyTracker: ObservableObject {
    static let shared = VocabularyTracker()
    
    private let queue = OperationQueue()
    private let context = PersistenceController.shared.container.viewContext
    
    enum WordStatus {
        case proficient
        case struggling(severity: Int)
    }
    
    struct WordEntry {
        let word: String
        let language: String
        var retriesNeeded: Int
        var lastPracticed: Date
        var previousInterval: TimeInterval
        var repetitions: Int
        var nextReview: Date
        
        init(word: String, language: String, severity: Int) {
            self.word = word
            self.language = language
            self.retriesNeeded = severity
            self.lastPracticed = Date()
            self.previousInterval = 0
            self.repetitions = 0
            self.nextReview = Date()
        }
    }
    
    func processUtterance(_ text: String, targetLanguage: String, contact: Contact) -> [String: WordStatus] {
        let words = extractWords(from: text, in: targetLanguage)
        let known = fetchProficientWords(language: targetLanguage)
        let struggling = fetchStrugglingWords(language: targetLanguage)
        var result: [String: WordStatus] = [:]
        
        for word in words {
            // Skip words already marked as proficient
            if known.contains(word) {
                result[word] = .proficient
                continue
            }
            
            if let entry = struggling[word], entry.retriesNeeded > 0 {
                // Update existing struggling word
                entry.lastPracticed = Date()
                entry.retriesNeeded -= 1
                result[word] = .struggling(severity: entry.retriesNeeded)
                
                if entry.retriesNeeded == 0 {
                    // Move to proficient after successful use
                    moveToProficient(word, language: targetLanguage, entry: entry)
                } else {
                    // Reschedule the next review with adjusted interval
                    rescheduleStruggling(entry)
                }
            } else {
                // New struggling word with max severity
                addToStruggling(word, severity: 3, language: targetLanguage)
                result[word] = .struggling(severity: 3)
            }
        }
        
        // Persist changes asynchronously
        queue.addOperation {
            self.saveContext()
        }
        
        return result
    }
    
    func getReviewWords(for language: String) -> [String] {
        let now = Date()
        let managedContext = PersistenceController.shared.container.viewContext
        
        let fetchRequest = Vocabulary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "language == %@ AND nextReview <= %@", language, now as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "nextReview", ascending: true)]
        
        do {
            let vocabularyItems = try managedContext.fetch(fetchRequest)
            return vocabularyItems.map { $0.word ?? "" }.filter { !$0.isEmpty }
        } catch {
            print("Failed to fetch review words: $error)")
            return []
        }
    }
    
    private func extractWords(from text: String, in language: String) -> Set<String> {
        var words = Set<String>()
        let cleanedText = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .components(separatedBy: " ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Filter only valid words (could integrate language-specific tokenization later)
        for word in cleanedText {
            if word.count > 1 && word.rangeOfCharacter(from: CharacterSet.decimalDigits) == nil {
                words.insert(word)
            }
        }
        
        return words
    }
    
    private func fetchProficientWords(language: String) -> Set<String> {
        let managedContext = PersistenceController.shared.container.viewContext
        
        let fetchRequest = Vocabulary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "language == %@ AND status == %@", language, "proficient")
        
        do {
            let results = try managedContext.fetch(fetchRequest)
            return Set(results.compactMap { $0.word })
        } catch {
            print("Failed to fetch proficient words: $error)")
            return []
        }
    }
    
    private func fetchStrugglingWords(language: String) -> [String: WordEntry] {
        let managedContext = PersistenceController.shared.container.viewContext
        
        let fetchRequest = Vocabulary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "language == %@ AND status == %@", language, "struggling")
        
        do {
            let results = try managedContext.fetch(fetchRequest)
            var dictionary: [String: WordEntry] = [:]
            for item in results {
                if let word = item.word {
                    dictionary[word] = WordEntry(
                        word: word,
                        language: item.language ?? "",
                        severity: Int(item.retriesNeeded),
                        lastPracticed: item.lastPracticed ?? Date(),
                        previousInterval: item.previousInterval,
                        repetitions: Int(item.repetitions),
                        nextReview: item.nextReview ?? Date()
                    )
                }
            }
            return dictionary
        } catch {
            print("Failed to fetch struggling words: $error)")
            return [:]
        }
    }
    
    private func moveToProficient(_ word: String, language: String, entry: WordEntry) {
        let managedContext = PersistenceController.shared.container.viewContext
        
        // Update to proficient status
        let fetchRequest = Vocabulary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "word == %@ AND language == %@", word, language)
        
        do {
            let results = try managedContext.fetch(fetchRequest)
            if let vocab = results.first {
                vocab.status = "proficient"
                vocab.lastPracticed = Date()
                vocab.repetitions += 1
                
                // Use SM-2 to calculate next review interval
                let quality = 5.0 // Assume perfect recall when moving to proficient
                let factor = 2.5 + (0.15 - 0.05 * Double(vocab.repetitions)) - (0.9 * (1.0 - quality/5.0))
                let newInterval = max(1.0, vocab.previousInterval * factor) // At least 1 day
                vocab.previousInterval = newInterval
                vocab.nextReview = Calendar.current.date(byAdding: .day, value: Int(newInterval), to: Date())
            }
        } catch {
            print("Failed to update word status to proficient: $error)")
        }
    }
    
    private func rescheduleStruggling(_ entry: WordEntry) {
        let managedContext = PersistenceController.shared.container.viewContext
        
        let fetchRequest = Vocabulary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "word == %@ AND language == %@", entry.word, entry.language)
        
        do {
            let results = try managedContext.fetch(fetchRequest)
            if let vocab = results.first {
                // Apply SM-2 with quality based on retries
                let quality = Double(5 - entry.retriesNeeded) // 4 if severity 1, 3 if severity 2, 2 if severity 3
                let factor = 2.5 + (0.15 - 0.05 * Double(vocab.repetitions)) - (0.9 * (1.0 - quality/5.0))
                
                // Struggling words are reviewed 3x more often
                let baseInterval = max(0.5, vocab.previousInterval * factor)
                let newInterval = baseInterval / 3.0
                let nextReview = Calendar.current.date(byAdding: .day, value: Int(newInterval), to: Date())
                
                vocab.previousInterval = newInterval
                vocab.nextReview = nextReview
                vocab.lastPracticed = Date()
            }
        } catch {
            print("Failed to reschedule struggling word: $error)")
        }
    }
    
    private func addToStruggling(_ word: String, severity: Int, language: String) {
        let managedContext = PersistenceController.shared.container.viewContext
        let vocab = Vocabulary(context: managedContext)
        
        vocab.word = word
        vocab.language = language
        vocab.status = "struggling"
        vocab.retriesNeeded = Int16(severity)
        vocab.repetitions = 0
        vocab.lastPracticed = Date()
        vocab.previousInterval = 0
        vocab.nextReview = Date() // Review immediately
        
        // Set base interval using SM-2 (first review)
        let factor = 2.5 + (0.15 - 0.05 * 0) - (0.9 * (1.0 - 2.0/5.0)) // Quality = 2 (struggling)
        let newInterval = 1.0 / 3.0 // First review tomorrow, but 3x faster
        vocab.previousInterval = newInterval
        vocab.nextReview = Calendar.current.date(byAdding: .day, value: Int(newInterval), to: Date())
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Failed to save vocabulary context: $error)")
        }
    }
}
