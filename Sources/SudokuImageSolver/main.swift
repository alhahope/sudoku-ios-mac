import Foundation
import ImageIO
import SudokuCore

@main
struct SudokuImageSolverCLI {
    static func main() {
        do {
            try run()
        } catch let error as SudokuError {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    static func run() throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 2 else {
            throw SudokuError.usage
        }

        let inputURL = URL(fileURLWithPath: arguments[1])
        let outputURL: URL
        if arguments.count >= 3, arguments[2] != "--givens" {
            outputURL = URL(fileURLWithPath: arguments[2])
        } else {
            let stem = inputURL.deletingPathExtension().lastPathComponent
            outputURL = inputURL.deletingLastPathComponent().appendingPathComponent("\(stem)-solved.png")
        }

        let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil)
        guard let cgSource = source,
              let image = CGImageSourceCreateImageAtIndex(cgSource, 0, nil) else {
            throw SudokuError.cannotLoadImage(inputURL.path)
        }

        guard let boardRect = SudokuImageRecognizer.detectBoardRect(in: image) else {
            throw SudokuError.cannotFindBoard
        }

        let givens: SudokuGrid
        if let flagIndex = arguments.firstIndex(of: "--givens"), flagIndex + 1 < arguments.count {
            givens = try SudokuGrid.from(flattened: arguments[flagIndex + 1])
        } else {
            givens = try SudokuImageRecognizer.recognize(from: image).grid
        }

        let solved = try SudokuSolver.solve(givens)
        let rendered = try SudokuImageRenderer.renderSolution(on: image, boardRect: boardRect, original: givens, solved: solved)
        try SudokuImageRenderer.writePNG(rendered, to: outputURL)

        print("Input:  \(inputURL.path)")
        print("Output: \(outputURL.path)")
        print("Puzzle: \(givens.flattenedString())")
        print("Solved: \(solved.flattenedString())")
    }
}
