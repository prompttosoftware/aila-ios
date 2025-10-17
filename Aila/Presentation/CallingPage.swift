import SwiftUI
import AVFoundation

struct CallingPage: View {
    @ObservedObject var flow = ConversationFlow.shared
    @State private var showingCallEnded = false

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                
                Text(flow.activeContact?.name ?? "Unknown")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .id(UUID()) // Force reanimation when contact changes
                
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.green)
                    .font(.title)
                    .padding(.top, 20)
                    .animation(.easeInOut, value: flow.isActive)
                
                Spacer()
                
                HStack(spacing: 60) {
                    Button(action: toggleSpeaker) {
                        Image(systemName: flow.speakerEnabled ? "speaker.3" : "speaker.1")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Button(action: endCall) {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .frame(width: 80, height: 80)
                            .background(Color.red)
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .alert("Call Ended", isPresented: $showingCallEnded) {
            Button("OK") { }
        }
    }

    func toggleSpeaker() {
        flow.toggleSpeaker()
    }

    func endCall() {
        ConversationFlow.shared.endCall()
        showingCallEnded = true
    }
}

struct CallingPage_Previews: PreviewProvider {
    static var previews: some View {
        // Mock setup for preview
        ConversationFlow.shared.activeContact = Contact(id: "1", name: "Alex Johnson", phoneNumber: "+1234567890")
        ConversationFlow.shared.isActive = true
        return CallingPage()
    }
}
