import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum SourceLanguage: String, CaseIterable, Identifiable, Codable {
    case c = "C"
    case cpp = "C++"

    var id: String { rawValue }

    var apiValue: String {
        switch self {
        case .c:
            return "c"
        case .cpp:
            return "cpp"
        }
    }

    var fileExtension: String {
        switch self {
        case .c:
            return "c"
        case .cpp:
            return "cpp"
        }
    }

    var defaultFileName: String {
        "main.\(fileExtension)"
    }

    var exportContentType: UTType {
        UTType(filenameExtension: fileExtension) ?? .plainText
    }

    var defaultTemplate: String {
        switch self {
        case .c:
            return """
            #include <stdio.h>

            int main(void) {
                printf("Hello from C!\\n");
                return 0;
            }
            """
        case .cpp:
            return """
            #include <iostream>

            int main() {
                std::cout << "Hello from C++!" << std::endl;
                return 0;
            }
            """
        }
    }

    static func infer(from fileName: String) -> SourceLanguage? {
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()

        switch fileExtension {
        case "c", "h":
            return .c
        case "cc", "cp", "cpp", "cxx", "hpp", "hh", "hxx":
            return .cpp
        default:
            return nil
        }
    }
}

struct CompileRequest: Codable {
    let language: String
    let source: String
    let stdin: String
}

struct CompileResponse: Codable {
    let success: Bool
    let stdout: String
    let stderr: String
    let exitCode: Int
    let durationMs: Int
}

enum CompilerError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "The compiler endpoint URL is invalid."
        case .invalidResponse:
            return "The compiler service returned an invalid response."
        case let .transport(message):
            return message
        }
    }
}

struct SourceCodeDocument: FileDocument {
    static var readableContentTypes: [UTType] { supportedContentTypes }
    static var writableContentTypes: [UTType] { supportedContentTypes }

    static let supportedContentTypes: [UTType] = {
        var contentTypes: [UTType] = [.plainText]

        ["c", "h", "cc", "cp", "cpp", "cxx", "hh", "hpp", "hxx"].forEach { fileExtension in
            if let contentType = UTType(filenameExtension: fileExtension) {
                contentTypes.append(contentType)
            }
        }

        return contentTypes
    }()

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
