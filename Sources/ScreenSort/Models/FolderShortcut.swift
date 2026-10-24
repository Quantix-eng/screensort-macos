import Foundation

struct FolderShortcut: Identifiable, Codable {
    let id: UUID
    var label: String
    var folderURL: URL
    var keyCode: UInt16

    var displayName: String {
        "\(label) → \(folderURL.lastPathComponent)"
    }

    static func == (lhs: FolderShortcut, rhs: FolderShortcut) -> Bool {
        lhs.id == rhs.id && lhs.keyCode == rhs.keyCode
    }
}

// MARK: - UserDefaults Persistence
extension Array where Element == FolderShortcut {
    func saveToDefaults() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "folderShortcuts")
        }
    }
    
    static func loadFromDefaults() -> [FolderShortcut]? {
        guard let data = UserDefaults.standard.data(forKey: "folderShortcuts") else {
            return nil
        }
        return try? JSONDecoder().decode([FolderShortcut].self, from: data)
    }
}
