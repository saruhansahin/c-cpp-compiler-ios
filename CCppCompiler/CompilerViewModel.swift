import Foundation
import SwiftUI

@MainActor
final class CompilerViewModel: ObservableObject {
    private enum DefaultsKey {
        static let selectedLanguage = "compiler.selectedLanguage"
        static let useRemoteCompiler = "compiler.useRemoteCompiler"
        static let endpoint = "compiler.endpoint"
        static let sourceCode = "compiler.sourceCode"
        static let standardInput = "compiler.standardInput"
        static let currentFileName = "compiler.currentFileName"
    }

    @Published var selectedLanguage: SourceLanguage = .cpp {
        didSet {
            UserDefaults.standard.set(selectedLanguage.apiValue, forKey: DefaultsKey.selectedLanguage)

            if sourceCode == oldValue.defaultTemplate || sourceCode.isEmpty {
                sourceCode = selectedLanguage.defaultTemplate
            }

            if URL(fileURLWithPath: currentFileName).pathExtension.lowercased() == oldValue.fileExtension {
                currentFileName = replacingFileExtension(in: currentFileName, with: selectedLanguage.fileExtension)
            }
        }
    }
    @Published var sourceCode: String {
        didSet {
            UserDefaults.standard.set(sourceCode, forKey: DefaultsKey.sourceCode)
        }
    }
    @Published var standardInput: String {
        didSet {
            UserDefaults.standard.set(standardInput, forKey: DefaultsKey.standardInput)
        }
    }
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
    @Published var currentFileName: String {
        didSet {
            let sanitized = sanitizeFileName(currentFileName)
            if sanitized != currentFileName {
                currentFileName = sanitized
                return
            }

            UserDefaults.standard.set(currentFileName, forKey: DefaultsKey.currentFileName)
        }
    }

    init() {
        let savedLanguageToken = UserDefaults.standard.string(forKey: DefaultsKey.selectedLanguage)
        let savedLanguage: SourceLanguage? = {
            switch savedLanguageToken {
            case "c", "C":
                return .c
            case "cpp", "C++":
                return .cpp
            default:
                return nil
            }
        }()
        let savedFileName = UserDefaults.standard.string(forKey: DefaultsKey.currentFileName)
        let inferredLanguage = savedFileName.flatMap(SourceLanguage.infer(from:))
        let initialLanguage = savedLanguage ?? inferredLanguage ?? .cpp

        selectedLanguage = initialLanguage
        currentFileName = Self.sanitizeStaticFileName(savedFileName ?? initialLanguage.defaultFileName)
        sourceCode = UserDefaults.standard.string(forKey: DefaultsKey.sourceCode) ?? initialLanguage.defaultTemplate
        standardInput = UserDefaults.standard.string(forKey: DefaultsKey.standardInput) ?? ""
        useRemoteCompiler = UserDefaults.standard.object(forKey: DefaultsKey.useRemoteCompiler) as? Bool ?? true
        endpointText = UserDefaults.standard.string(forKey: DefaultsKey.endpoint) ?? "http://127.0.0.1:8080/compile"
    }

    func newDocument() {
        selectedLanguage = .cpp
        currentFileName = selectedLanguage.defaultFileName
        sourceCode = selectedLanguage.defaultTemplate
        standardInput = ""
        output = "Created a new \(selectedLanguage.rawValue) file."
    }

    func loadExample() {
        sourceCode = selectedLanguage.defaultTemplate
        currentFileName = selectedLanguage.defaultFileName
        output = "Loaded the \(selectedLanguage.rawValue) example."
    }

    func loadDocument(text: String, fileName: String) {
        let inferredLanguage = SourceLanguage.infer(from: fileName) ?? selectedLanguage
        selectedLanguage = inferredLanguage
        currentFileName = sanitizeFileName(fileName)
        sourceCode = text
        output = "Opened \(currentFileName)."
    }

    func didExport(to fileName: String) {
        currentFileName = sanitizeFileName(fileName)
        output = "Saved \(currentFileName) to Files."
    }

    func compile() async {
        isCompiling = true
        output = "Compiling \(selectedLanguage.rawValue) source in \(currentFileName)..."
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

    var lineCount: Int {
        max(sourceCode.components(separatedBy: .newlines).count, 1)
    }

    var characterCount: Int {
        sourceCode.count
    }

    var backendLabel: String {
        useRemoteCompiler ? "Live Server" : "Mock Mode"
    }

    var draftLabel: String {
        "Autosaved locally"
    }

    var outputStatusLabel: String {
        if isCompiling {
            return "Running"
        }

        if output.contains("Status: Success") {
            return "Success"
        }

        if output.contains("Status: Failed") || output.contains("Request failed") {
            return "Error"
        }

        return "Idle"
    }

    var outputStatusColor: Color {
        switch outputStatusLabel {
        case "Success":
            return Color(red: 0.22, green: 0.78, blue: 0.49)
        case "Error":
            return Color(red: 0.92, green: 0.39, blue: 0.34)
        case "Running":
            return Color(red: 0.95, green: 0.68, blue: 0.25)
        default:
            return Color(red: 0.47, green: 0.58, blue: 0.71)
        }
    }

    var endpointDisplayText: String {
        endpointText.isEmpty ? "No endpoint configured" : endpointText
    }

    var endpointHint: String {
        if endpointText.contains("127.0.0.1") || endpointText.contains("localhost") {
            return "Use 127.0.0.1 for the iOS Simulator. For a real iPhone, replace it with your Mac's local IP, like http://192.168.1.20:8080/compile."
        }

        return "Your phone and your server must be on the same network unless the backend is deployed publicly."
    }

    private func replacingFileExtension(in fileName: String, with newExtension: String) -> String {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        return "\(baseName).\(newExtension)"
    }

    private func sanitizeFileName(_ fileName: String) -> String {
        Self.sanitizeStaticFileName(fileName)
    }

    private static func sanitizeStaticFileName(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SourceLanguage.cpp.defaultFileName : trimmed
    }
}
