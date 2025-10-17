import SwiftUI
import CoreData

struct ContactListPage: View {
    @ObservedObject var contactManager = ContactManager.shared
    @State private var showingAddModal = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(contactManager.contacts) { contact in
                    ContactRow(contact: contact)
                }
                .onDelete(perform: deleteContacts)
            }
            .navigationTitle("Contacts")
            .sheet(isPresented: $showingAddModal) {
                ContactModal()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Add") {
                        showingAddModal = true
                    }
                }
            }
        }
    }

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            let contact = contactManager.contacts[index]
            contactManager.deleteContact(contact)
        }
    }
}

private struct ContactRow: View {
    let contact: Contact
    @Environment(\.openURL) var openURL

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(contact.wrappedName)
                    .font(.headline)
                Text(contact.wrappedLanguage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "flag.fill")
                .foregroundColor(getFlagColor(for: contact.wrappedLanguageCode))

            Button(action: {
                ConversationFlow.shared.startConversation(contact: contact)
                openURL(URL(string: "ila://calling")!)
            }) {
                Image(systemName: "phone.fill")
                    .foregroundColor(.green)
            }
            .buttonStyle(PlainButtonStyle())

            NavigationLink(destination: CallingPage(contact: contact)) {
                EmptyView()
            }
            .opacity(0)
            .frame(width: 0)

            Button(action: {
                // Edit action (placeholder for future sheet/navigation)
                print("Edit contact: \(contact.wrappedName)")
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                // Delete action handled via onDelete in parent List
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            ConversationFlow.shared.startConversation(contact: contact)
            openURL(URL(string: "ila://calling")!)
        }
    }

    private func getFlagColor(for languageCode: String) -> Color {
        // Simplified representation; actual app might use emojis or flag images
        switch languageCode {
        case "es": return .red // Spanish
        case "fr": return .blue // French
        case "de": return .black // German
        case "ja": return .red // Japanese
        default: return .gray
        }
    }
}

// MARK: - Preview

struct ContactListPage_Previews: PreviewProvider {
    static var previews: some View {
        ContactListPage()
    }
}
