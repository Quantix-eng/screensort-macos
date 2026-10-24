import Foundation
import Combine
import AppKit

enum AppScreen {
    case welcome
    case sorting
}

@MainActor
final class ScreenshotViewModel: ObservableObject {
    @Published var screenshots: [Screenshot] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var userActions: [UserAction] = []
    @Published var canUndoAction: Bool = false
    @Published var isProcessing: Bool = false
    @Published var destinationFolders: [URL] = []
    @Published var folderShortcuts: [FolderShortcut] = []
    @Published var showCompletionScreen: Bool = false
    @Published var initialScreenshotCount: Int = 0
    @Published var processedCount: Int = 0

    // New: category and source selection
    @Published var currentScreen: AppScreen = .welcome
    @Published var selectedCategories: Set<FileCategory> = [.screenshots]
    @Published var scanLocation: ScanLocation = .desktopOnly

    private let scanner = ScreenshotScanner()
    private let actionEngine = ActionEngine()
    private var preloadedImages: [UUID: NSImage] = [:]

    init() {
        loadSettings()
    }

    var currentScreenshot: Screenshot? {
        screenshots[safe: currentIndex]
    }

    var totalCount: Int {
        screenshots.count
    }

    var remainingCount: Int {
        max(0, screenshots.count - (currentIndex + 1))
    }

    var progressText: String {
        if initialScreenshotCount == 0 { return "–" }
        return "\(processedCount) / \(initialScreenshotCount)"
    }

    var progressPercentage: Double {
        guard initialScreenshotCount > 0 else { return 0 }
        return Double(processedCount) / Double(initialScreenshotCount)
    }

    func loadSettings() {
        if let saved = [UserAction].loadFromDefaults() {
            self.userActions = saved
        } else {
            self.userActions = UserAction.defaultActions
            self.userActions.saveToDefaults()
        }
        
        if let savedFolders = UserDefaults.standard.array(forKey: "destinationFolders") as? [String] {
            self.destinationFolders = savedFolders.compactMap { URL(fileURLWithPath: $0) }
        } else {
            self.destinationFolders = []
        }
        
        if let savedShortcuts = [FolderShortcut].loadFromDefaults() {
            self.folderShortcuts = savedShortcuts
        } else {
            self.folderShortcuts = []
        }
    }

    func saveFolders() {
        let paths = destinationFolders.map { $0.path }
        UserDefaults.standard.set(paths, forKey: "destinationFolders")
    }

    func saveFolderShortcuts() {
        folderShortcuts.saveToDefaults()
    }
    
    func addFolderShortcut(label: String, folderURL: URL, keyCode: UInt16) {
        let shortcut = FolderShortcut(id: UUID(), label: label, folderURL: folderURL, keyCode: keyCode)
        folderShortcuts.append(shortcut)
        saveFolderShortcuts()
    }
    
    func removeFolderShortcut(at index: Int) {
        folderShortcuts.remove(at: index)
        saveFolderShortcuts()
    }

    func addDestinationFolder(_ url: URL) {
        if !destinationFolders.contains(url) {
            destinationFolders.append(url)
            saveFolders()
        }
    }

    func removeDestinationFolder(at index: Int) {
        destinationFolders.remove(at: index)
        saveFolders()
    }

    func startSorting() {
        currentScreen = .sorting
        loadScreenshots()
    }

    func backToWelcome() {
        currentScreen = .welcome
        screenshots = []
        currentIndex = 0
        showCompletionScreen = false
        initialScreenshotCount = 0
        processedCount = 0
        preloadedImages.removeAll()
    }

    func loadScreenshots() {
        isLoading = true
        Task {
            let found = await scanner.scan(categories: selectedCategories, source: scanLocation)
            self.screenshots = found
            self.currentIndex = 0
            self.showCompletionScreen = false
            
            self.initialScreenshotCount = found.count
            self.processedCount = 0
            
            self.isLoading = false
            self.preloadImages()
        }
    }

    private func handleSkip() {
        guard !screenshots.isEmpty, let currentScreenshot = currentScreenshot else { return }

        isProcessing = true
        Task {
            do {
                try await actionEngine.execute(action: UserAction(
                    id: UUID(),
                    name: "Skip",
                    keyCode: 0,
                    type: .skip
                ), on: currentScreenshot)
                
                await MainActor.run {
                    screenshots.remove(at: currentIndex)
                    processedCount += 1
                    
                    if screenshots.isEmpty {
                        showCompletionScreen = true
                    } else if currentIndex >= screenshots.count {
                        currentIndex = max(0, screenshots.count - 1)
                    }
                    
                    updateUndoState()
                    preloadImages()
                    isProcessing = false
                }
            } catch {
                print("Skip error: \(error)")
                await MainActor.run { isProcessing = false }
            }
        }
    }

    func executeAction(_ action: UserAction) {
        guard !isProcessing else { return }

        switch action.type {
        case .delete:
            handleDelete()
        case .moveToFolder:
            handleMove(to: action.destinationFolderURL)
        case .skip:
            handleSkip()
        case .undo:
            performUndo()
        }
    }
    
