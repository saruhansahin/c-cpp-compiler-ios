# C/C++ Compiler Mobile App

This workspace contains a starter iOS app built with SwiftUI for a mobile C/C++ compiler experience.

## What this starter does

- lets the user edit C or C++ source code
- provides example templates
- has a compile action and output panel
- isolates compilation behind a service protocol so you can swap implementations later

## Important iOS constraint

iOS does not let regular App Store apps compile arbitrary native code and execute unsigned machine code the same way a desktop IDE does. Because of that, a production-ready mobile compiler usually uses one of these approaches:

1. Remote compilation: send code to your own backend, compile in a container, and return stdout/stderr
2. Embedded WebAssembly toolchain: compile and run inside a WASM runtime
3. Limited interpreter/sandbox: support only a subset of languages or prebuilt execution environments

This starter ships with:

- `MockCompilerService` for local UI development
- `RemoteCompilerService` stub for a real backend later

## Files

- `CCppCompiler.xcodeproj`: Xcode project
- `CCppCompiler/`: app source

## Next steps

1. Open `CCppCompiler.xcodeproj` in Xcode
2. Run the app in the iOS Simulator
3. Replace `MockCompilerService` with a real backend integration
4. Add authentication, request limits, and sandboxed job execution on the server side

## Suggested backend API

`POST /compile`

Request:

```json
{
  "language": "cpp",
  "source": "#include <iostream>\nint main(){ std::cout << \"Hi\"; }",
  "stdin": ""
}
```

Response:

```json
{
  "success": true,
  "stdout": "Hi\n",
  "stderr": "",
  "exitCode": 0,
  "durationMs": 48
}
```
