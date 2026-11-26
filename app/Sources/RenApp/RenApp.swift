import SwiftUI
import RenKit

@main
struct RenApp: App {
    @StateObject private var vm = CleanerViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            DashboardView(vm: vm)
                .background(Color.clear)
                .onAppear {
                    let viewModel = vm
                    appDelegate.onRescan = { [weak viewModel] in
                        viewModel?.startScan()
                    }
                    appDelegate.onAbout = { [weak viewModel] in
                        viewModel?.showingAbout = true
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Ren") {
                    vm.showingAbout = true
                }
            }
        }
    }
}
