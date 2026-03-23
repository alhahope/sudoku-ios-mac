import SwiftUI

@main
struct SudokuDesktopApp: App {
    @StateObject private var viewModel = SudokuAppViewModel()

    var body: some Scene {
        WindowGroup("数独求解器") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1120, minHeight: 760)
        }
        .windowResizability(.contentSize)
    }
}
