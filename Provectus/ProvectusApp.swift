import SwiftUI

@main
struct ProvectusApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: DraftingViewModel())
        }
    }
}
