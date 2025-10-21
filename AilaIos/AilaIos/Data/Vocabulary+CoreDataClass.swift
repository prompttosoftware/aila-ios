import Foundation
import CoreData

@objc(VocabularyProficient)
public class VocabularyProficient: NSManagedObject {
    // Managed properties (automatically generated from .xcdatamodeld):
    //
    // @NSManaged public var word: String
    // @NSManaged public var language: String
    // @NSManaged public var lastPracticed: Date
    //
    // Note: Properties are defined in the CoreData model file.
    // This class serves as a native interface for VocabularyProficient entity.
}

@objc(VocabularyStruggling)
public class VocabularyStruggling: NSManagedObject {
    @NSManaged public var word: String
    @NSManaged public var language: String
    @NSManaged public var severity: Int16
    @NSManaged public var retriesNeeded: Int16
    @NSManaged public var nextReview: Date

    /// Calculates and updates the next review date based on current retries and severity.
    /// Uses SM-2 inspired formula: interval = severity * (retriesNeeded == 0 ? 1 : pow(2, Double(6 - retriesNeeded)))
    /// - Returns: The new nextReview date
    @discardableResult
    public func updateNextReview() -> Date {
        let intervalDays: Double
        if retriesNeeded == 0 {
            intervalDays = 1.0 // Final review before moving to proficient
        } else {
            intervalDays = Double(severity) * pow(2.0, Double(6 - retriesNeeded))
        }

        let nextDate = Date(timeIntervalSinceNow: intervalDays * 86400)
        nextReview = nextDate
        return nextDate
    }

    /// Decrements retriesNeeded and updates nextReview accordingly.
    /// - Returns: true if item should be moved to VocabularyProficient
    @discardableResult
    public func recordAttempt() -> Bool {
        if retriesNeeded > 0 {
            retriesNeeded -= 1
        }
        updateNextReview()
        return retriesNeeded <= 0
    }
}

// MARK: - Fetching and Query Helpers

extension NSManagedObjectContext {
    /// Retrieves a struggling word by word and language
    func fetchStrugglingWord(word: String, language: String) -> VocabularyStruggling? {
        let request: NSFetchRequest<VocabularyStruggling> = VocabularyStruggling.fetchRequest()
        request.predicate = NSPredicate(format: "word == %@ AND language == %@", word, language)
        do {
            let results = try fetch(request)
            return results.first
        } catch {
            print("Error fetching struggling word: $error)")
            return nil
        }
    }

    /// Retrieves a proficient word by word and language
    func fetchProficientWord(word: String, language: String) -> VocabularyProficient? {
        let request: NSFetchRequest<VocabularyProficient> = VocabularyProficient.fetchRequest()
        request.predicate = NSPredicate(format: "word == %@ AND language == %@", word, language)
        do {
            let results = try fetch(request)
            return results.first
        } catch {
            print("Error fetching proficient word: $error)")
            return nil
        }
    }
}
