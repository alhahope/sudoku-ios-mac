import SwiftUI

struct SudokuBoardView: View {
    @ObservedObject var viewModel: SudokuAppViewModel
    @FocusState private var isKeyboardFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 20, y: 10)

                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                SudokuCellView(
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
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                gridLines(side: side, cell: cell)
            }
            .overlay {
                KeyboardCaptureView { event in
                    handleKeyEvent(event)
                }
                .focused($isKeyboardFocused)
            }
            .onTapGesture {
                isKeyboardFocused = true
            }
            .onAppear {
                isKeyboardFocused = true
            }
        }
    }

    private func gridLines(side: CGFloat, cell: CGFloat) -> some View {
        Canvas { context, size in
            for index in 0...9 {
                var vertical = Path()
                vertical.move(to: CGPoint(x: CGFloat(index) * cell, y: 0))
                vertical.addLine(to: CGPoint(x: CGFloat(index) * cell, y: side))
                context.stroke(vertical, with: .color(Color.green.opacity(index.isMultiple(of: 3) ? 0.95 : 0.35)), lineWidth: index.isMultiple(of: 3) ? 3 : 1)

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: CGFloat(index) * cell))
                horizontal.addLine(to: CGPoint(x: side, y: CGFloat(index) * cell))
                context.stroke(horizontal, with: .color(Color.green.opacity(index.isMultiple(of: 3) ? 0.95 : 0.35)), lineWidth: index.isMultiple(of: 3) ? 3 : 1)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard event.type == .keyDown else { return }

        switch event.keyCode {
        case 123:
            viewModel.moveSelection(rowDelta: 0, colDelta: -1)
            return
        case 124:
            viewModel.moveSelection(rowDelta: 0, colDelta: 1)
            return
        case 125:
            viewModel.moveSelection(rowDelta: 1, colDelta: 0)
            return
        case 126:
            viewModel.moveSelection(rowDelta: -1, colDelta: 0)
            return
        case 51, 117:
            viewModel.clearSelected()
            return
        default:
            break
        }

        guard let characters = event.charactersIgnoringModifiers else { return }
        for char in characters {
            if char == "0" {
                viewModel.clearSelected()
                return
            }

            if let value = Int(String(char)), (1...9).contains(value) {
                viewModel.input(value)
                return
            }
        }
    }
}

private struct SudokuCellView: View {
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
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(isOriginal ? Color.black : Color.red)
            }
        }
    }
}

private struct KeyboardCaptureView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyAwareView {
        let view = KeyAwareView()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyAwareView, context: Context) {
        nsView.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyAwareView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}
