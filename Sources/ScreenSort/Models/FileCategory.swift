import Foundation

enum FileCategory: String, CaseIterable, Identifiable, Codable {
    case screenshots = "screenshots"
    case videoCaptures = "videoCaptures"
    case allImages = "allImages"
    case pdfs = "pdfs"
    case documents = "documents"
    case presentations = "presentations"
    case spreadsheets = "spreadsheets"
    case archives = "archives"
    case folders = "folders"
    case allFiles = "allFiles"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .screenshots: return "Screenshots"
        case .videoCaptures: return "Screen recordings"
        case .allImages: return "All images"
        case .pdfs: return "PDF"
        case .documents: return "Documents"
        case .presentations: return "Presentations"
        case .spreadsheets: return "Spreadsheets"
        case .archives: return "Archives"
        case .folders: return "Folders"
        case .allFiles: return "All files"
        }
    }

    var systemImage: String {
        switch self {
        case .screenshots: return "camera.viewfinder"
        case .videoCaptures: return "video.fill"
        case .allImages: return "photo.stack"
        case .pdfs: return "doc.richtext"
        case .documents: return "doc.text"
        case .presentations: return "rectangle.on.rectangle.angled"
        case .spreadsheets: return "tablecells"
        case .archives: return "archivebox"
        case .folders: return "folder.fill"
        case .allFiles: return "doc.on.doc"
        }
    }

    var fileExtensions: Set<String> {
        switch self {
        case .screenshots:
            return ["png", "jpg", "jpeg"] // filtered by name prefix
        case .videoCaptures:
            return ["mov", "mp4", "m4v"] // filtered by name prefix
        case .allImages:
            return ["png", "jpg", "jpeg", "gif", "tiff", "tif", "webp", "heic", "heif", "bmp", "ico", "svg"]
        case .pdfs:
            return ["pdf"]
        case .documents:
            return ["txt", "rtf", "doc", "docx", "pages", "odt", "md", "markdown"]
        case .presentations:
            return ["ppt", "pptx", "key", "odp"]
        case .spreadsheets:
            return ["xls", "xlsx", "numbers", "csv", "ods"]
        case .archives:
            return ["zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "iso"]
        case .folders:
            return [] // special: matches directories
        case .allFiles:
            return [] // special: matches everything
        }
    }

    /// Whether this category requires prefix-based name matching (screenshots)
    var requiresNamePrefix: Bool {
        switch self {
        case .screenshots, .videoCaptures:
            return true
        default:
            return false
        }
    }

    /// Known screenshot/video capture prefixes across languages
    static let screenshotPrefixes = [
        "Screenshot", "Capture d'écran", "Bildschirmfoto",
        "Captura de pantalla", "Schermafbeelding", "Skärmavbild"
    ]

    static let videoCapturePrefixes = [
        "Screen Recording", "Enregistrement de l'écran",
        "Bildschirmaufnahme", "Grabación de pantalla"
    ]
}

/// Represents where files should be scanned from
enum ScanLocation: Equatable {
    case desktopOnly
    case desktopAndPictures
    case customFolder(URL)

    var displayName: String {
        switch self {
        case .desktopOnly:
            return "Desktop uniquement"
        case .desktopAndPictures:
            return "Desktop + Pictures"
        case .customFolder(let url):
            return url.lastPathComponent
        }
    }
}
