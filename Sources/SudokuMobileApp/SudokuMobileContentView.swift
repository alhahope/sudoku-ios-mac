import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct SudokuMobileContentView: View {
    @ObservedObject var viewModel: SudokuMobileViewModel
    @State private var gridString = ""
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color(red: 0.96, green: 0.99, blue: 0.96), Color(red: 0.89, green: 0.95, blue: 0.91)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) {
                            boardColumn
                            previewColumn
                                .frame(width: 320)
                        }
                        VStack(spacing: 20) {
                            boardColumn
                            previewColumn
                        }
                    }
                    .frame(maxWidth: 980)
                    .padding(.horizontal, 20)
                    .padding(.top, proxy.safeAreaInsets.top + 12)
                    .padding(.bottom, max(28, proxy.safeAreaInsets.bottom + 12))
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(Color(red: 0.96, green: 0.99, blue: 0.96))
        }
        .tint(Color(red: 0.08, green: 0.60, blue: 0.36))
        .onChange(of: selectedPhotoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.importImageData(data)
                    gridString = viewModel.gridString
                } else {
                    viewModel.status = "无法读取所选图片。"
                }
                selectedPhotoItem = nil
            }
        }
        .fileImporter(
            isPresented: $viewModel.isPresentingImporter,
            allowedContentTypes: [.png, .jpeg, .heic, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importImageFromFile(url: url)
                    gridString = viewModel.gridString
                }
            case .failure(let error):
                viewModel.status = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $viewModel.isPresentingExporter,
            document: viewModel.exportDocument,
            contentType: .png,
            defaultFilename: viewModel.exportFilename
        ) { result in
            viewModel.handleExportResult(result)
        }
    }

    private var boardColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerCard

            SudokuMobileBoardView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

            keypad

            buttonGrid

            gridStringCard
        }
        .padding(20)
        .background(.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("数独求解器")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.23, blue: 0.16))
            Text("手机端版")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 0.33))
            Text("手动输入、自动识别、求解与答案导出都保留下来了。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.55, green: 0.61, blue: 0.58))
            Text(viewModel.status)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.17, green: 0.37, blue: 0.27))
                .padding(.top, 4)
        }
    }

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
            ForEach(1..<10) { number in
                Button("\(number)") {
                    viewModel.input(number)
                }
                .buttonStyle(MobileKeypadButtonStyle(fill: Color(red: 0.10, green: 0.61, blue: 0.39)))
            }

            Button("清除") {
                viewModel.clearSelected()
            }
            .buttonStyle(MobileKeypadButtonStyle(fill: Color(red: 0.82, green: 0.29, blue: 0.24)))
        }
    }

    private var buttonGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                actionLabel("照片导入", color: Color(red: 0.14, green: 0.55, blue: 0.38))
            }
            .buttonStyle(.plain)

            Button {
                viewModel.isPresentingImporter = true
            } label: {
                actionLabel("文件导入", color: Color(red: 0.16, green: 0.46, blue: 0.71))
            }
            .buttonStyle(.plain)

            Button {
                viewModel.solvePuzzle()
            } label: {
                actionLabel("一键求解", color: Color(red: 0.93, green: 0.63, blue: 0.14))
            }
            .buttonStyle(.plain)

            Button {
                viewModel.prepareExport()
            } label: {
                actionLabel("导出答案图", color: Color(red: 0.12, green: 0.39, blue: 0.78))
            }
            .buttonStyle(.plain)

            Button {
                viewModel.clearAll()
                gridString = ""
            } label: {
                actionLabel("清空", color: Color(red: 0.65, green: 0.25, blue: 0.22))
            }
            .buttonStyle(.plain)
        }
    }

    private var gridStringCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("81 位题面字符串")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            TextField("用 0 表示空格", text: $gridString, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 13, design: .monospaced))
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            Button("填入题面") {
                viewModel.pasteGridString(gridString)
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(red: 0.10, green: 0.43, blue: 0.70))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("截图与答案预览")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            previewCard(title: "原始截图", image: viewModel.importedImage)
            previewCard(title: "答案叠加图", image: viewModel.solutionPreview)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.08, green: 0.16, blue: 0.13).opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func previewCard(title: String, image: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(10)
                } else {
                    VStack(spacing: 8) {
                        Text("还没有内容")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                        Text("导入截图并求解后，这里会显示预览。")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                            .multilineTextAlignment(.center)
                    }
                    .padding(18)
                }
            }
            .frame(height: 240)
        }
    }

    private func actionLabel(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MobileKeypadButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(fill.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
