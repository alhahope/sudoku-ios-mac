import AppKit
import Foundation
import SudokuCore
import UniformTypeIdentifiers

@MainActor
final class SudokuAppViewModel: ObservableObject {
    @Published var givens = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    @Published var solved = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    @Published var selectedCell: CellPosition? = .init(row: 0, col: 0)
    @Published var status = "手动输入题面，或导入截图自动识别。"
    @Published var importedImage: NSImage?
    @Published var solutionPreview: NSImage?
    @Published var boardRect: CGRect?
    @Published var isShowingSolvedNumbers = false

    struct CellPosition: Hashable {
        let row: Int
        let col: Int
    }

    var gridString: String {
        SudokuGrid(values: givens).flattenedString()
    }

    func valueAt(row: Int, col: Int) -> Int {
        let value = isShowingSolvedNumbers ? solved[row][col] : givens[row][col]
        return value
    }

    func isOriginal(row: Int, col: Int) -> Bool {
        givens[row][col] != 0
    }

    func setSelected(_ row: Int, _ col: Int) {
        selectedCell = CellPosition(row: row, col: col)
    }

    func input(_ value: Int) {
        guard let selectedCell else { return }
        givens[selectedCell.row][selectedCell.col] = value
        solved = givens
        isShowingSolvedNumbers = false
        solutionPreview = nil
    }

    func clearSelected() {
        input(0)
    }

    func moveSelection(rowDelta: Int, colDelta: Int) {
        let current = selectedCell ?? CellPosition(row: 0, col: 0)
        let nextRow = min(8, max(0, current.row + rowDelta))
        let nextCol = min(8, max(0, current.col + colDelta))
        selectedCell = CellPosition(row: nextRow, col: nextCol)
    }

    func clearAll() {
        givens = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        solved = givens
        importedImage = nil
        solutionPreview = nil
        boardRect = nil
        isShowingSolvedNumbers = false
        status = "已清空。"
    }

    func solvePuzzle() {
        do {
            let solvedGrid = try SudokuSolver.solve(SudokuGrid(values: givens))
            solved = solvedGrid.values
            isShowingSolvedNumbers = true
            status = "求解完成。"
            refreshSolutionPreviewIfPossible()
        } catch {
            status = error.localizedDescription
        }
    }

    func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard let image = NSImage(contentsOf: url),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw SudokuError.cannotLoadImage(url.path)
            }

            importedImage = image
            guard let detectedBoardRect = SudokuImageRecognizer.detectBoardRect(in: cgImage) else {
                throw SudokuError.cannotFindBoard
            }

            let recognizedGrid = SudokuImageRecognizer.recognizeDigits(in: cgImage, boardRect: detectedBoardRect)
            givens = recognizedGrid.values
            solved = givens
            boardRect = detectedBoardRect
            isShowingSolvedNumbers = false
            solutionPreview = nil
            let count = recognizedGrid.givensCount
            if count >= 17 {
                status = "已识别 \(count) 个数字。请逐格检查，修正后再求解。"
            } else {
                status = "只识别到 \(count) 个数字，但棋盘位置已锁定。你可以手动补全后继续求解和导出答案图。"
            }
        } catch {
            status = "导入成功，但自动识别失败：\(error.localizedDescription)"
        }
    }

    func exportSolutionImage() {
        do {
            if !isShowingSolvedNumbers {
                try solveIfNeeded()
            }

            guard let importedImage,
                  let cgImage = importedImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let boardRect else {
                status = "需要先导入一张截图，才能导出答案图。"
                return
            }

            let rendered = try SudokuImageRenderer.renderSolution(
                on: cgImage,
                boardRect: boardRect,
                original: SudokuGrid(values: givens),
                solved: SudokuGrid(values: solved)
            )

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = "sudoku-answer.png"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try SudokuImageRenderer.writePNG(rendered, to: url)
            solutionPreview = NSImage(cgImage: rendered, size: importedImage.size)
            status = "答案图已导出到 \(url.path)"
        } catch {
            status = error.localizedDescription
        }
    }

    func pasteGridString(_ string: String) {
        do {
            let grid = try SudokuGrid.from(flattened: string)
            givens = grid.values
            solved = givens
            isShowingSolvedNumbers = false
            solutionPreview = nil
            status = "已从字符串导入题面。"
        } catch {
            status = error.localizedDescription
        }
    }

    private func solveIfNeeded() throws {
        if !isShowingSolvedNumbers {
            let solvedGrid = try SudokuSolver.solve(SudokuGrid(values: givens))
            solved = solvedGrid.values
            isShowingSolvedNumbers = true
        }
    }

    private func refreshSolutionPreviewIfPossible() {
        guard let importedImage,
              let cgImage = importedImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let boardRect else { return }

        do {
            let rendered = try SudokuImageRenderer.renderSolution(
                on: cgImage,
                boardRect: boardRect,
                original: SudokuGrid(values: givens),
                solved: SudokuGrid(values: solved)
            )
            solutionPreview = NSImage(cgImage: rendered, size: importedImage.size)
        } catch {
            status = error.localizedDescription
        }
    }
}
