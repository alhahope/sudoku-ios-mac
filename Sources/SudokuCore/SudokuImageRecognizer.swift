import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Vision

public struct SudokuRecognitionResult {
    public let boardRect: CGRect
    public let grid: SudokuGrid

    public init(boardRect: CGRect, grid: SudokuGrid) {
        self.boardRect = boardRect
        self.grid = grid
    }
}

public enum SudokuImageRecognizer {
    private static let normalizedBoardSide = 900
    private static let templateSize = CGSize(width: 28, height: 40)
    private static let samplePuzzleString = "800049502450032069090000804004020091070010008021970305019403287060000050200700010"
    private static let sampleDigitTemplates = buildReferenceDigitTemplates()
    private static let fallbackDigitTemplates = buildFontDigitTemplates()
    private static let digitTemplates = mergeTemplates(primary: sampleDigitTemplates, secondary: fallbackDigitTemplates)

    public static func recognize(from image: CGImage) throws -> SudokuRecognitionResult {
        guard let boardRect = detectBoardRect(in: image) else {
            throw SudokuError.cannotFindBoard
        }

        let grid = recognizeDigits(in: image, boardRect: boardRect)
        guard grid.givensCount >= 17 else {
            throw SudokuError.cannotRecognizeDigits
        }
        return SudokuRecognitionResult(boardRect: boardRect, grid: grid)
    }

    public static func detectBoardRect(in image: CGImage) -> CGRect? {
        if isBoardOnlyImage(width: image.width, height: image.height) {
            return defaultBoardRect(for: image)
        }
        if let rect = detectBoardRectByGreenComponent(in: image) {
            return rect
        }
        if let rect = detectBoardRectWithVision(in: image) {
            return rect
        }
        return detectBoardRectByGreenFrame(in: image)
    }

    public static func recognizeDigits(in image: CGImage, boardRect: CGRect) -> SudokuGrid {
        let cellRects = fallbackCellRects(for: boardRect)

        var grid = SudokuGrid.empty
        var observations: [DigitObservation] = []

        for row in 0..<9 {
            for col in 0..<9 {
                let rect = cellRects[row][col]
                guard let cellImage = cropImage(image, rectFromTopLeft: rect),
                      likelyContainsDigit(cellImage),
                      let prediction = recognizeDigit(in: cellImage) else {
                    continue
                }

                grid[row, col] = prediction.digit
                observations.append(DigitObservation(row: row, col: col, digit: prediction.digit, score: prediction.score))
            }
        }

        pruneConflictingDigits(in: &grid, observations: observations)
        fillLikelyOnes(in: &grid, image: image, cellRects: cellRects)
        pruneConflictingDigits(in: &grid, observations: observations)
        return grid
    }

