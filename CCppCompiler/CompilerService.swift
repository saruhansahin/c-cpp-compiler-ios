import Foundation

protocol CompilerService {
    func compile(source: String, language: SourceLanguage, stdin: String) async throws -> CompileResponse
}

struct MockCompilerService: CompilerService {
    func compile(source: String, language: SourceLanguage, stdin: String) async throws -> CompileResponse {
        try await Task.sleep(nanoseconds: 600_000_000)

        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSource.isEmpty else {
            return CompileResponse(
                success: false,
                stdout: "",
                stderr: "error: source file is empty",
                exitCode: 1,
                durationMs: 2
            )
        }

        let hasMain = normalizedSource.contains("main(")
        let looksBroken = normalizedSource.contains("syntax_error") || normalizedSource.contains("printf(") && !normalizedSource.contains(";")

        if !hasMain {
            return CompileResponse(
                success: false,
                stdout: "",
                stderr: "linker error: missing entry point `main`",
                exitCode: 1,
                durationMs: 11
            )
        }

        if looksBroken {
            return CompileResponse(
                success: false,
                stdout: "",
                stderr: "compiler error: simulated syntax failure near line 1",
                exitCode: 1,
                durationMs: 17
            )
        }

        let output = language == .c ? "Hello from the mock C compiler." : "Hello from the mock C++ compiler."
        let stdinBlock = stdin.isEmpty ? "" : "\nstdin:\n\(stdin)"

        return CompileResponse(
            success: true,
            stdout: "\(output)\nBuild completed successfully.\(stdinBlock)\n",
            stderr: "",
            exitCode: 0,
            durationMs: 42
        )
    }
}

struct RemoteCompilerService: CompilerService {
    let endpoint: URL

    func compile(source: String, language: SourceLanguage, stdin: String) async throws -> CompileResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            CompileRequest(language: language.apiValue, source: source, stdin: stdin)
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CompilerError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
            throw CompilerError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(CompileResponse.self, from: data)
        } catch {
            throw CompilerError.invalidResponse
        }
    }
}
