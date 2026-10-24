import Foundation

struct ActionHistoryEntry: Codable {
    let screenshotURL: URL
    let originalURL: URL
    let currentURL: URL
    let actionType: ActionType
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case screenshotURL, originalURL, currentURL, actionType, timestamp
    }
}

actor ActionHistory {
    private var history: [ActionHistoryEntry] = []
    private let maxHistorySize = 20
    private let fileManager = FileManager.default

    nonisolated let maxHistory = 20

    func addEntry(
        screenshotURL: URL,
        originalURL: URL,
        currentURL: URL,
        actionType: ActionType
    ) {
        history.append(ActionHistoryEntry(
            screenshotURL: screenshotURL,
            originalURL: originalURL,
            currentURL: currentURL,
            actionType: actionType,
            timestamp: Date()
        ))

        if history.count > maxHistorySize {
            history.removeFirst()
        }
    }

    func undo() -> ActionHistoryEntry? {
        guard !history.isEmpty else { return nil }
        return history.removeLast()
    }

    func canUndo() -> Bool {
        !history.isEmpty
    }

    func count() -> Int {
        history.count
    }

    func clear() {
        history.removeAll()
    }

    func restoreFromTrash(_ entry: ActionHistoryEntry) throws {
        let fileManager = FileManager.default

        // If file was moved to trash, try to restore it
        if fileManager.fileExists(atPath: entry.currentURL.path) {
            try fileManager.moveItem(at: entry.currentURL, to: entry.originalURL)
        }
    }

    func reverseMove(_ entry: ActionHistoryEntry) throws {
        if fileManager.fileExists(atPath: entry.currentURL.path) {
            try fileManager.moveItem(at: entry.currentURL, to: entry.originalURL)
        }
    }
}
