import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab = .shortcuts
    @State private var editingActions: [UserAction] = []
    @State private var editingFolderShortcuts: [FolderShortcut] = []
    @State private var recordingKeyForActionID: UUID? = nil
    @State private var recordingKeyForFolderID: UUID? = nil
    @State private var eventMonitor: Any? = nil
    @State private var keyboardLayout: KeyboardLayout = KeyboardLayout.savedLayout
    @State private var editingDestinationFolders: [URL] = []

    enum SettingsTab: CaseIterable {
        case shortcuts, destinations, general

        var title: String {
            switch self {
            case .shortcuts: return "Shortcuts"
            case .destinations: return "Folders"
            case .general: return "General"
            }
        }

        var icon: String {
            switch self {
            case .shortcuts: return "keyboard"
            case .destinations: return "folder.badge.plus"
            case .general: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.top, 20)
                Text("Set up shortcuts and folders")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)

            // Tab Selector — matching WelcomeView source buttons
            HStack(spacing: 10) {
                ForEach(SettingsTab.allCases, id: \.title) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18))
                            Text(tab.title)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTab == tab ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal, 24)

            Divider().padding(.top, 16).padding(.horizontal, 24)

            // Tab Content
            Group {
                switch selectedTab {
                case .shortcuts:
                    shortcutsTab
                case .destinations:
                    destinationsTab
                case .general:
                    generalTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer
            HStack(spacing: 12) {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 700, height: 580)
        .onAppear {
            viewModel.settingsAreOpen = true
            editingActions = viewModel.userActions
            editingDestinationFolders = viewModel.destinationFolders
            editingFolderShortcuts = viewModel.folderShortcuts
            keyboardLayout = KeyboardLayout.savedLayout
            setupKeyRecording()
        }
        .onDisappear {
            viewModel.settingsAreOpen = false
            stopKeyRecording()
        }
    }

    // MARK: - Shortcuts Tab
    @ViewBuilder
    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text("Keyboard shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker("", selection: $keyboardLayout) {
                    ForEach(KeyboardLayout.allCases, id: \.self) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
                .onChange(of: keyboardLayout) { _ in
                    KeyboardLayout.savedLayout = keyboardLayout
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(0..<editingActions.count, id: \.self) { index in
                        actionRow(at: index)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }


    // MARK: - Destinations Tab
    @ViewBuilder
    private var destinationsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Folder shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: addFolderShortcut) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)

            if editingFolderShortcuts.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundColor(.secondary)
                    Text("No folder shortcuts")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Assign a key to a folder\nfor quick keyboard sorting")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: addFolderShortcut) {
                        Label("Add shortcut", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(0..<editingFolderShortcuts.count, id: \.self) { index in
                            folderShortcutRow(at: index)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - General Tab
    @ViewBuilder
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("About")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                infoRow(icon: "folder", title: "Default locations", value: "~/Desktop and ~/Pictures")
                infoRow(icon: "arrow.counterclockwise", title: "Undo history", value: "Up to 20 actions")
                infoRow(icon: "keyboard", title: "Open settings", value: "Cmd + ,")
                infoRow(icon: "escape", title: "Back to start", value: "Esc")
            }
            .padding(.horizontal, 24)

            Spacer()

            // App info
            VStack(spacing: 4) {
                Text("ScreenSort v1.0")
                    .font(.system(size: 13, weight: .semibold))
                Text("Sort files quickly with your keyboard")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }

    // MARK: - Folder Shortcut Row
    @ViewBuilder
    private func folderShortcutRow(at index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(editingFolderShortcuts[index].label)
                    .font(.system(size: 13, weight: .medium))
                Text(editingFolderShortcuts[index].folderURL.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Key badge
            keyBadge(
                isRecording: recordingKeyForFolderID == editingFolderShortcuts[index].id,
                keyCode: editingFolderShortcuts[index].keyCode,
                onToggle: {
                    if recordingKeyForFolderID == editingFolderShortcuts[index].id {
                        recordingKeyForFolderID = nil
                    } else {
                        recordingKeyForFolderID = editingFolderShortcuts[index].id
                        recordingKeyForActionID = nil
                    }
                }
            )

            // Delete button
            Button(action: {
                editingFolderShortcuts.remove(at: index)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    // MARK: - Action Row
    @ViewBuilder
    private func actionRow(at index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: editingActions[index].type.systemImage)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(editingActions[index].displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(editingActions[index].type.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            keyBadge(
                isRecording: recordingKeyForActionID == editingActions[index].id,
                keyCode: editingActions[index].keyCode,
                onToggle: {
                    if recordingKeyForActionID == editingActions[index].id {
                        recordingKeyForActionID = nil
                    } else {
                        recordingKeyForActionID = editingActions[index].id
                        recordingKeyForFolderID = nil
                    }
                }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    // MARK: - Shared Key Badge
    private func keyBadge(isRecording: Bool, keyCode: UInt16, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            if isRecording {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                    Text("Press a key…")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.red.opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(5)
            } else {
                Text(KeyboardLayoutMapping.getKeyName(keyCode: keyCode, layout: keyboardLayout))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Methods
    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose folder"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            if !editingDestinationFolders.contains(selectedURL) {
                editingDestinationFolders.append(selectedURL)
            }
        }
    }

    private func addFolderShortcut() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose folder"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            let label = selectedURL.lastPathComponent
            let shortcut = FolderShortcut(id: UUID(), label: label, folderURL: selectedURL, keyCode: 0)
            editingFolderShortcuts.append(shortcut)
        }
    }

    private func setupKeyRecording() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let recordingID = self.recordingKeyForActionID,
               let index = self.editingActions.firstIndex(where: { $0.id == recordingID }) {
                self.editingActions[index].keyCode = event.keyCode
                self.recordingKeyForActionID = nil
                return nil
            }
            
            if let recordingID = self.recordingKeyForFolderID,
               let index = self.editingFolderShortcuts.firstIndex(where: { $0.id == recordingID }) {
                self.editingFolderShortcuts[index].keyCode = event.keyCode
                self.recordingKeyForFolderID = nil
                return nil
            }
            
            return event
        }
    }

    private func stopKeyRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        recordingKeyForActionID = nil
        recordingKeyForFolderID = nil
    }

    private func saveChanges() {
        viewModel.userActions = editingActions
        editingActions.saveToDefaults()
        viewModel.destinationFolders = editingDestinationFolders
        viewModel.saveFolders()
        viewModel.folderShortcuts = editingFolderShortcuts
        viewModel.saveFolderShortcuts()
    }
}



