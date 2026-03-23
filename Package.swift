// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SudokuImageSolver",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SudokuCore",
            targets: ["SudokuCore"]
        ),
        .executable(
            name: "sudoku-image-solver",
            targets: ["SudokuImageSolver"]
        ),
        .executable(
            name: "SudokuDesktopApp",
            targets: ["SudokuDesktopApp"]
        )
    ],
    targets: [
        .target(
            name: "SudokuCore"
        ),
        .executableTarget(
            name: "SudokuImageSolver",
            dependencies: ["SudokuCore"]
        ),
        .executableTarget(
            name: "SudokuDesktopApp",
            dependencies: ["SudokuCore"]
        )
    ]
)