    private static func detectBoardRectWithVision(in image: CGImage) -> CGRect? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 20
        request.minimumAspectRatio = 0.9
        request.maximumAspectRatio = 1.1
        request.minimumSize = 0.18
        request.minimumConfidence = 0.55
        request.quadratureTolerance = 18

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])

        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let candidates = (request.results ?? []).compactMap { observation -> (CGRect, Double)? in
            let points = [observation.topLeft, observation.topRight, observation.bottomLeft, observation.bottomRight]
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
                return nil
            }

            let rect = CGRect(
                x: minX * imageWidth,
                y: (1.0 - maxY) * imageHeight,
                width: (maxX - minX) * imageWidth,
                height: (maxY - minY) * imageHeight
            ).integral.insetBy(dx: 3, dy: 3)

            let squareScore = 1.0 - abs(rect.width - rect.height) / max(rect.width, rect.height)
            let areaScore = Double((rect.width * rect.height) / (imageWidth * imageHeight))
            let centerBias = 1.0 - abs(rect.midY - imageHeight * 0.52) / imageHeight
            return (rect, squareScore * 3.0 + areaScore * 6.0 + Double(max(0.0, centerBias)))
        }

        return candidates.sorted(by: { $0.1 > $1.1 }).first?.0
    }

    private static func detectBoardRectByGreenComponent(in image: CGImage) -> CGRect? {
        guard let pixels = pixelBuffer(from: image) else { return nil }

        let width = pixels.width
        let height = pixels.height
        let boardOnlyImage = isBoardOnlyImage(width: width, height: height)
        let minSearchY = boardOnlyImage ? 0 : Int(Double(height) * 0.16)
        let maxSearchY = boardOnlyImage ? height : Int(Double(height) * 0.84)
        var visited = Array(repeating: false, count: width * height)

        var bestRect: CGRect?
        var bestScore = Double.leastNormalMagnitude

        for y in minSearchY..<maxSearchY {
            for x in 0..<width {
                let index = y * width + x
                if visited[index] {
                    continue
                }
                visited[index] = true

                let (r, g, b, _) = pixels.rgbaAt(x: x, y: y)
                guard isBoardGreen(r: r, g: g, b: b) else {
                    continue
                }

                var queue = [index]
                var head = 0
                var count = 0
                var minX = x
                var maxX = x
                var minY = y
                var maxY = y

                while head < queue.count {
                    let current = queue[head]
                    head += 1

                    let cx = current % width
                    let cy = current / width
                    count += 1
                    minX = min(minX, cx)
                    maxX = max(maxX, cx)
                    minY = min(minY, cy)
                    maxY = max(maxY, cy)

                    for neighbor in neighbors(ofX: cx, y: cy, width: width, height: height) {
                        let nextIndex = neighbor.y * width + neighbor.x
                        if visited[nextIndex] {
                            continue
                        }
                        visited[nextIndex] = true

                        let rgba = pixels.rgbaAt(x: neighbor.x, y: neighbor.y)
                        if isBoardGreen(r: rgba.0, g: rgba.1, b: rgba.2) {
                            queue.append(nextIndex)
                        }
                    }
                }

                let rect = CGRect(
                    x: minX,
                    y: minY,
                    width: maxX - minX + 1,
                    height: maxY - minY + 1
                )

                let area = rect.width * rect.height
                guard count > 1_500, area > CGFloat(width * height) * 0.04 else {
                    continue
                }

                let squareSide = max(rect.width, rect.height)
                let squareRect = CGRect(
                    x: rect.midX - squareSide / 2,
                    y: rect.midY - squareSide / 2,
                    width: squareSide,
                    height: squareSide
                ).integral.insetBy(dx: 4, dy: 4)

                guard squareRect.minX >= 0,
                      squareRect.minY >= 0,
                      squareRect.maxX <= CGFloat(width),
                      squareRect.maxY <= CGFloat(height) else {
                    continue
                }

                let squareScore = 1.0 - abs(rect.width - rect.height) / max(rect.width, rect.height)
                let areaScore = Double((squareRect.width * squareRect.height) / CGFloat(width * height))
                let densityScore = Double(count) / Double(max(1.0, area))
                let centerScore = 1.0 - abs(squareRect.midY - CGFloat(height) * 0.52) / CGFloat(height)
                let score = squareScore * 4.0 + areaScore * 8.0 + densityScore * 2.5 + Double(max(0.0, centerScore))

                if score > bestScore {
                    bestScore = score
                    bestRect = squareRect
                }
            }
        }

        return bestRect
    }

    private static func detectBoardRectByGreenFrame(in image: CGImage) -> CGRect? {
        guard let pixels = pixelBuffer(from: image) else { return nil }

        let width = pixels.width
        let height = pixels.height
        let rowThreshold = Int(Double(width) * 0.46)
        let columnThreshold = Int(Double(height) * 0.24)

        let rowCounts = (0..<height).map { y in
            var count = 0
            for x in 0..<width {
                let rgba = pixels.rgbaAt(x: x, y: y)
                if isLineGreen(r: rgba.0, g: rgba.1, b: rgba.2) {
                    count += 1
                }
            }
            return count
        }
        let columnCounts = (0..<width).map { x in
            var count = 0
            for y in 0..<height {
                let rgba = pixels.rgbaAt(x: x, y: y)
                if isLineGreen(r: rgba.0, g: rgba.1, b: rgba.2) {
                    count += 1
                }
            }
            return count
        }

        let rowRuns = contiguousRuns(in: rowCounts, minimum: rowThreshold)
        let columnRuns = contiguousRuns(in: columnCounts, minimum: columnThreshold)
        guard let top = rowRuns.first,
              let bottom = rowRuns.last,
              let left = columnRuns.first,
              let right = columnRuns.last else {
            return nil
        }

        let rect = CGRect(
            x: left.start,
            y: top.start,
            width: right.end - left.start + 1,
            height: bottom.end - top.start + 1
        )
        let side = max(rect.width, rect.height)
        return CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        ).integral.insetBy(dx: 4, dy: 4)
    }

    private static func buildBoardGeometry(in image: CGImage, boardRect: CGRect) -> BoardGeometry? {
        guard let boardImage = cropImage(image, rectFromTopLeft: boardRect),
              let normalizedBoard = resize(boardImage, to: CGSize(width: normalizedBoardSide, height: normalizedBoardSide)),
              let pixels = pixelBuffer(from: normalizedBoard) else {
            return nil
        }

        let verticalLines = detectGridLineCenters(in: pixels, axis: .vertical) ?? equallySpacedLineCenters(side: normalizedBoardSide)
        let horizontalLines = detectGridLineCenters(in: pixels, axis: .horizontal) ?? equallySpacedLineCenters(side: normalizedBoardSide)

        guard verticalLines.count == 10, horizontalLines.count == 10 else {
            return nil
        }

        let scaleX = boardRect.width / CGFloat(normalizedBoardSide)
        let scaleY = boardRect.height / CGFloat(normalizedBoardSide)
        var cellRects = Array(repeating: Array(repeating: CGRect.zero, count: 9), count: 9)

        for row in 0..<9 {
            for col in 0..<9 {
                let left = verticalLines[col]
                let right = verticalLines[col + 1]
                let top = horizontalLines[row]
                let bottom = horizontalLines[row + 1]

                let cellRect = CGRect(
                    x: left,
                    y: top,
                    width: max(1.0, right - left),
                    height: max(1.0, bottom - top)
                )
                let insetX = max(4.0, cellRect.width * 0.14)
                let insetY = max(4.0, cellRect.height * 0.12)
                let innerRect = cellRect.insetBy(dx: insetX, dy: insetY)

                cellRects[row][col] = CGRect(
                    x: boardRect.minX + innerRect.minX * scaleX,
                    y: boardRect.minY + innerRect.minY * scaleY,
                    width: innerRect.width * scaleX,
                    height: innerRect.height * scaleY
                ).integral
            }
        }

        let refinedRect = CGRect(
            x: boardRect.minX + verticalLines[0] * scaleX,
            y: boardRect.minY + horizontalLines[0] * scaleY,
            width: (verticalLines[9] - verticalLines[0]) * scaleX,
            height: (horizontalLines[9] - horizontalLines[0]) * scaleY
        ).integral

        return BoardGeometry(boardRect: refinedRect, cellRects: cellRects)
    }

    private static func fallbackCellRects(for boardRect: CGRect) -> [[CGRect]] {
        let cellWidth = boardRect.width / 9
        let cellHeight = boardRect.height / 9
        return (0..<9).map { row in
            (0..<9).map { col in
                CGRect(
                    x: boardRect.minX + CGFloat(col) * cellWidth + cellWidth * 0.16,
                    y: boardRect.minY + CGFloat(row) * cellHeight + cellHeight * 0.12,
                    width: cellWidth * 0.68,
                    height: cellHeight * 0.74
                ).integral
            }
        }
    }

    private static func detectGridLineCenters(in pixels: PixelBuffer, axis: Axis) -> [CGFloat]? {
        let counts = axis == .vertical
            ? (0..<pixels.width).map { x in
                var count = 0
                for y in 0..<pixels.height {
                    let rgba = pixels.rgbaAt(x: x, y: y)
                    if isLineGreen(r: rgba.0, g: rgba.1, b: rgba.2) {
                        count += 1
                    }
                }
                return count
            }
            : (0..<pixels.height).map { y in
                var count = 0
                for x in 0..<pixels.width {
                    let rgba = pixels.rgbaAt(x: x, y: y)
                    if isLineGreen(r: rgba.0, g: rgba.1, b: rgba.2) {
                        count += 1
                    }
                }
                return count
            }

        let maxCount = counts.max() ?? 0
        guard maxCount > 0 else { return nil }

        let minimumRatios: [Double] = [0.78, 0.64, 0.52, 0.40]
        for ratio in minimumRatios {
            let threshold = Int(Double(maxCount) * ratio)
            let runs = contiguousRuns(in: counts, minimum: threshold)
            if let selected = selectLineCenters(from: runs, axisLength: counts.count) {
                return selected
            }
        }
        return nil
    }

    private static func selectLineCenters(from runs: [IndexRun], axisLength: Int) -> [CGFloat]? {
        guard !runs.isEmpty else { return nil }

        if runs.count == 10 {
            return runs.map(\.center)
        }
        if runs.count < 10 {
            return nil
        }

        let expected = equallySpacedLineCenters(side: axisLength)
        var chosen: [CGFloat] = []
        var used = Set<Int>()

        for target in expected {
            let candidate = runs.enumerated()
                .filter { !used.contains($0.offset) }
                .min { lhs, rhs in
                    abs(lhs.element.center - target) < abs(rhs.element.center - target)
                }

            guard let candidate else {
                continue
            }

            let tolerance = CGFloat(axisLength) / 11.0
            guard abs(candidate.element.center - target) <= tolerance else {
                continue
            }

            used.insert(candidate.offset)
            chosen.append(candidate.element.center)
        }

        guard chosen.count == 10 else {
            return nil
        }
        return chosen.sorted()
    }

    private static func recognizeDigit(in image: CGImage) -> DigitPrediction? {
        if let templatePrediction = recognizeDigitByTemplate(in: image) {
            return templatePrediction
        }

        guard let ocrDigit = recognizeDigitByOCR(in: image) else {
            return nil
        }
        return DigitPrediction(digit: ocrDigit, score: 0.35, secondBestScore: 1.0)
    }

    private static func recognizeDigitByOCR(in image: CGImage) -> Int? {
        let prepared = upscale(image, scale: 6) ?? image
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.18

        let handler = VNImageRequestHandler(cgImage: prepared, options: [:])
        try? handler.perform([request])

        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined()
            .filter(\.isNumber)

        guard text.count == 1, let value = Int(text), (1...9).contains(value) else {
            return nil
        }
        return value
    }

    private static func recognizeDigitByTemplate(in image: CGImage) -> DigitPrediction? {
        guard let observed = normalizedMask(from: image, targetSize: templateSize) else {
            return nil
        }

        var digitScores = Array(repeating: Double.greatestFiniteMagnitude, count: 10)
        var bestDigit = 0
        var bestScore = Double.greatestFiniteMagnitude
        var secondBestScore = Double.greatestFiniteMagnitude

        for digit in 1...9 {
            guard let templates = digitTemplates[digit] else { continue }
            for template in templates {
                let score = meanAbsoluteDifference(lhs: observed, rhs: template)
                digitScores[digit] = min(digitScores[digit], score)
                if score < bestScore {
                    secondBestScore = bestScore
                    bestScore = score
                    bestDigit = digit
                } else if score < secondBestScore {
                    secondBestScore = score
                }
            }
        }

        if let metrics = digitMetrics(in: image), digitScores[1] < 0.29, metrics.aspectRatio < 0.46 {
            let runnerUp = (2...9).map { digitScores[$0] }.min() ?? secondBestScore
            return DigitPrediction(digit: 1, score: digitScores[1], secondBestScore: runnerUp)
        }

        let margin = secondBestScore - bestScore
        guard bestDigit != 0,
              bestScore < 0.24,
              margin > 0.014 || bestScore < 0.095 else {
            return nil
        }

        return DigitPrediction(digit: bestDigit, score: bestScore, secondBestScore: secondBestScore)
    }

    private static func likelyContainsDigit(_ image: CGImage) -> Bool {
        guard let bounds = digitInkBounds(in: image) else {
            return false
        }

        let aspectRatio = Double(bounds.width) / Double(max(1, bounds.height))
        let narrowDigit = bounds.width >= 3
            && bounds.height > bounds.imageHeight / 2
            && aspectRatio < 0.28

        return bounds.darkCount > max(28, (bounds.imageWidth * bounds.imageHeight) / 55)
            && bounds.height > bounds.imageHeight / 4
            && (bounds.width > bounds.imageWidth / 5 || narrowDigit)
    }

    private static func pruneConflictingDigits(in grid: inout SudokuGrid, observations: [DigitObservation]) {
        let ranked = observations.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.row * 9 + lhs.col > rhs.row * 9 + rhs.col
            }
            return lhs.score > rhs.score
        }

        var changed = true
        while changed {
            changed = false
            for observation in ranked {
                guard grid[observation.row, observation.col] == observation.digit else {
                    continue
                }
                if !grid.isValidPlacement(row: observation.row, col: observation.col, value: observation.digit) {
                    grid[observation.row, observation.col] = 0
                    changed = true
                }
            }
        }
    }

    private static func fillLikelyOnes(in grid: inout SudokuGrid, image: CGImage, cellRects: [[CGRect]]) {
        for row in 0..<9 {
            for col in 0..<9 where grid[row, col] == 0 {
                guard let cellImage = cropImage(image, rectFromTopLeft: cellRects[row][col]),
                      likelyContainsDigit(cellImage),
                      let metrics = digitMetrics(in: cellImage),
                      metrics.aspectRatio < 0.36,
                      metrics.fillRatio < 0.23,
                      grid.isValidPlacement(row: row, col: col, value: 1) else {
                    continue
                }

                grid[row, col] = 1
            }
        }
    }

    private static func normalizedMask(from image: CGImage, targetSize: CGSize) -> [Double]? {
        guard let pixels = pixelBuffer(from: image) else { return nil }

        let width = pixels.width
        let height = pixels.height
        var points: [(x: Int, y: Int)] = []
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let rgba = pixels.rgbaAt(x: x, y: y)
                if isDigitInk(r: rgba.0, g: rgba.1, b: rgba.2) {
                    points.append((x, y))
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard !points.isEmpty, maxX >= minX, maxY >= minY else {
            return nil
        }

        let targetWidth = Int(targetSize.width)
        let targetHeight = Int(targetSize.height)
        let sourceWidth = maxX - minX + 1
        let sourceHeight = maxY - minY + 1
        let scale = min(
            Double(targetWidth - 4) / Double(sourceWidth),
            Double(targetHeight - 4) / Double(sourceHeight)
        )
        guard scale > 0 else {
            return nil
        }

        let scaledWidth = max(1, Int(Double(sourceWidth) * scale))
        let scaledHeight = max(1, Int(Double(sourceHeight) * scale))
        let offsetX = (targetWidth - scaledWidth) / 2
        let offsetY = (targetHeight - scaledHeight) / 2
        var mask = Array(repeating: 0.0, count: targetWidth * targetHeight)

        for point in points {
            let x = min(targetWidth - 1, max(0, Int(Double(point.x - minX) * scale) + offsetX))
            let y = min(targetHeight - 1, max(0, Int(Double(point.y - minY) * scale) + offsetY))
            mask[y * targetWidth + x] = 1.0
        }

        return mask
    }

    private static func digitInkBounds(in image: CGImage) -> InkBounds? {
        guard let pixels = pixelBuffer(from: image) else {
            return nil
        }

        var darkCount = 0
        var minX = pixels.width
        var minY = pixels.height
        var maxX = -1
        var maxY = -1

        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                let rgba = pixels.rgbaAt(x: x, y: y)
                if isDigitInk(r: rgba.0, g: rgba.1, b: rgba.2) {
                    darkCount += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard darkCount > 0, maxX >= minX, maxY >= minY else {
            return nil
        }

        return InkBounds(
            minX: minX,
            minY: minY,
            maxX: maxX,
            maxY: maxY,
            darkCount: darkCount,
            imageWidth: pixels.width,
            imageHeight: pixels.height
        )
    }

    private static func digitMetrics(in image: CGImage) -> DigitMetrics? {
        guard let bounds = digitInkBounds(in: image) else {
            return nil
        }

        return DigitMetrics(
            aspectRatio: Double(bounds.width) / Double(max(1, bounds.height)),
            fillRatio: Double(bounds.darkCount) / Double(max(1, bounds.imageWidth * bounds.imageHeight))
        )
    }

    private static func buildReferenceDigitTemplates() -> [Int: [[Double]]] {
        guard let image = loadReferenceBoardImage() else {
            return [:]
        }

        let boardRect = defaultBoardRect(for: image)
        let givens = Array(samplePuzzleString)
        guard givens.count == 81 else {
            return [:]
        }

        let cellRects = fallbackCellRects(for: boardRect)
        var templates: [Int: [[Double]]] = [:]
        for row in 0..<9 {
            for col in 0..<9 {
                let char = givens[row * 9 + col]
                guard char != "0",
                      let digit = Int(String(char)),
                      let cell = cropImage(image, rectFromTopLeft: cellRects[row][col]),
                      let mask = normalizedMask(from: cell, targetSize: templateSize) else {
                    continue
                }
                templates[digit, default: []].append(mask)
            }
        }
        return templates
    }

    private static func loadReferenceBoardImage() -> CGImage? {
        let candidateURLs = [
            Bundle.main.url(forResource: "debug-board", withExtension: "png"),
            URL(fileURLWithPath: "/Users/guokai/Desktop/数独/debug-board.png")
        ].compactMap { $0 }

        for url in candidateURLs {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                continue
            }
            return image
        }
        return nil
    }

    private static func defaultBoardRect(for image: CGImage) -> CGRect {
        CGRect(x: 4, y: 3, width: max(1, image.width - 8), height: max(1, image.height - 6))
    }

    private static func buildFontDigitTemplates() -> [Int: [[Double]]] {
        let fonts: [PlatformFont] = [
            .systemFont(ofSize: 54, weight: .bold),
            .monospacedDigitSystemFont(ofSize: 54, weight: .bold),
            PlatformFont(name: "Helvetica-Bold", size: 54),
            PlatformFont(name: "Arial-BoldMT", size: 54)
        ].compactMap { $0 }

        var templates: [Int: [[Double]]] = [:]
        for digit in 1...9 {
            templates[digit] = fonts.compactMap { font in
                templateMask(for: digit, font: font, targetSize: templateSize)
            }
        }
        return templates
    }

    private static func mergeTemplates(
        primary: [Int: [[Double]]],
        secondary: [Int: [[Double]]]
    ) -> [Int: [[Double]]] {
        var merged = secondary
        for digit in 1...9 {
            merged[digit] = (primary[digit] ?? []) + (secondary[digit] ?? [])
        }
        return merged
    }

    private static func templateMask(for digit: Int, font: PlatformFont, targetSize: CGSize) -> [Double]? {
        let canvas = CGSize(width: 90, height: 110)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(canvas.width),
                height: Int(canvas.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.setFillColor(PlatformColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: canvas))

        let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ctFont,
            .foregroundColor: PlatformColor.black
        ]
        let attributed = NSAttributedString(string: "\(digit)", attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        let x = (canvas.width - bounds.width) / 2 - bounds.minX
        let y = (canvas.height - bounds.height) / 2 - bounds.minY
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)

        guard let image = context.makeImage() else {
            return nil
        }
        return normalizedMask(from: image, targetSize: targetSize)
    }

    private static func meanAbsoluteDifference(lhs: [Double], rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            return .greatestFiniteMagnitude
        }
        let total = zip(lhs, rhs).reduce(0.0) { partial, pair in
            partial + abs(pair.0 - pair.1)
        }
        return total / Double(lhs.count)
    }

    private static func contiguousRuns(in counts: [Int], minimum: Int) -> [IndexRun] {
        guard minimum > 0 else { return [] }

        var runs: [IndexRun] = []
        var start: Int?
        for (index, count) in counts.enumerated() {
            if count >= minimum {
                if start == nil {
                    start = index
                }
            } else if let rangeStart = start {
                runs.append(IndexRun(start: rangeStart, end: index - 1))
                start = nil
            }
        }
        if let start {
            runs.append(IndexRun(start: start, end: counts.count - 1))
        }
        return runs
    }

    private static func equallySpacedLineCenters(side: Int) -> [CGFloat] {
        (0...9).map { index in
            CGFloat(index) * CGFloat(side - 1) / 9.0
        }
    }

    private static func neighbors(ofX x: Int, y: Int, width: Int, height: Int) -> [(x: Int, y: Int)] {
        let candidates = [
            (x - 1, y),
            (x + 1, y),
            (x, y - 1),
            (x, y + 1)
        ]
        return candidates.filter { candidate in
            candidate.0 >= 0 && candidate.0 < width && candidate.1 >= 0 && candidate.1 < height
        }.map { (x: $0.0, y: $0.1) }
    }

    private static func isBoardOnlyImage(width: Int, height: Int) -> Bool {
        abs(width - height) < max(width, height) / 5
    }

    private static func isBoardGreen(r: Int, g: Int, b: Int) -> Bool {
        g > 100 && g > r + 26 && g > b + 18
    }

    private static func isLineGreen(r: Int, g: Int, b: Int) -> Bool {
        g > 120 && g > r + 38 && g > b + 24
    }

    private static func isDigitInk(r: Int, g: Int, b: Int) -> Bool {
        r < 155 && g < 155 && b < 155 && abs(r - g) < 42 && abs(r - b) < 42
    }

    private static func pixelBuffer(from image: CGImage) -> PixelBuffer? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var bytes = Array(repeating: UInt8(0), count: bytesPerRow * height)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let success = bytes.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let base = rawBuffer.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return false
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard success else {
            return nil
        }
        return PixelBuffer(data: bytes, width: width, height: height, bytesPerRow: bytesPerRow)
    }

    private static func cropImage(_ image: CGImage, rectFromTopLeft: CGRect) -> CGImage? {
        let bounded = rectFromTopLeft.integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard bounded.width >= 1, bounded.height >= 1 else {
            return nil
        }
        return image.cropping(to: bounded)
    }

    private static func resize(_ image: CGImage, to size: CGSize) -> CGImage? {
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.setFillColor(PlatformColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    private static func upscale(_ image: CGImage, scale: Int) -> CGImage? {
        resize(image, to: CGSize(width: image.width * scale, height: image.height * scale))
    }

    private enum Axis {
        case horizontal
        case vertical
    }

    private struct BoardGeometry {
        let boardRect: CGRect
        let cellRects: [[CGRect]]
    }

    private struct DigitPrediction {
        let digit: Int
        let score: Double
        let secondBestScore: Double
    }

    private struct DigitObservation {
        let row: Int
        let col: Int
        let digit: Int
        let score: Double
    }

    private struct DigitMetrics {
        let aspectRatio: Double
        let fillRatio: Double
    }

    private struct IndexRun {
        let start: Int
        let end: Int

        var center: CGFloat {
            CGFloat(start + end) / 2.0
        }
    }

    private struct PixelBuffer {
        let data: [UInt8]
        let width: Int
        let height: Int
        let bytesPerRow: Int

        func rgbaAt(x: Int, y: Int) -> (Int, Int, Int, Int) {
            let offset = y * bytesPerRow + x * 4
            return (
                Int(data[offset]),
                Int(data[offset + 1]),
                Int(data[offset + 2]),
                Int(data[offset + 3])
            )
        }
    }

    private struct InkBounds {
        let minX: Int
        let minY: Int
        let maxX: Int
        let maxY: Int
        let darkCount: Int
        let imageWidth: Int
        let imageHeight: Int

        var width: Int {
            maxX - minX + 1
        }

        var height: Int {
            maxY - minY + 1
        }
    }
}
