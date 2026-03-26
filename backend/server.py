#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import resource
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

MAX_REQUEST_BYTES = 200_000
MAX_SOURCE_BYTES = 100_000
MAX_STDIN_BYTES = 32_000
MAX_CAPTURE_BYTES = 64 * 1024
COMPILE_TIMEOUT_SECONDS = 10
RUN_TIMEOUT_SECONDS = 5

LANGUAGE_CONFIG = {
    "c": {
        "filename": "main.c",
        "compiler": ["clang", "-O0", "-std=c17", "-Wall", "-Wextra", "-pedantic"],
    },
    "cpp": {
        "filename": "main.cpp",
        "compiler": ["clang++", "-O0", "-std=c++20", "-Wall", "-Wextra", "-pedantic"],
    },
}


@dataclass(frozen=True)
class ProcessLimits:
    cpu_seconds: int
    address_space_bytes: int
    file_size_bytes: int
    process_count: int


@dataclass(frozen=True)
class ProcessResult:
    exit_code: int
    stdout: str
    stderr: str
    timed_out: bool = False


COMPILE_LIMITS = ProcessLimits(
    cpu_seconds=8,
    address_space_bytes=1024 * 1024 * 1024,
    file_size_bytes=8 * 1024 * 1024,
    process_count=32,
)

RUN_LIMITS = ProcessLimits(
    cpu_seconds=2,
    address_space_bytes=256 * 1024 * 1024,
    file_size_bytes=MAX_CAPTURE_BYTES,
    process_count=8,
)


class RequestError(Exception):
    def __init__(self, message: str, status: HTTPStatus = HTTPStatus.BAD_REQUEST) -> None:
        super().__init__(message)
        self.message = message
        self.status = status


def json_response(handler: BaseHTTPRequestHandler, status: HTTPStatus, payload: dict[str, Any]) -> None:
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.end_headers()
    handler.wfile.write(body)


def read_limited_text(path: Path) -> str:
    if not path.exists():
        return ""

    data = path.read_bytes()
    truncated = len(data) > MAX_CAPTURE_BYTES
    data = data[:MAX_CAPTURE_BYTES]
    text = data.decode("utf-8", errors="replace")

    if truncated:
        text += "\n\n[output truncated]"

    return text


def set_resource_limits(limits: ProcessLimits) -> None:
    os.setsid()

    limit_pairs = [
        (resource.RLIMIT_CPU, limits.cpu_seconds),
        (resource.RLIMIT_CORE, 0),
        (resource.RLIMIT_FSIZE, limits.file_size_bytes),
    ]

    for kind, value in limit_pairs:
        try:
            resource.setrlimit(kind, (value, value))
        except (ValueError, OSError):
            pass

    if sys.platform != "darwin":
        try:
            resource.setrlimit(resource.RLIMIT_NPROC, (limits.process_count, limits.process_count))
        except (ValueError, OSError):
            pass

    for kind in (resource.RLIMIT_AS, resource.RLIMIT_DATA):
        try:
            resource.setrlimit(kind, (limits.address_space_bytes, limits.address_space_bytes))
        except (ValueError, OSError):
            pass


