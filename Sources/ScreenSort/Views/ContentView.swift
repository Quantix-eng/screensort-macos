import SwiftUI
import AppKit
import QuickLookThumbnailing
import AVFoundation

struct ContentView: View {
    @EnvironmentObject private var viewModel: ScreenshotViewModel
    @State private var showSettings = false
    @State private var eventMonitor: Any? = nil

    var body: some View {
        Group {
            switch viewModel.currentScreen {
            case .welcome:
                WelcomeView(viewModel: viewModel)
            case .sorting:
                sortingView
            }
        }
        .onAppear {
            setupKeyboardHandling()
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    // MARK: - Sorting View
    private var sortingView: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.blue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.showCompletionScreen {
                CompletionView(viewModel: viewModel)
                    .transition(.opacity)
            } else if let item = viewModel.currentScreenshot {
                ZStack(alignment: .bottom) {
                    // Content area - image or file icon
                    if item.isImage, let nsImage = viewModel.getPreloadedImage(for: item) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                            .id(item.id)
                    } else {
                        // Non-image file or directory preview
                        FilePreviewView(item: item)
                            .transition(.opacity)
                            .id(item.id)
                    }

                    // Bottom controls overlay
                    bottomBar(for: item)
                }
                .opacity(viewModel.isProcessing ? 0.65 : 1.0)
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundColor(.secondary)

                    Text("No files found")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("No files match the selected categories")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: { viewModel.loadScreenshots() }) {
                            Label("Scan again", systemImage: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.bordered)

                        Button(action: { viewModel.backToWelcome() }) {
                            Label("Back", systemImage: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 12)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Top-right buttons
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 4) {
                    // Back button
                    Button(action: { viewModel.backToWelcome() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .foregroundColor(.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Back to start")

                    // Settings button
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .foregroundColor(.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Settings (Cmd + ,)")
                    .sheet(isPresented: $showSettings) {
                        SettingsView(viewModel: viewModel)
                    }
                }
                .padding(12)

                Spacer()
            }
        }
    }

    // MARK: - Bottom Bar
    private func bottomBar(for item: Screenshot) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                ProgressView(value: viewModel.progressPercentage)
                    .tint(.blue)
                    .padding(.horizontal, 20)
                    .scaleEffect(y: 1.0, anchor: .center)

                ZStack(alignment: .center) {
                    HStack(spacing: 16) {
                        // Filename + type badge
                        HStack(spacing: 8) {
                            Text(item.fileExtension)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.7))
                                .cornerRadius(3)

                            Text(item.filename)
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.canUndoAction {
                            Label("Z", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.yellow)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    Text(viewModel.progressText)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color.black.opacity(0.7))
        }
    }

    // MARK: - Keyboard
    private func setupKeyboardHandling() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle shortcuts in sorting mode
            guard viewModel.currentScreen == .sorting else { return event }

            // Cmd+, for settings
            if event.modifierFlags.contains(.command) && event.keyCode == 41 {
                showSettings = true
                return nil
            }

            // Escape to go back
            if event.keyCode == 53 {
                viewModel.backToWelcome()
                return nil
            }

            // Check for folder shortcuts first
            if let folderShortcut = viewModel.folderShortcuts.first(where: { $0.keyCode == event.keyCode }) {
                viewModel.executeFolderShortcut(folderShortcut)
                return nil
            }

            // Check for configured actions
            if let matchedAction = viewModel.userActions.first(where: { $0.keyCode == event.keyCode }) {
                viewModel.executeAction(matchedAction)
                return nil
            }

            return event
        }
    }
}

// MARK: - File Preview (non-image files, folders)
struct FilePreviewView: View {
    let item: Screenshot
    @State private var thumbnailImage: NSImage? = nil
    @State private var textContent: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            switch item.previewType {
            case .pdf:
                pdfPreview
            case .video:
                videoPreview
            case .text, .code:
                textPreview
            case .directory:
                iconPreview
            case .generic:
                iconPreview
            case .image:
                iconPreview // fallback, shouldn't happen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadPreview() }
        .onChange(of: item.id) { _ in
            thumbnailImage = nil
            textContent = nil
            loadPreview()
        }
    }

