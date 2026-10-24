import Foundation

enum ActionType: String, Codable, CaseIterable, Equatable {
    case delete = "delete"
    case moveToFolder = "moveToFolder"
    case skip = "skip"
    case undo = "undo"

    var displayName: String {
        switch self {
        case .delete:
            return "Delete"
        case .moveToFolder:
            return "Move to folder"
        case .skip:
            return "Skip"
        case .undo:
            return "Undo"
        }
    }

    var description: String {
        switch self {
        case .delete:
            return "Move to Trash"
        case .moveToFolder:
            return "Move to a folder"
        case .skip:
            return "Skip to next item"
        case .undo:
            return "Undo (up to 20 actions)"
        }
    }

    var systemImage: String {
        switch self {
        case .delete:
            return "trash.fill"
        case .moveToFolder:
            return "folder.badge.plus"
        case .skip:
            return "forward.fill"
        case .undo:
            return "arrow.counterclockwise"
        }
    }
}

struct UserAction: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var keyCode: UInt16
    let type: ActionType
    var destinationFolderURL: URL?

    var displayName: String {
        if type == .moveToFolder, let url = destinationFolderURL {
            return "\(name) → \(url.lastPathComponent)"
        }
        return name
    }

    static var defaultActions: [UserAction] {
        return [
            UserAction(id: UUID(), name: "Delete", keyCode: 2, type: .delete),      // D
            UserAction(id: UUID(), name: "Skip", keyCode: 49, type: .skip),           // Space
            UserAction(id: UUID(), name: "Undo", keyCode: 6, type: .undo),              // Z
            UserAction(id: UUID(), name: "Folder A", keyCode: 3, type: .moveToFolder), // F
        ]
    }

    static func == (lhs: UserAction, rhs: UserAction) -> Bool {
        lhs.id == rhs.id && lhs.keyCode == rhs.keyCode && lhs.type == rhs.type
    }
}

// MARK: - UserDefaults Persistence
extension Array where Element == UserAction {
    func saveToDefaults() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "userActions")
        }
    }
    
    static func loadFromDefaults() -> [UserAction]? {
        guard let data = UserDefaults.standard.data(forKey: "userActions") else {
            return nil
        }
        return try? JSONDecoder().decode([UserAction].self, from: data)
    }
}

func defaultActions() -> [UserAction] {
    if let saved = [UserAction].loadFromDefaults() {
        return saved
    }
    return UserAction.defaultActions
}
