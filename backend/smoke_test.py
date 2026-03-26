#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request


def request_json(url: str, payload: dict | None = None) -> dict:
    if payload is None:
        request = urllib.request.Request(url)
    else:
        body = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    base_url = "http://127.0.0.1:8080"

    try:
        health = request_json(f"{base_url}/health")
        print("health:", health)

        result = request_json(
            f"{base_url}/compile",
            {
                "language": "cpp",
                "source": (
                    "#include <iostream>\n"
                    "int main() {\n"
                    '    std::cout << "Hello from backend" << std::endl;\n'
                    "    return 0;\n"
                    "}\n"
                ),
                "stdin": "",
            },
        )
        print("compile:", json.dumps(result, indent=2))
    except urllib.error.URLError as error:
        print(f"server request failed: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
