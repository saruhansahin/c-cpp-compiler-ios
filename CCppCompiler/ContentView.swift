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
                        Text("Compiler Backend")
                            .font(.headline)

                        Toggle("Use Live Compiler Server", isOn: $viewModel.useRemoteCompiler)

                        if viewModel.useRemoteCompiler {
                            TextField("Endpoint URL", text: $viewModel.endpointText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)

                            Text(viewModel.endpointHint)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Mock mode is useful only for UI testing. Turn on the live server for real compilation.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
                                Text("Compile & Run")
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
                        Text("The best production path is a remote compiler backend. The app stays mobile-first, but compilation runs in a controlled server sandbox.")
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
