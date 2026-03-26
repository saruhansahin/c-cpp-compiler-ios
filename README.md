# C/C++ Compiler Mobile App

This repo now contains the best practical architecture for a mobile C/C++ compiler on iOS:

- a SwiftUI iPhone app for editing code and showing results
- a real backend compile server that runs `clang` and `clang++`
- a clean API boundary so the app can compile and run code from inside your own product

## Why this architecture

iOS apps can present the full compiler experience, but they cannot behave like a desktop IDE that freely creates and executes arbitrary new native binaries on-device. The production-safe answer is:

1. User writes code in your app
2. Your app sends it to your backend
3. Your backend compiles and runs it inside a restricted environment
4. Your app displays the output

To the user, your app is still the compiler.

## Repo layout

- `CCppCompiler.xcodeproj`: iOS app project
- `CCppCompiler/`: SwiftUI app source
- `backend/server.py`: real compile-and-run HTTP server
- `backend/smoke_test.py`: small integration test for the backend

## Run the backend

On your Mac:

```bash
cd /path/to/c-cpp-compiler-ios
python3 backend/server.py --host 127.0.0.1 --port 8080
```

For a physical iPhone on the same Wi‑Fi network:

```bash
cd /path/to/c-cpp-compiler-ios
python3 backend/server.py --host 0.0.0.0 --port 8080
```

Then set the app endpoint to:

- Simulator: `http://127.0.0.1:8080/compile`
- Real iPhone: `http://YOUR_MAC_LOCAL_IP:8080/compile`

Example local IP:

```text
http://192.168.1.20:8080/compile
```

You can find your Mac's Wi-Fi IP with:

```bash
ipconfig getifaddr en0
```

## Test the backend

Start the server, then run:

```bash
cd /path/to/c-cpp-compiler-ios
python3 backend/smoke_test.py
```

## Open the app

```bash
open CCppCompiler.xcodeproj
```

Avoid `:` in the parent folder name when opening the Xcode project. A path like `C:Cpp Compiler` can break Swift dependency parsing during builds. Use a clean folder name such as `c-cpp-compiler-ios`.

Inside the app:

1. Keep `Use Live Compiler Server` enabled
2. Confirm the endpoint URL
3. Load the sample
4. Tap `Compile & Run`

## API

`POST /compile`

Request:

```json
{
  "language": "cpp",
  "source": "#include <iostream>\nint main(){ std::cout << \"Hi\" << std::endl; }",
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

Health check:

```text
GET /health
```

## Security note

`backend/server.py` includes basic limits for:

- compile timeout
- run timeout
- memory
- process count
- captured output size

That is good for local development and controlled demos. For public deployment, put this backend inside a real container or VM sandbox and add authentication plus rate limits.
