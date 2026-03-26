import Foundation

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
