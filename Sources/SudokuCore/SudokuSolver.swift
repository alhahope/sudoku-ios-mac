import Foundation

public enum SudokuError: Error, LocalizedError {
    case usage
    case invalidGridString
    case invalidPuzzle
    case unsolvedPuzzle
    case multipleSolutions
    case cannotLoadImage(String)
    case cannotFindBoard
    case cannotRecognizeDigits
    case cannotCreateContext
    case cannotWriteImage(String)

    public var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: sudoku-image-solver <input-image> [output-image] [--givens <81-char-grid>]"
        case .invalidGridString:
            return "Invalid givens grid. Use 81 digits and 0 for blanks."
        case .invalidPuzzle:
            return "The puzzle contains conflicting numbers."
        case .unsolvedPuzzle:
            return "Puzzle could not be solved from the recognized digits."
        case .multipleSolutions:
            return "This puzzle does not have a unique solution. The givens may be incomplete or entered incorrectly."
        case .cannotLoadImage(let path):
            return "Cannot load image: \(path)"
        case .cannotFindBoard:
            return "Could not find the Sudoku board in the image."
        case .cannotRecognizeDigits:
            return "Could not recognize enough digits from the board."
        case .cannotCreateContext:
            return "Could not create a graphics context."
        case .cannotWriteImage(let path):
            return "Could not write output image: \(path)"
        }
    }
}

public enum SudokuSolver {
    public static func solve(_ grid: SudokuGrid) throws -> SudokuGrid {
        guard isPuzzleConsistent(grid) else {
            throw SudokuError.invalidPuzzle
        }

        var working = grid
        var solutionsFound = 0
        var firstSolution: SudokuGrid?
        searchSolutions(&working, solutionsFound: &solutionsFound, firstSolution: &firstSolution, limit: 2)

        guard let solved = firstSolution else {
            throw SudokuError.unsolvedPuzzle
        }
        guard solutionsFound == 1 else {
            throw SudokuError.multipleSolutions
        }
        return solved
    }

    public static func isPuzzleConsistent(_ grid: SudokuGrid) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                let value = grid[row, col]
                if value == 0 { continue }
                if !grid.isValidPlacement(row: row, col: col, value: value) {
                    return false
                }
            }
        }
        return true
    }

    private static func searchSolutions(
        _ grid: inout SudokuGrid,
        solutionsFound: inout Int,
        firstSolution: inout SudokuGrid?,
        limit: Int
    ) {
        guard solutionsFound < limit else { return }

        guard let cell = bestCell(in: grid) else {
            solutionsFound += 1
            if firstSolution == nil {
                firstSolution = grid
            }
            return
        }

        for candidate in candidates(for: cell, in: grid) {
            guard solutionsFound < limit else { return }
            grid[cell.row, cell.col] = candidate
            searchSolutions(&grid, solutionsFound: &solutionsFound, firstSolution: &firstSolution, limit: limit)
            grid[cell.row, cell.col] = 0
        }
    }

    private static func bestCell(in grid: SudokuGrid) -> (row: Int, col: Int)? {
        var best: (row: Int, col: Int, count: Int)?
        for row in 0..<9 {
            for col in 0..<9 where grid[row, col] == 0 {
                let count = candidates(for: (row, col), in: grid).count
                if count == 0 { return (row, col) }
                if best == nil || count < best!.count {
                    best = (row, col, count)
                }
            }
        }
        return best.map { ($0.row, $0.col) }
    }

    private static func candidates(for cell: (row: Int, col: Int), in grid: SudokuGrid) -> [Int] {
        guard grid[cell.row, cell.col] == 0 else { return [] }
        return (1...9).filter { grid.isValidPlacement(row: cell.row, col: cell.col, value: $0) }
    }
}
