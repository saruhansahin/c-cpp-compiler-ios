import Foundation

@MainActor
final class CompilerViewModel: ObservableObject {
    @Published var selectedLanguage: SourceLanguage = .cpp {
        didSet {
            if sourceCode == oldValue.defaultTemplate || sourceCode.isEmpty {
                sourceCode = selectedLanguage.defaultTemplate
            }
        }
    }
    @Published var sourceCode: String
    @Published var standardInput = ""
    @Published var output = "Tap Compile to see build output."
    @Published var isCompiling = false
    @Published var useRemoteCompiler = false
    @Published var endpointText = "http://localhost:8080/compile"

    init() {
        sourceCode = SourceLanguage.cpp.defaultTemplate
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
}
