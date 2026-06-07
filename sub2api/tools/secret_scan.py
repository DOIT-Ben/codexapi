#!/usr/bin/env python3
"""Lightweight repository secret scanner for Sub2API.

The scanner is intentionally conservative: it ignores dependency/build folders,
allows documented placeholders and known built-in OAuth client constants, and
fails on high-confidence private keys or API-token-like strings.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

SKIP_DIRS = {
    ".git",
    ".idea",
    ".vscode",
    ".cache",
    ".dev",
    ".serena",
    "node_modules",
    "dist",
    "build",
    "release",
    "vendor",
    "postgres_data",
    "redis_data",
    "data",
}

SKIP_SUFFIXES = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".ico",
    ".pdf",
    ".zip",
    ".gz",
    ".tar",
    ".7z",
    ".exe",
    ".dll",
    ".so",
    ".dylib",
    ".test",
    ".lock",
}

ALLOWLIST_SUBSTRINGS = (
    "your-client-secret",
    "your-built-in-secret",
    "your_secure_password",
    "your_jwt_secret",
    "your_admin_password",
    "change_this_secure_password",
    "change-this-to-a-secure-random-string",
    "sk-ant-mirror-xxxxxxxxxxxx",
    "sk-getbykey-",
    "sk-update-last-used-",
    "sk-reuse-after-soft-delete",
    "sk-usage-",
    "sk-getbyid-request-type",
    "sk-proj-1234567890abcdef",
    "AIza...",
    "starts with AIza",
    "以 AIza 开头",
    "GOCSPX-***",
    "MIIEvQIBADANBg...",
    "\\\\nMIIE\\\\n",
    "\\nabc\\n",
    "\\ndata\\n",
    "-----BEGIN RSA PRIVATE KEY-----\\ndata\\n-----END RSA PRIVATE KEY-----",
)

ALLOWLIST_EXACT = {
    "GOCSPX-placeholder-secret",
}


@dataclass(frozen=True)
class Rule:
    name: str
    pattern: re.Pattern[str]


RULES = (
    Rule("private-key", re.compile(r"-----BEGIN (?:RSA |OPENSSH |EC |DSA |)?PRIVATE KEY-----")),
    Rule("openai-style-key", re.compile(r"\bsk-(?:proj-|ant-|live-)?[A-Za-z0-9_-]{20,}\b")),
    Rule("gemini-api-key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    Rule("google-oauth-secret", re.compile(r"\bGOCSPX-[0-9A-Za-z_-]{24,}\b")),
)


def run_git(args: list[str]) -> list[str]:
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=ROOT,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except (OSError, subprocess.CalledProcessError):
        return []
    return [line for line in result.stdout.splitlines() if line]


def is_skipped(path: Path) -> bool:
    if path == Path(__file__).resolve():
        return True
    rel_parts = path.relative_to(ROOT).parts
    if any(part in SKIP_DIRS for part in rel_parts):
        return True
    if path.suffix.lower() in SKIP_SUFFIXES:
        return True
    return False


def candidate_files() -> list[Path]:
    tracked = {ROOT / item for item in run_git(["ls-files"])}
    untracked = {
        ROOT / item
        for item in run_git(["ls-files", "--others", "--exclude-standard"])
    }
    files = tracked | untracked

    if not files:
        for current_root, dirs, names in os.walk(ROOT):
            dirs[:] = [name for name in dirs if name not in SKIP_DIRS]
            files.update(Path(current_root) / name for name in names)

    return sorted(path for path in files if path.is_file() and not is_skipped(path))


def is_allowed(line: str, matched: str) -> bool:
    if matched in ALLOWLIST_EXACT:
        return True
    return any(token in line for token in ALLOWLIST_SUBSTRINGS)


def scan_file(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []
    except OSError as exc:
        return [f"{path.relative_to(ROOT)}: unable to read file: {exc}"]

    findings: list[str] = []
    rel = path.relative_to(ROOT).as_posix()
    for line_no, line in enumerate(text.splitlines(), start=1):
        for rule in RULES:
            for match in rule.pattern.finditer(line):
                value = match.group(0)
                if is_allowed(line, value):
                    continue
                findings.append(f"{rel}:{line_no}: {rule.name}: {value[:12]}...")
    return findings


def main() -> int:
    findings: list[str] = []
    for path in candidate_files():
        findings.extend(scan_file(path))

    if findings:
        print("Potential secrets found:", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        return 1

    print("Secret scan passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
