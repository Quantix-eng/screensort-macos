import Foundation
import AppKit

enum PreviewType {
    case image
    case pdf
    case video
    case text       // .txt, .md, .csv, .rtf
    case code       // .py, .swift, .js, .html, .css, .json, .xml, .sh, .rb, .java, .c, .cpp, .h
    case directory
    case generic    // icon only
}

struct Screenshot: Identifiable, Hashable {
    let id: UUID = UUID()
    let url: URL
    var dateCreated: Date
    var isDirectory: Bool = false

    var filename: String {
        url.lastPathComponent
    }

    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "webp", "heic", "heif", "bmp", "ico", "svg"]
    private static let pdfExts: Set<String> = ["pdf"]
    private static let videoExts: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]
    private static let textExts: Set<String> = ["txt", "md", "markdown", "rtf", "csv", "log", "strings", "plist"]
    private static let codeExts: Set<String> = ["py", "swift", "js", "ts", "jsx", "tsx", "html", "css", "scss",
                                                 "json", "xml", "yaml", "yml", "sh", "bash", "zsh",
                                                 "rb", "java", "c", "cpp", "h", "hpp", "m", "go",
                                                 "rs", "php", "lua", "r", "sql", "toml", "ini", "cfg",
                                                 "dockerfile", "makefile", "gitignore"]

    var previewType: PreviewType {
        if isDirectory { return .directory }
        let ext = url.pathExtension.lowercased()
        // Handle extensionless files by name
        let name = url.lastPathComponent.lowercased()
        if Self.imageExts.contains(ext) { return .image }
        if Self.pdfExts.contains(ext) { return .pdf }
        if Self.videoExts.contains(ext) { return .video }
        if Self.textExts.contains(ext) { return .text }
        if Self.codeExts.contains(ext) || Self.codeExts.contains(name) { return .code }
        return .generic
    }

    var isImage: Bool { previewType == .image }

    /// System icon for this file type
    var fileIcon: NSImage {
        if isDirectory {
            return NSWorkspace.shared.icon(for: .folder)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// Human-readable file size
    var fileSizeText: String {
        guard !isDirectory else { return "Dossier" }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes?[.size] as? Int64 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// File extension for display
    var fileExtension: String {
        let ext = url.pathExtension.uppercased()
        return ext.isEmpty ? (isDirectory ? "DOSSIER" : "FICHIER") : ext
    }
}
