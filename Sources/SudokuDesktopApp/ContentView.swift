import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: SudokuAppViewModel
    @State private var gridString = ""

    var body: some View {
        HStack(spacing: 24) {
            leftPanel
            rightPanel
        }
        .padding(28)
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 0.96), Color(red: 0.90, green: 0.95, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("数独求解器")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("先把题做出来，再逐步增强自动识别。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            SudokuBoardView(viewModel: viewModel)
                .frame(width: 560, height: 560)

            keypad

            HStack(spacing: 12) {
                actionButton("导入截图", color: Color(red: 0.14, green: 0.55, blue: 0.38)) {
                    viewModel.importImage()
                    gridString = viewModel.gridString
                }
                actionButton("一键求解", color: Color(red: 0.93, green: 0.63, blue: 0.14)) {
                    viewModel.solvePuzzle()
                }
                actionButton("导出答案图", color: Color(red: 0.10, green: 0.43, blue: 0.70)) {
                    viewModel.exportSolutionImage()
                }
                actionButton("清空", color: Color(red: 0.65, green: 0.25, blue: 0.22)) {
                    viewModel.clearAll()
                    gridString = ""
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("81 位题面字符串")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                HStack(spacing: 10) {
                    TextField("用 0 表示空格", text: $gridString)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                    Button("填入") {
                        viewModel.pasteGridString(gridString)
                    }
                }
            }

            Text(viewModel.status)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }

    private var keypad: some View {
        HStack(spacing: 10) {
            ForEach(1..<10) { number in
                Button("\(number)") { viewModel.input(number) }
                    .buttonStyle(KeypadButtonStyle(fill: Color(red: 0.09, green: 0.62, blue: 0.39)))
            }
            Button("清除") { viewModel.clearSelected() }
                .buttonStyle(KeypadButtonStyle(fill: Color(red: 0.82, green: 0.29, blue: 0.24)))
        }
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("截图与答案预览")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            previewCard(title: "原始截图", image: viewModel.importedImage)
            previewCard(title: "答案叠加图", image: viewModel.solutionPreview)

            Spacer()
        }
        .padding(24)
        .frame(width: 420)
        .frame(maxHeight: .infinity)
        .background(Color(red: 0.08, green: 0.16, blue: 0.13).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func previewCard(title: String, image: NSImage?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(10)
                } else {
                    VStack(spacing: 8) {
                        Text("还没有内容")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                        Text("导入截图后，这里会显示预览。")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .frame(height: 260)
        }
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(color)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(fill.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
