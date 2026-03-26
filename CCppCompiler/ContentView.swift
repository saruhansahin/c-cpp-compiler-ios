import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CompilerViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Language", selection: $viewModel.selectedLanguage) {
                        ForEach(SourceLanguage.allCases) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Source Code")
                                .font(.headline)
                            Spacer()
                            Button("Load Example") {
                                viewModel.loadExample()
                            }
                        }

                        TextEditor(text: $viewModel.sourceCode)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 260)
                            .padding(8)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Standard Input")
                            .font(.headline)

                        TextEditor(text: $viewModel.standardInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 90)
                            .padding(8)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use Remote Compiler API", isOn: $viewModel.useRemoteCompiler)

                        if viewModel.useRemoteCompiler {
                            TextField("Endpoint URL", text: $viewModel.endpointText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
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
                                Text("Compile")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isCompiling)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output")
                            .font(.headline)

                        ScrollView {
                            Text(viewModel.output)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 180)
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Architecture Note")
                            .font(.headline)
                        Text("App Store iOS apps cannot execute arbitrary newly compiled native binaries. Use a backend or a WASM runtime for real compilation.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("C/C++ Compiler")
        }
    }
}

#Preview {
    ContentView()
}
