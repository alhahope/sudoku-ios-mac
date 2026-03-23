import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

public enum SudokuImageRenderer {
    public static func renderSolution(
        on image: CGImage,
        boardRect: CGRect,
        original: SudokuGrid,
        solved: SudokuGrid
    ) throws -> CGImage {
        let width = image.width
        let height = image.height
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw SudokuError.cannotCreateContext
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let cellWidth = boardRect.width / 9
        let cellHeight = boardRect.height / 9
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, min(cellWidth, cellHeight) * 0.56, nil)
        let color = PlatformColor.systemRed.cgColor

        for row in 0..<9 {
            for col in 0..<9 where original[row, col] == 0 {
                let text = NSAttributedString(
                    string: "\(solved[row, col])",
                    attributes: [
                        .font: font,
                        .foregroundColor: color
                    ]
                )
                let line = CTLineCreateWithAttributedString(text)
                let bounds = CTLineGetBoundsWithOptions(line, [])
                let x = boardRect.minX + CGFloat(col) * cellWidth + (cellWidth - bounds.width) / 2 - bounds.minX
                let yTop = boardRect.minY + CGFloat(row) * cellHeight + (cellHeight - bounds.height) / 2 - 2
                let y = CGFloat(height) - yTop - bounds.height - bounds.minY
                context.textPosition = CGPoint(x: x, y: y)
                CTLineDraw(line, context)
            }
        }

        guard let output = context.makeImage() else {
            throw SudokuError.cannotCreateContext
        }
        return output
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw SudokuError.cannotWriteImage(url.path)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw SudokuError.cannotWriteImage(url.path)
        }
    }
}
