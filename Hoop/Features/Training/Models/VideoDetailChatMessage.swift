import Foundation

struct VideoDetailChatMessage: Identifiable, Equatable {
    enum Sender {
        case user
        case assistant
    }

    let id: UUID
    let sender: Sender
    let text: String

    init(
        id: UUID = UUID(),
        sender: Sender,
        text: String
    ) {
        self.id = id
        self.sender = sender
        self.text = text
    }
}