def run_command(
    command: list[str],
    *,
    cwd: Path,
    stdin_text: str,
    timeout_seconds: int,
    limits: ProcessLimits,
) -> ProcessResult:
    stdout_path = cwd / "stdout.txt"
    stderr_path = cwd / "stderr.txt"

    with stdout_path.open("wb") as stdout_file, stderr_path.open("wb") as stderr_file:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            stdin=subprocess.PIPE,
            stdout=stdout_file,
            stderr=stderr_file,
            preexec_fn=lambda: set_resource_limits(limits),
        )

        try:
            process.communicate(stdin_text.encode("utf-8"), timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            stderr = read_limited_text(stderr_path)
            timeout_note = f"process timed out after {timeout_seconds} seconds"
            stderr = f"{stderr}\n{timeout_note}".strip()
            return ProcessResult(
                exit_code=124,
                stdout=read_limited_text(stdout_path),
                stderr=stderr,
                timed_out=True,
            )

    return ProcessResult(
        exit_code=process.returncode,
        stdout=read_limited_text(stdout_path),
        stderr=read_limited_text(stderr_path),
    )


def validate_request(payload: dict[str, Any]) -> tuple[str, str, str]:
    language = payload.get("language")
    source = payload.get("source")
    stdin_text = payload.get("stdin", "")

    if language not in LANGUAGE_CONFIG:
        raise RequestError("language must be one of: c, cpp")

    if not isinstance(source, str) or not source.strip():
        raise RequestError("source must be a non-empty string")

    if not isinstance(stdin_text, str):
        raise RequestError("stdin must be a string")

    if len(source.encode("utf-8")) > MAX_SOURCE_BYTES:
        raise RequestError("source is too large")

    if len(stdin_text.encode("utf-8")) > MAX_STDIN_BYTES:
        raise RequestError("stdin is too large")

    return language, source, stdin_text


def compile_and_run(language: str, source: str, stdin_text: str) -> dict[str, Any]:
    if shutil.which("clang") is None or shutil.which("clang++") is None:
        raise RequestError(
            "clang/clang++ were not found on the server",
            status=HTTPStatus.INTERNAL_SERVER_ERROR,
        )

    started_at = time.perf_counter()
    config = LANGUAGE_CONFIG[language]

    with tempfile.TemporaryDirectory(prefix="ccpp-compiler-") as temp_dir:
        work_dir = Path(temp_dir)
        source_path = work_dir / config["filename"]
        output_path = work_dir / "program"
        source_path.write_text(source, encoding="utf-8")

        compile_result = run_command(
            [*config["compiler"], str(source_path), "-o", str(output_path)],
            cwd=work_dir,
            stdin_text="",
            timeout_seconds=COMPILE_TIMEOUT_SECONDS,
            limits=COMPILE_LIMITS,
        )

        if compile_result.exit_code != 0:
            return {
                "success": False,
                "stdout": compile_result.stdout,
                "stderr": compile_result.stderr,
                "exitCode": compile_result.exit_code,
                "durationMs": int((time.perf_counter() - started_at) * 1000),
            }

        run_result = run_command(
            [str(output_path)],
            cwd=work_dir,
            stdin_text=stdin_text,
            timeout_seconds=RUN_TIMEOUT_SECONDS,
            limits=RUN_LIMITS,
        )

        return {
            "success": run_result.exit_code == 0 and not run_result.timed_out,
            "stdout": run_result.stdout,
            "stderr": run_result.stderr,
            "exitCode": run_result.exit_code,
            "durationMs": int((time.perf_counter() - started_at) * 1000),
        }


class CompilerRequestHandler(BaseHTTPRequestHandler):
    server_version = "CCppCompilerServer/1.0"

    def do_GET(self) -> None:
        if self.path == "/health":
            json_response(self, HTTPStatus.OK, {"status": "ok"})
            return

        json_response(self, HTTPStatus.NOT_FOUND, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/compile":
            json_response(self, HTTPStatus.NOT_FOUND, {"error": "not found"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0:
                raise RequestError("request body is required")

            if content_length > MAX_REQUEST_BYTES:
                raise RequestError("request is too large", status=HTTPStatus.REQUEST_ENTITY_TOO_LARGE)

            raw_body = self.rfile.read(content_length)
            payload = json.loads(raw_body)
            if not isinstance(payload, dict):
                raise RequestError("request body must be a JSON object")

            language, source, stdin_text = validate_request(payload)
            response = compile_and_run(language, source, stdin_text)
            json_response(self, HTTPStatus.OK, response)
        except ValueError as error:
            json_response(self, HTTPStatus.BAD_REQUEST, {"error": "invalid Content-Length header"})
        except RequestError as error:
            json_response(self, error.status, {"error": error.message})
        except json.JSONDecodeError:
            json_response(self, HTTPStatus.BAD_REQUEST, {"error": "invalid JSON"})
        except Exception as error:  # pragma: no cover - fallback path
            json_response(
                self,
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"error": f"internal server error: {error}"},
            )

    def log_message(self, format: str, *args: Any) -> None:
        print(f"{self.address_string()} - {format % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="C/C++ compiler backend server")
    parser.add_argument("--host", default="127.0.0.1", help="Bind address")
    parser.add_argument("--port", type=int, default=8080, help="Bind port")
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), CompilerRequestHandler)
    print(f"Compiler server listening on http://{args.host}:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
