import DataCatalog
import PresentationStyles
import SwiftUI
import UniformTypeIdentifiers

/// The Settings window: emulator apps, launch options, library folders and RPCS3's installed games.
public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("Emulators") {
                ForEach(viewModel.emulators) { row in
                    LabeledContent {
                        HStack {
                            Text(row.appPath ?? "Not found")
                                .foregroundStyle(row.appPath == nil ? Palette.missing : Palette.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Choose…") { viewModel.chooseApp(for: row.kind) }
                        }
                    } label: {
                        Text(row.title)
                    }
                }
                Button("Detect Installed Emulators") { viewModel.detectEmulators() }
            }

            Section("Launching") {
                Toggle("Start games in fullscreen", isOn: $viewModel.startsFullscreen)
                Toggle("Skip BIOS intro (PS1 / PS2)", isOn: $viewModel.skipsBIOSIntro)
            }

            Section("Library Folders") {
                if viewModel.folders.isEmpty {
                    Text("No folders yet.").foregroundStyle(Palette.secondaryText)
                }
                ForEach(viewModel.folders) { folder in
                    HStack {
                        Text(folder.url.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Picker("Console", selection: hintBinding(for: folder)) {
                            Text("Auto-detect").tag(Platform?.none)
                            ForEach(viewModel.platforms) { platform in
                                Text(platform.shortName).tag(Platform?.some(platform))
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button(role: .destructive) {
                            Task { await viewModel.removeFolder(folder) }
                        } label: {
                            Image(systemName: Symbols.removeFolder)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Folder…") { viewModel.chooseFolders() }
            }

            Section("PS3") {
                Toggle("Include games installed in RPCS3", isOn: $viewModel.includesRPCS3InstalledGames)
                LabeledContent("dev_hdd0/game") {
                    Text(viewModel.rpcs3GameFolderPath)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: Metrics.settingsWidth, height: Metrics.settingsHeight)
        .fileImporter(isPresented: $viewModel.isChoosingApp, allowedContentTypes: [.applicationBundle]) { result in
            if case .success(let url) = result { viewModel.useApp(url) }
        }
        .fileImporter(
            isPresented: $viewModel.isChoosingFolders,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task { await viewModel.addFolders(urls) }
            }
        }
    }

    private func hintBinding(for folder: LibraryFolder) -> Binding<Platform?> {
        Binding(
            get: { folder.platformHint },
            set: { viewModel.setPlatformHint($0, for: folder) }
        )
    }
}

#if DEBUG
#Preview("Nothing set up") {
    SettingsView(viewModel: SettingsViewModel(library: PreviewLibrary.make(.init())))
}

#Preview("Set up") {
    SettingsView(viewModel: SettingsViewModel(library: PreviewLibrary.make(PreviewLibrary.recorded)))
}
#endif