    // MARK: - PDF Preview
    private var pdfPreview: some View {
        VStack(spacing: 12) {
            if let thumb = thumbnailImage {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(4)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
            } else {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                Spacer()
            }
        }
        .padding(.bottom, 60)
    }

    // MARK: - Video Preview
    private var videoPreview: some View {
        VStack(spacing: 12) {
            if let thumb = thumbnailImage {
                ZStack {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(4)

                    // Play icon overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(radius: 6)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            } else {
                Spacer()
                Image(nsImage: item.fileIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                Spacer()
            }
        }
        .padding(.bottom, 60)
    }

    // MARK: - Text / Code Preview
    private var textPreview: some View {
        VStack(spacing: 0) {
            if let content = textContent {
                ScrollView {
                    Text(content)
                        .font(.system(size: 13, design: item.previewType == .code ? .monospaced : .default))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .textSelection(.enabled)
                }
                .background(Color(white: 0.12))
                .cornerRadius(8)
                .padding(.horizontal, 30)
                .padding(.top, 16)
                .padding(.bottom, 60)
            } else {
                Spacer()
                Image(nsImage: item.fileIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                Text(item.filename)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }

    // MARK: - Icon-only Preview (directories, generics)
    private var iconPreview: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(nsImage: item.fileIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)

            VStack(spacing: 6) {
                Text(item.filename)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(item.fileSizeText)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.bottom, 60)
    }

    // MARK: - Load Preview
    private func loadPreview() {
        switch item.previewType {
        case .pdf:
            loadPDFThumbnail()
        case .video:
            loadVideoThumbnail()
        case .text, .code:
            loadTextContent()
        default:
            break
        }
    }

    private func loadPDFThumbnail() {
        // Use Quick Look thumbnail for PDF
        let size = CGSize(width: 800, height: 1000)
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: size,
            scale: 2.0,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
            DispatchQueue.main.async {
                if let rep = representation {
                    self.thumbnailImage = rep.nsImage
                }
            }
        }
    }

    private func loadVideoThumbnail() {
        Task.detached {
            let asset = AVURLAsset(url: item.url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 800, height: 600)

            do {
                let cgImage = try generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                await MainActor.run {
                    self.thumbnailImage = nsImage
                }
            } catch {
                // Fallback: try QLThumbnail
                let size = CGSize(width: 800, height: 600)
                let request = QLThumbnailGenerator.Request(
                    fileAt: item.url,
                    size: size,
                    scale: 2.0,
                    representationTypes: .thumbnail
                )
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
                    DispatchQueue.main.async {
                        if let rep = rep {
                            self.thumbnailImage = rep.nsImage
                        }
                    }
                }
            }
        }
    }

    private func loadTextContent() {
        Task.detached {
            // Limit reading to first 10KB to keep UI responsive
            let maxBytes = 10_240
            guard let handle = FileHandle(forReadingAtPath: item.url.path) else { return }
            let data = handle.readData(ofLength: maxBytes)
            handle.closeFile()

            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .macOSRoman)

            if let t = text {
                // Trim to reasonable line count
                let lines = t.components(separatedBy: .newlines)
                let trimmed = lines.prefix(200).joined(separator: "\n")
                let displayText = lines.count > 200
                    ? trimmed + "\n\n— (\(lines.count - 200) more lines) —"
                    : trimmed

                await MainActor.run {
                    self.textContent = displayText
                }
            }
        }
    }
}

// MARK: - Completion Screen
struct CompletionView: View {
    @ObservedObject var viewModel: ScreenshotViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(.green)

            VStack(spacing: 6) {
                Text("Sorting complete")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)

                Text("\(viewModel.processedCount) items sorted")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: { viewModel.resetCompletion() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Scan again")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)

                Button(action: { viewModel.backToWelcome() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "house")
                        Text("Back to start")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button(action: { NSApp.terminate(nil) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                        Text("Quit app")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

