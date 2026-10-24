import Foundation

class ScreenshotScanner {

    /// Scan files matching the given categories from the given source
    func scan(categories: Set<FileCategory>, source: ScanLocation) async -> [Screenshot] {
        let fileManager = FileManager.default

        let searchDirectories: [URL]
        switch source {
        case .desktopOnly:
            searchDirectories = [
                fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            ].compactMap { $0 }
        case .desktopAndPictures:
            searchDirectories = [
                fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
            ].compactMap { $0 }
        case .customFolder(let url):
            searchDirectories = [url]
        }

        var foundItems: [Screenshot] = []

        for directory in searchDirectories {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
                    options: .skipsHiddenFiles
                )
                for url in contents {
                    let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey])
                    let isDir = resourceValues?.isDirectory ?? false
                    let date = resourceValues?.creationDate ?? Date()

                    if matchesCategories(url: url, isDirectory: isDir, categories: categories) {
                        foundItems.append(Screenshot(url: url, dateCreated: date, isDirectory: isDir))
                    }
                }
            } catch {
                continue
            }
        }

        return foundItems.sorted(by: { $0.dateCreated > $1.dateCreated })
    }

    /// Legacy method for backward compatibility
    func scanScreenshots() async -> [Screenshot] {
        return await scan(categories: [.screenshots], source: .desktopAndPictures)
    }

    private func matchesCategories(url: URL, isDirectory: Bool, categories: Set<FileCategory>) -> Bool {
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        for category in categories {
            switch category {
            case .allFiles:
                return true

            case .folders:
                if isDirectory { return true }

            case .screenshots:
                if isDirectory { continue }
                let hasPrefix = FileCategory.screenshotPrefixes.contains {
                    filename.lowercased().hasPrefix($0.lowercased())
                }
                let hasExtension = category.fileExtensions.contains(ext)
                if hasPrefix && hasExtension { return true }

            case .videoCaptures:
                if isDirectory { continue }
                let hasPrefix = FileCategory.videoCapturePrefixes.contains {
                    filename.lowercased().hasPrefix($0.lowercased())
                }
                let hasExtension = category.fileExtensions.contains(ext)
                if hasPrefix && hasExtension { return true }

            default:
                if isDirectory { continue }
                if category.fileExtensions.contains(ext) { return true }
            }
        }

        return false
    }
}
