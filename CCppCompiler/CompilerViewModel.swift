import Foundation

@MainActor
final class CompilerViewModel: ObservableObject {
    private enum DefaultsKey {
        static let useRemoteCompiler = "compiler.useRemoteCompiler"
        static let endpoint = "compiler.endpoint"
    }

    @Published var selectedLanguage: SourceLanguage = .cpp {
        didSet {
            if sourceCode == oldValue.defaultTemplate || sourceCode.isEmpty {
                sourceCode = selectedLanguage.defaultTemplate
            }
        }
    }
    @Published var sourceCode: String
    @Published var standardInput = ""
    @Published var output = "Start the backend server, then tap Compile to build and run code."
    @Published var isCompiling = false
    @Published var useRemoteCompiler: Bool {
        didSet {
            UserDefaults.standard.set(useRemoteCompiler, forKey: DefaultsKey.useRemoteCompiler)
        }
    }
    @Published var endpointText: String {
        didSet {
            UserDefaults.standard.set(endpointText, forKey: DefaultsKey.endpoint)
        }
    }

    init() {
        sourceCode = SourceLanguage.cpp.defaultTemplate
        useRemoteCompiler = UserDefaults.standard.object(forKey: DefaultsKey.useRemoteCompiler) as? Bool ?? true
        endpointText = UserDefaults.standard.string(forKey: DefaultsKey.endpoint) ?? "http://127.0.0.1:8080/compile"
    }

    func loadExample() {
        sourceCode = selectedLanguage.defaultTemplate
        output = "Loaded the \(selectedLanguage.rawValue) example."
    }

    func compile() async {
        isCompiling = true
        output = "Compiling \(selectedLanguage.rawValue) source..."
        defer { isCompiling = false }

        do {
            let service = try makeService()
            let result = try await service.compile(
                source: sourceCode,
                language: selectedLanguage,
                stdin: standardInput
            )
            output = format(result: result)
        } catch {
            output = "Request failed.\n\n\(error.localizedDescription)"
        }
    }

    private func makeService() throws -> CompilerService {
        guard useRemoteCompiler else {
            return MockCompilerService()
        }

        guard let endpoint = URL(string: endpointText), endpoint.scheme != nil else {
            throw CompilerError.invalidEndpoint
        }

        return RemoteCompilerService(endpoint: endpoint)
    }

    private func format(result: CompileResponse) -> String {
        var chunks: [String] = []
        chunks.append(result.success ? "Status: Success" : "Status: Failed")
        chunks.append("Exit code: \(result.exitCode)")
        chunks.append("Duration: \(result.durationMs) ms")

        if !result.stdout.isEmpty {
            chunks.append("STDOUT\n\(result.stdout)")
        }

        if !result.stderr.isEmpty {
            chunks.append("STDERR\n\(result.stderr)")
        }

        return chunks.joined(separator: "\n\n")
    }

    var endpointHint: String {
        if endpointText.contains("127.0.0.1") || endpointText.contains("localhost") {
            return "Use 127.0.0.1 for the iOS Simulator. For a real iPhone, replace it with your Mac's local IP, like http://192.168.1.20:8080/compile."
        }

        return "Your phone and your server must be on the same network unless the backend is deployed publicly."
    }
}
