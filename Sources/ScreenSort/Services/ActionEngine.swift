import Foundation

actor ActionEngine {
    private let fileManager = FileManager.default
    private let history = ActionHistory()

    func execute(action: UserAction, on screenshot: Screenshot) async throws {
        switch action.type {
        case .delete:
            try await handleDelete(screenshot: screenshot)
        case .moveToFolder:
            guard let destinationFolder = action.destinationFolderURL else { return }
            try await handleMove(screenshot: screenshot, to: destinationFolder)
        case .skip:
            await history.addEntry(
                screenshotURL: screenshot.url,
                originalURL: screenshot.url,
                currentURL: screenshot.url,
                actionType: .skip
            )
        case .undo:
            break // Handled in ViewModel
        }
    }

    private func handleDelete(screenshot: Screenshot) async throws {
        var trashedURL: NSURL?
        try fileManager.trashItem(at: screenshot.url, resultingItemURL: &trashedURL)
        
        let currentURL = (trashedURL as URL?) ?? screenshot.url
        await history.addEntry(
            screenshotURL: screenshot.url,
            originalURL: screenshot.url,
            currentURL: currentURL,
            actionType: .delete
        )
    }

    private func handleMove(screenshot: Screenshot, to destinationFolder: URL) async throws {
        if !fileManager.fileExists(atPath: destinationFolder.path) {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        }

        let destinationURL = destinationFolder.appendingPathComponent(screenshot.url.lastPathComponent)
        try fileManager.moveItem(at: screenshot.url, to: destinationURL)
        
        await history.addEntry(
            screenshotURL: screenshot.url,
            originalURL: screenshot.url,
            currentURL: destinationURL,
            actionType: .moveToFolder
        )
    }

    func undoLastAction() async throws -> Screenshot? {
        guard let entry = await history.undo() else { return nil }

        switch entry.actionType {
        case .delete:
            try await history.restoreFromTrash(entry)
            return Screenshot(url: entry.originalURL, dateCreated: entry.timestamp)
        case .moveToFolder:
            try await history.reverseMove(entry)
            return Screenshot(url: entry.originalURL, dateCreated: entry.timestamp)
        case .skip:
            return Screenshot(url: entry.originalURL, dateCreated: entry.timestamp)
        case .undo:
            return nil
        }
    }

    func canUndo() async -> Bool {
        await history.canUndo()
    }

    func historyCount() async -> Int {
        await history.count()
    }
}

