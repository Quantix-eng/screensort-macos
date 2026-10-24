import SwiftUI
import AppKit

struct WelcomeView: View {
    @ObservedObject var viewModel: ScreenshotViewModel

    private let categoryColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "rectangle.stack.badge.play")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(.accentColor)
                    .padding(.top, 30)

                Text("ScreenSort")
                    .font(.system(size: 28, weight: .bold))

                Text("Sort files quickly with your keyboard")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)

            Divider().padding(.horizontal, 40)

            // Location selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Location")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    sourceButton(
                        title: "Desktop",
                        icon: "desktopcomputer",
                        isSelected: viewModel.scanLocation == .desktopOnly,
                        action: { viewModel.scanLocation = .desktopOnly }
                    )
                    sourceButton(
                        title: "Desktop + Pictures",
                        icon: "photo.on.rectangle",
                        isSelected: viewModel.scanLocation == .desktopAndPictures,
                        action: { viewModel.scanLocation = .desktopAndPictures }
                    )
                    sourceButton(
                        title: customFolderName,
                        icon: "folder.badge.questionmark",
                        isSelected: isCustomFolder,
                        action: { viewModel.selectProjectFolder() }
                    )
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            // Category selection
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("File types")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: { viewModel.selectAllCategories() }) {
                        Text("Select all")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                LazyVGrid(columns: categoryColumns, spacing: 10) {
                    ForEach(FileCategory.allCases) { category in
                        CategoryToggleButton(
                            category: category,
                            isSelected: viewModel.selectedCategories.contains(category),
                            action: { viewModel.toggleCategory(category) }
                        )
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()

            // Start button
            VStack(spacing: 10) {
                Button(action: { viewModel.startSorting() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Start sorting")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: 280)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.selectedCategories.isEmpty)

                if viewModel.selectedCategories.isEmpty {
                    Text("Select at least one file type")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var isCustomFolder: Bool {
        if case .customFolder = viewModel.scanLocation { return true }
        return false
    }

    private var customFolderName: String {
        if case .customFolder(let url) = viewModel.scanLocation {
            return url.lastPathComponent
        }
        return "Choose a folder…"
    }

    private func sourceButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

// MARK: - Category Toggle Button
struct CategoryToggleButton: View {
    let category: FileCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(category.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}
