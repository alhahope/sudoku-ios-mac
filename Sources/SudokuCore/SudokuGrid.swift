import Foundation

public struct SudokuGrid: Equatable, Codable {
    public var values: [[Int]]

    public init(values: [[Int]]) {
        self.values = values
    }

    public static let empty = SudokuGrid(values: Array(repeating: Array(repeating: 0, count: 9), count: 9))

    public subscript(row: Int, col: Int) -> Int {
        get { values[row][col] }
        set { values[row][col] = newValue }
    }

    public var givensCount: Int {
        values.flatMap { $0 }.filter { $0 != 0 }.count
    }

    public var isComplete: Bool {
        !values.flatMap { $0 }.contains(0)
    }

    public func isValidPlacement(row: Int, col: Int, value: Int) -> Bool {
        for index in 0..<9 {
            if index != col, values[row][index] == value { return false }
            if index != row, values[index][col] == value { return false }
        }

        let startRow = (row / 3) * 3
        let startCol = (col / 3) * 3
        for r in startRow..<(startRow + 3) {
            for c in startCol..<(startCol + 3) where !(r == row && c == col) {
                if values[r][c] == value { return false }
            }
        }
        return true
    }

    public func firstEmptyCell() -> (row: Int, col: Int)? {
        for row in 0..<9 {
            for col in 0..<9 where values[row][col] == 0 {
                return (row, col)
            }
        }
        return nil
    }

    public func rowString(_ row: Int) -> String {
        values[row].map(String.init).joined()
    }

    public func flattenedString() -> String {
        values.flatMap { $0 }.map(String.init).joined()
    }

    public static func from(flattened string: String) throws -> SudokuGrid {
        let digits = string.filter(\.isNumber)
        guard digits.count == 81 else {
            throw SudokuError.invalidGridString
        }

        var rows = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for (index, char) in digits.enumerated() {
            guard let value = Int(String(char)), (0...9).contains(value) else {
                throw SudokuError.invalidGridString
            }
            rows[index / 9][index % 9] = value
        }
        return SudokuGrid(values: rows)
    }
}
