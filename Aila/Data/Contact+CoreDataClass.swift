import Foundation
import CoreData

@objc(Contact)
public class Contact: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var birthday: Date
    @NSManaged private var _personality: String?
    @NSManaged public var voice: String
    @NSManaged public var language: String
    @NSManaged public var lastCallTime: Date?

    @objc dynamic public var personality: String? {
        get {
            return _personality
        }
        set {
            _personality = newValue?.stripXSS()
        }
    }
}

extension Contact {
    static func insert(
        into context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        birthday: Date,
        personality: String?,
        voice: String,
        language: String,
        lastCallTime: Date? = nil
    ) -> Contact {
        let contact = Contact(context: context)
        contact.id = id
        contact.name = name
        contact.birthday = birthday
        contact.personality = personality
        contact.voice = voice
        contact.language = language
        contact.lastCallTime = lastCallTime
        return contact
    }
}

// MARK: - String Extension for XSS Stripping
private extension String {
    func stripXSS() -> String {
        var result = self
        // Simple XSS prevention: remove script tags and common event handlers
        result = result.replacingOccurrences(of: #"<script[^>]*>.*?</script>"#, with: "", options: .regularExpression, range: nil)
        result = result.replacingOccurrences(of: #"\bon\w+\s*=\s*\"[^\"]*\""#, with: "", options: .regularExpression, range: nil)
        result = result.replacingOccurrences(of: #"\bon\w+\s*=\s*\'[^\']*\'"#, with: "", options: .regularExpression, range: nil)
        result = result.replacingOccurrences(of: #"\bon\w+\s*=\s*[^\s>]*"#, with: "", options: .regularExpression, range: nil)
        // Remove iframe, object, embed tags
        result = result.replacingOccurrences(of: #"<(iframe|object|embed)[^>]*>.*?</\1>"#, with: "", options: .regularExpression, range: nil)
        // Remove onerror, onload in img
        result = result.replacingOccurrences(of: #"onerror\s*=\s*\"[^\"]*\""#, with: "", options: .regularExpression, range: nil)
        result = result.replacingOccurrences(of: #"onload\s*=\s*\"[^\"]*\""#, with: "", options: .regularExpression, range: nil)
        return result
    }
}
