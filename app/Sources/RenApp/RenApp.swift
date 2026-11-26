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
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
