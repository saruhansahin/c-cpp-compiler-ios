import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = CompilerViewModel()
    @State private var isImporterPresented = false
    @State private var isExporterPresented = false
    @State private var exportDocument = SourceCodeDocument()
    @State private var exportContentType: UTType = .plainText
    @State private var fileErrorMessage: String?
    @State private var bannerMessage: String?

    var body: some View {
        GeometryReader { geometry in
            let wideLayout = geometry.size.width > 960

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.08, blue: 0.12),
                        Color(red: 0.08, green: 0.12, blue: 0.18),
                        Color(red: 0.04, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(red: 0.17, green: 0.47, blue: 0.72).opacity(0.22))
                    .frame(width: 420)
                    .blur(radius: 40)
                    .offset(x: 220, y: -280)

                Circle()
                    .fill(Color(red: 0.92, green: 0.53, blue: 0.18).opacity(0.14))
                    .frame(width: 340)
                    .blur(radius: 50)
                    .offset(x: -260, y: 300)

                if wideLayout {
                    HStack(alignment: .top, spacing: 18) {
                        explorerSidebar
                            .frame(width: min(250, geometry.size.width * 0.24))

                        VStack(spacing: 18) {
                            toolbar(isCompact: false)

                            HStack(alignment: .top, spacing: 18) {
                                editorPanel(minHeight: max(380, geometry.size.height * 0.56))

                                VStack(spacing: 18) {
                                    inspectorPanel
                                    consolePanel(minHeight: max(220, geometry.size.height * 0.26))
                                }
                                .frame(width: min(340, geometry.size.width * 0.30))
                            }
                        }
                    }
                    .padding(18)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            toolbar(isCompact: true)
                            explorerSidebar
                            editorPanel(minHeight: 360)
                            inspectorPanel
                            consolePanel(minHeight: 220)
                        }
                        .padding(16)
                    }
                }
            }
            .overlay(alignment: .top) {
                if let bannerMessage {
                    BannerView(message: bannerMessage)
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .preferredColorScheme(.dark)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: SourceCodeDocument.supportedContentTypes,
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .fileExporter(
                isPresented: $isExporterPresented,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: viewModel.currentFileName,
                onCompletion: handleExport
            )
            .alert(
                "File Error",
                isPresented: Binding(
                    get: { fileErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            fileErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    fileErrorMessage = nil
                }
            } message: {
                Text(fileErrorMessage ?? "")
            }
        }
    }

    private func toolbar(isCompact: Bool) -> some View {
        IDEPanel {
            if isCompact {
                VStack(alignment: .leading, spacing: 14) {
                    brandBlock
                    languageControl
                    actionBar(compact: true)
                }
            } else {
                HStack(spacing: 16) {
                    brandBlock
                    Spacer(minLength: 12)
                    languageControl
                    Spacer(minLength: 12)
                    actionBar(compact: false)
                }
            }
        }
    }

    private var brandBlock: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.53, blue: 0.84),
                            Color(red: 0.10, green: 0.24, blue: 0.46)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Mobile C/C++ IDE")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Xcode ve VS Code tarzinda derleyici arayuzu")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
        }
    }

    private var languageControl: some View {
        HStack(spacing: 8) {
            ForEach(SourceLanguage.allCases) { language in
                Button {
                    viewModel.selectedLanguage = language
                } label: {
                    Text(language.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(viewModel.selectedLanguage == language ? .white : Color.white.opacity(0.65))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    viewModel.selectedLanguage == language
                                        ? Color(red: 0.18, green: 0.46, blue: 0.72)
                                        : Color.white.opacity(0.06)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.25))
        )
    }

    private func actionBar(compact: Bool) -> some View {
        let buttons = HStack(spacing: 10) {
            ToolbarActionButton(title: "New", icon: "doc.badge.plus", tint: Color.white.opacity(0.08)) {
                viewModel.newDocument()
                showBanner("New source file created")
            }

            ToolbarActionButton(title: "Open", icon: "folder", tint: Color.white.opacity(0.08)) {
                isImporterPresented = true
            }

            ToolbarActionButton(title: "Save As", icon: "square.and.arrow.down", tint: Color.white.opacity(0.08)) {
                exportDocument = SourceCodeDocument(text: viewModel.sourceCode)
                exportContentType = viewModel.selectedLanguage.exportContentType
                isExporterPresented = true
            }

            ToolbarActionButton(title: "Example", icon: "wand.and.stars", tint: Color.white.opacity(0.08)) {
                viewModel.loadExample()
                showBanner("Example loaded")
            }

            Button {
                Task {
                    await viewModel.compile()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isCompiling {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                    }

                    Text(viewModel.isCompiling ? "Running" : "Run")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.16, green: 0.56, blue: 0.92),
                                    Color(red: 0.09, green: 0.31, blue: 0.68)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompiling)
        }

        if compact {
            return AnyView(
                ScrollView(.horizontal, showsIndicators: false) {
                    buttons
                }
            )
        }

        return AnyView(buttons)
    }

    private var explorerSidebar: some View {
        IDEPanel(title: "Explorer", subtitle: "Workspace") {
            VStack(alignment: .leading, spacing: 12) {
                ExplorerRow(
                    icon: "doc.text.fill",
                    title: viewModel.currentFileName,
                    subtitle: "\(viewModel.selectedLanguage.rawValue) source file",
                    accent: Color(red: 0.23, green: 0.53, blue: 0.87),
                    isActive: true
                )

                ExplorerRow(
                    icon: "terminal.fill",
                    title: "stdin",
                    subtitle: viewModel.standardInput.isEmpty ? "No program input" : "Input ready",
                    accent: Color(red: 0.88, green: 0.58, blue: 0.18)
                )

                ExplorerRow(
                    icon: "server.rack",
                    title: viewModel.backendLabel,
                    subtitle: viewModel.useRemoteCompiler ? "Connected to compiler backend" : "UI demo mode",
                    accent: Color(red: 0.24, green: 0.72, blue: 0.48)
                )

                ExplorerRow(
                    icon: "list.bullet.rectangle.portrait",
                    title: "Console",
                    subtitle: viewModel.outputStatusLabel,
                    accent: viewModel.outputStatusColor
                )

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 10) {
                    StatChip(icon: "line.3.horizontal", title: "\(viewModel.lineCount) lines")
                    StatChip(icon: "textformat.abc", title: "\(viewModel.characterCount) chars")
                    StatChip(icon: "externaldrive.fill.badge.checkmark", title: viewModel.draftLabel)
                    StatChip(icon: "folder.badge.gearshape", title: "Open ve Save As aktif")
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Files")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))

                    Text("Open: Files uygulamasindan kaynak kodu alir.\nSave As: Dosyayi Files veya iCloud Drive'a yazar.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
        }
    }

    private func editorPanel(minHeight: CGFloat) -> some View {
        IDEPanel {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TrafficLightsView()

                    HStack(spacing: 10) {
                        Image(systemName: "chevron.left.slash.chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.39, green: 0.68, blue: 0.97))

                        Text(viewModel.currentFileName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(viewModel.selectedLanguage.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )

                    Spacer()

                    Text("\(viewModel.lineCount) lines • UTF-8")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(14)

                Divider()
                    .overlay(Color.white.opacity(0.08))

                TextEditor(text: $viewModel.sourceCode)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(red: 0.90, green: 0.94, blue: 0.98))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .frame(minHeight: minHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.05, green: 0.07, blue: 0.10).opacity(0.96))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .padding(14)
            }
        }
    }

    private var inspectorPanel: some View {
        IDEPanel(title: "Run Configuration", subtitle: "Input, backend ve file actions") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("File Name")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))

                    TextField("main.cpp", text: $viewModel.currentFileName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Standard Input")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))

                    TextEditor(text: $viewModel.standardInput)
                        .scrollContentBackground(.hidden)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(red: 0.89, green: 0.94, blue: 0.98))
                        .padding(12)
                        .frame(height: 108)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.black.opacity(0.28))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }

                Toggle(isOn: $viewModel.useRemoteCompiler) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Use Live Compiler Server")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(viewModel.backendLabel)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .tint(Color(red: 0.17, green: 0.54, blue: 0.85))

                if viewModel.useRemoteCompiler {
                    TextField("http://127.0.0.1:8080/compile", text: $viewModel.endpointText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    Text(viewModel.endpointHint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                } else {
                    Text("Mock mode yalnizca arayuz testi icin. Gercek derleme icin live server acik olmali.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                }

                HStack(spacing: 10) {
                    ToolbarActionButton(title: "Open", icon: "folder", tint: Color.white.opacity(0.08)) {
                        isImporterPresented = true
                    }

                    ToolbarActionButton(title: "Save As", icon: "square.and.arrow.down", tint: Color.white.opacity(0.08)) {
                        exportDocument = SourceCodeDocument(text: viewModel.sourceCode)
                        exportContentType = viewModel.selectedLanguage.exportContentType
                        isExporterPresented = true
                    }
                }

                Button {
                    Task {
                        await viewModel.compile()
                    }
                } label: {
                    HStack {
                        Spacer()

                        if viewModel.isCompiling {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Compile & Run")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }

                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.50, blue: 0.80),
                                        Color(red: 0.09, green: 0.32, blue: 0.63)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isCompiling)
            }
        }
    }

    private func consolePanel(minHeight: CGFloat) -> some View {
        IDEPanel(title: "Console", subtitle: "Build and runtime output") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(viewModel.outputStatusColor)
                        .frame(width: 10, height: 10)

                    Text(viewModel.outputStatusLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(viewModel.draftLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                }

                ScrollView {
                    Text(viewModel.output)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(red: 0.87, green: 0.94, blue: 0.99))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: minHeight)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.05, green: 0.07, blue: 0.10).opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if didAccessSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let fileContents = try String(contentsOf: url, encoding: .utf8)
                viewModel.loadDocument(text: fileContents, fileName: url.lastPathComponent)
                showBanner("Opened \(url.lastPathComponent)")
            } catch {
                fileErrorMessage = "Could not open the selected file.\n\(error.localizedDescription)"
            }

        case let .failure(error):
            fileErrorMessage = "Could not open the selected file.\n\(error.localizedDescription)"
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            viewModel.didExport(to: url.lastPathComponent)
            showBanner("Saved \(url.lastPathComponent)")

        case let .failure(error):
            fileErrorMessage = "Could not save the selected file.\n\(error.localizedDescription)"
        }
    }

    private func showBanner(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
            bannerMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if bannerMessage == message {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                    bannerMessage = nil
                }
            }
        }
    }
}

private struct IDEPanel<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.52))
                    }
                }
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ToolbarActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ExplorerRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    var isActive = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.18))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.52))
            }

            Spacer()

            if isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent)
                    .frame(width: 4, height: 28)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isActive ? Color.white.opacity(0.06) : Color.black.opacity(0.18))
        )
    }
}

private struct StatChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.72))

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.22))
        )
    }
}

private struct TrafficLightsView: View {
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(Color(red: 0.96, green: 0.39, blue: 0.34))
            Circle().fill(Color(red: 0.98, green: 0.76, blue: 0.22))
            Circle().fill(Color(red: 0.23, green: 0.79, blue: 0.35))
        }
        .frame(width: 44)
    }
}

private struct BannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.25, green: 0.76, blue: 0.47))

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
