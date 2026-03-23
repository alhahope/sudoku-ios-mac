import CoreImage
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

@MainActor
final class SudokuMobileViewModel: ObservableObject {
    @Published var givens = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    @Published var solved = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    @Published var selectedCell: CellPosition? = .init(row: 0, col: 0)
    @Published var status = "手动输入题面，或导入截图自动识别。"
    @Published var importedImage: UIImage?
    @Published var solutionPreview: UIImage?
    @Published var boardRect: CGRect?
    @Published var isShowingSolvedNumbers = false
    @Published var isPresentingImporter = false
    @Published var isPresentingExporter = false
    @Published var exportDocument: PNGFileDocument?

    var exportFilename = "sudoku-answer"

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

    func clearAll() {
        givens = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        solved = givens
        importedImage = nil
        solutionPreview = nil
        boardRect = nil
        exportDocument = nil
        exportFilename = "sudoku-answer"
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

    func importImageData(_ data: Data, suggestedName: String = "sudoku-shot") {
        do {
            let image = try normalizedImage(from: data)
            let cgImage = try cgImage(from: image)
            importedImage = image
            boardRect = SudokuImageRecognizer.detectBoardRect(in: cgImage)

            guard let detectedBoardRect = boardRect else {
                throw SudokuError.cannotFindBoard
            }

            let recognizedGrid = SudokuImageRecognizer.recognizeDigits(in: cgImage, boardRect: detectedBoardRect)
            givens = recognizedGrid.values
            solved = givens
            isShowingSolvedNumbers = false
            solutionPreview = nil
            exportDocument = nil
            exportFilename = suggestedName
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

    func importImageFromFile(url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            importImageData(data, suggestedName: url.deletingPathExtension().lastPathComponent)
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

    func prepareExport() {
        do {
            if !isShowingSolvedNumbers {
                try solveIfNeeded()
            }

            guard let importedImage,
                  let boardRect else {
                status = "需要先导入一张截图，才能导出答案图。"
                return
            }

            let cgImage = try cgImage(from: importedImage)
            let rendered = try SudokuImageRenderer.renderSolution(
                on: cgImage,
                boardRect: boardRect,
                original: SudokuGrid(values: givens),
                solved: SudokuGrid(values: solved)
            )
            guard let pngData = pngData(from: rendered) else {
                throw SudokuError.cannotWriteImage(exportFilename)
            }

            exportDocument = PNGFileDocument(data: pngData)
            solutionPreview = UIImage(cgImage: rendered)
            isPresentingExporter = true
            status = "答案图已生成，选择保存位置即可。"
        } catch {
            status = error.localizedDescription
        }
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            status = "答案图已导出到 \(url.lastPathComponent)"
        case .failure(let error):
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
        guard let importedImage, let boardRect else { return }

        do {
            let cgImage = try cgImage(from: importedImage)
            let rendered = try SudokuImageRenderer.renderSolution(
                on: cgImage,
                boardRect: boardRect,
                original: SudokuGrid(values: givens),
                solved: SudokuGrid(values: solved)
            )
            solutionPreview = UIImage(cgImage: rendered)
        } catch {
            status = error.localizedDescription
        }
    }

    private func normalizedImage(from data: Data) throws -> UIImage {
        guard let decoded = UIImage(data: data) else {
            throw SudokuError.cannotLoadImage("data")
        }

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        rendererFormat.opaque = true
        let renderer = UIGraphicsImageRenderer(size: decoded.size, format: rendererFormat)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: decoded.size)).fill()
            decoded.draw(in: CGRect(origin: .zero, size: decoded.size))
        }
    }

    private func cgImage(from image: UIImage) throws -> CGImage {
        if let cgImage = image.cgImage {
            return cgImage
        }

        if let ciImage = image.ciImage {
            let context = CIContext()
            if let rendered = context.createCGImage(ciImage, from: ciImage.extent) {
                return rendered
            }
        }

        guard let pngData = image.pngData(),
              let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw SudokuError.cannotCreateContext
        }
        return cgImage
    }

    private func pngData(from image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }
}