    func executeFolderShortcut(_ shortcut: FolderShortcut) {
        guard !isProcessing else { return }
        handleMove(to: shortcut.folderURL)
    }

    private func handleDelete() {
        guard !screenshots.isEmpty, let currentScreenshot = currentScreenshot else { return }

        isProcessing = true
        Task {
            do {
                try await actionEngine.execute(action: UserAction(
                    id: UUID(),
                    name: "Delete",
                    keyCode: 0,
                    type: .delete
                ), on: currentScreenshot)
                
                // Ensure all UI updates happen on MainActor
                await MainActor.run {
                    screenshots.remove(at: currentIndex)
                    processedCount += 1
                    
                    if screenshots.isEmpty {
                        showCompletionScreen = true
                    } else if currentIndex >= screenshots.count {
                        currentIndex = max(0, screenshots.count - 1)
                    }
                    
                    updateUndoState()
                    preloadImages()
                    isProcessing = false
                }
            } catch {
                print("Delete error: \(error)")
                await MainActor.run { isProcessing = false }
            }
        }
    }

    private func handleMove(to folder: URL?) {
        guard !screenshots.isEmpty, let currentScreenshot = currentScreenshot else { return }
        guard let dest = folder else { 
            showFolderPicker()
            return 
        }

        isProcessing = true
        Task {
            do {
                try await actionEngine.execute(action: UserAction(
                    id: UUID(),
                    name: "Move",
                    keyCode: 0,
                    type: .moveToFolder,
                    destinationFolderURL: dest
                ), on: currentScreenshot)
                
                // Ensure all UI updates happen on MainActor
                await MainActor.run {
                    screenshots.remove(at: currentIndex)
                    processedCount += 1
                    
                    if screenshots.isEmpty {
                        showCompletionScreen = true
                    } else if currentIndex >= screenshots.count {
                        currentIndex = max(0, screenshots.count - 1)
                    }
                    
                    updateUndoState()
                    preloadImages()
                    isProcessing = false
                }
            } catch {
                print("Move error: \(error)")
                await MainActor.run { isProcessing = false }
            }
        }
    }

    private func showFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose destination folder"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            addDestinationFolder(selectedURL)
            handleMove(to: selectedURL)
        }
    }

    func performUndo() {
        // Can undo even if list is empty (to restore last item)
        // guard !screenshots.isEmpty else { return } 

        isProcessing = true
        Task {
            do {
                if let restoredScreenshot = try await actionEngine.undoLastAction() {
                    let newURL = restoredScreenshot.url
                    let updatedScreenshot = Screenshot(url: newURL, dateCreated: restoredScreenshot.dateCreated)

                    if currentIndex >= 0 && currentIndex <= screenshots.count {
                        screenshots.insert(updatedScreenshot, at: currentIndex)
                    } else {
                        screenshots.append(updatedScreenshot)
                        currentIndex = screenshots.count - 1
                    }
                    
                    processedCount = max(0, processedCount - 1)
                    showCompletionScreen = false
                }
                updateUndoState()
                preloadImages()
                isProcessing = false
            } catch {
                print("Undo error: \(error)")
                isProcessing = false
            }
        }
    }

    private func updateUndoState() {
        Task {
            let canUndo = await actionEngine.canUndo()
            self.canUndoAction = canUndo
        }
    }

    private func preloadImages() {
        let indicesToPreload = [currentIndex - 1, currentIndex, currentIndex + 1]
            .filter { $0 >= 0 && $0 < screenshots.count }

        let uuidsToPreload = Set(indicesToPreload.map { screenshots[$0].id })

        for index in indicesToPreload {
            let item = screenshots[index]
            let uuid = item.id
            // Only preload actual images
            if preloadedImages[uuid] == nil && item.isImage {
                if let nsImage = NSImage(contentsOf: item.url) {
                    preloadedImages[uuid] = nsImage
                }
            }
        }

        // Clean up images not in current preload set
        let uuidsToRemove = preloadedImages.keys.filter { !uuidsToPreload.contains($0) }
        for uuid in uuidsToRemove {
            preloadedImages.removeValue(forKey: uuid)
        }
    }

    func getPreloadedImage(for screenshot: Screenshot) -> NSImage? {
        // Always reload to avoid stale cache
        if let cachedImage = preloadedImages[screenshot.id] {
            return cachedImage
        }
        // Fallback: load directly if not in cache
        return NSImage(contentsOf: screenshot.url)
    }

    func resetCompletion() {
        showCompletionScreen = false
        loadScreenshots()
    }

    func selectProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose a folder to sort"
        panel.message = "Select a folder whose contents you want to sort"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            scanLocation = .customFolder(selectedURL)
        }
    }

    func toggleCategory(_ category: FileCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            // If selecting allFiles, clear others; if selecting something else, remove allFiles
            if category == .allFiles {
                selectedCategories = [.allFiles]
            } else {
                selectedCategories.remove(.allFiles)
                selectedCategories.insert(category)
            }
        }
    }

    func selectAllCategories() {
        selectedCategories = [.allFiles]
    }
}

