import PresentationStyles
import SwiftUI
import UniformTypeIdentifiers

/// The main window around the detail area: the sidebar, the search field, the toolbar, the folder
/// chooser and the error alert.
public struct ShellView<Detail: View>: View {
    @Bindable private var viewModel: ShellViewModel
    private let detail: Detail

    public init(viewModel: ShellViewModel, @ViewBuilder detail: () -> Detail) {
        self.viewModel = viewModel
        self.detail = detail()
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: Metrics.sidebarMinWidth, ideal: Metrics.sidebarIdealWidth)
        } detail: {
            detail
                .navigationTitle(viewModel.title)
        }
        .searchable(text: $viewModel.search, placement: .toolbar, prompt: "Search titles or serials")
        .toolbar {
            ToolbarItem {
                if viewModel.isScanning {
                    ProgressView().controlSize(.small)
                }
            }
            ToolbarItem {
                Button { viewModel.chooseFolders() } label: {
                    Label("Add Folder", systemImage: Symbols.addFolder)
                }
            }
            ToolbarItem {
                Button { Task { await viewModel.rescan() } } label: {
                    Label("Rescan", systemImage: Symbols.rescan)
                }
                .disabled(viewModel.isScanning)
            }
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
        .alert("Something went wrong", isPresented: errorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }
}

#if DEBUG
#Preview("Empty library") {
    ShellView(viewModel: ShellViewModel(library: PreviewLibrary.make(.init()))) {
        Text("Detail area")
    }
}

#Preview("Library") {
    ShellView(viewModel: ShellViewModel(library: PreviewLibrary.make(PreviewLibrary.recorded))) {
        Text("Detail area")
    }
}

#Preview("Scanning") {
    let library = PreviewLibrary.make(PreviewLibrary.recorded, scanForever: true)
    Task { await library.rescan() }
    return ShellView(viewModel: ShellViewModel(library: library)) {
        Text("Detail area")
    }
}

#Preview("Error") {
    let library = PreviewLibrary.make(PreviewLibrary.recorded)
    library.launch(PreviewLibrary.recorded.games[0])
    library.launch(PreviewLibrary.recorded.games[1])
    return ShellView(viewModel: ShellViewModel(library: library)) {
        Text("Detail area")
    }
}
#endif
