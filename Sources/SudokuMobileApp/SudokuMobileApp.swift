import SwiftUI

@main
struct SudokuMobileApp: App {
    @StateObject private var viewModel = SudokuMobileViewModel()

    var body: some Scene {
        WindowGroup {
            SudokuMobileContentView(viewModel: viewModel)
                .preferredColorScheme(.light)
        }
    }
}
