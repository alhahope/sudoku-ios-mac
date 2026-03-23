import SwiftUI

struct SudokuMobileBoardView: View {
    @ObservedObject var viewModel: SudokuMobileViewModel

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                SudokuMobileCellView(
                                    value: viewModel.valueAt(row: row, col: col),
                                    isOriginal: viewModel.isOriginal(row: row, col: col),
                                    isSelected: viewModel.selectedCell == .init(row: row, col: col),
                                    isAlternate: ((row / 3) + (col / 3)).isMultiple(of: 2)
                                )
                                .frame(width: cell, height: cell)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.setSelected(row, col)
                                }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                gridLines(side: side, cell: cell)
            }
        }
    }

    private func gridLines(side: CGFloat, cell: CGFloat) -> some View {
        Canvas { context, _ in
            for index in 0...9 {
                var vertical = Path()
                vertical.move(to: CGPoint(x: CGFloat(index) * cell, y: 0))
                vertical.addLine(to: CGPoint(x: CGFloat(index) * cell, y: side))
                context.stroke(
                    vertical,
                    with: .color(Color.green.opacity(index.isMultiple(of: 3) ? 0.95 : 0.35)),
                    lineWidth: index.isMultiple(of: 3) ? 3 : 1
                )

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: CGFloat(index) * cell))
                horizontal.addLine(to: CGPoint(x: side, y: CGFloat(index) * cell))
                context.stroke(
                    horizontal,
                    with: .color(Color.green.opacity(index.isMultiple(of: 3) ? 0.95 : 0.35)),
                    lineWidth: index.isMultiple(of: 3) ? 3 : 1
                )
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }
}

private struct SudokuMobileCellView: View {
    let value: Int
    let isOriginal: Bool
    let isSelected: Bool
    let isAlternate: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isSelected ? Color(red: 0.83, green: 0.95, blue: 0.86) : (isAlternate ? Color.white : Color(red: 0.96, green: 1.0, blue: 0.97)))
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isOriginal ? Color.black : Color.red)
            }
        }
    }
}
