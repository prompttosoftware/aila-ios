import SwiftUI
import CoreData
import Foundation

class ContactManager: ObservableObject {
    static let shared = ContactManager()
    
    @Published var contacts: [Contact] = []
    
    private init() {
        loadContacts()
    }
    
    private var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AilaModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        return container
    }()
    
    private func loadContacts() {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        
        do {
            contacts = try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch contacts: \(error)")
            contacts = []
        }
    }
    
    func createContact(name: String, birthday: Date, personality: String, voice: String, language: String) -> Contact {
        let context = persistentContainer.viewContext
        let contact = Contact(context: context)
        
        contact.id = UUID()
        contact.name = name
        contact.birthday = birthday
        contact.personality = sanitize(personality)
        contact.voice = voice
        contact.language = language
        contact.lastCallTime = nil
        
        saveContext()
        contacts.append(contact)
        
        return contact
    }
    
    func deleteContact(_ contact: Contact) {
        let context = persistentContainer.viewContext
        context.delete(contact)
        
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts.remove(at: index)
        }
        
        saveContext()
    }
    
    func generateRingingNarrative(for contact: Contact) async -> String {
        let lastInteraction = contact.lastCallTime ?? Date.distantPast
        let delta = Date().timeIntervalSince(lastInteraction)
        let hours = Int(delta / 3600)
        
        let prompt = """
        Generate a realistic update about what \(contact.name ?? "they") did since your last interaction.
        Context: \(contact.personality ?? ""). Time elapsed: \(hours) hours.
        Response must be 1-2 sentences, natural conversational tone.
        """
        
        if let response = await MLModelExecutor.shared.generateText(from: prompt) {
            return response
        } else {
            return "Hey there! Good to hear from you."
        }
    }
    
    func updateLastCallTime(for contact: Contact) {
        contact.lastCallTime = Date()
        saveContext()
    }
    
    private func sanitize(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "friendly and curious" : trimmed
    }
    
    private func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save managed object context: \(error)")
            }
        }
    }
}
