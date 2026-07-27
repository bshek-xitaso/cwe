#!/usr/bin/env python3
"""
Usage:
  python3 scripts/extract_cwe_versions.py
    - prints one CWE version per line (e.g. 4.20).

  python3 scripts/extract_cwe_versions.py --json
    - prints versions as a JSON array.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from html.parser import HTMLParser
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


DEFAULT_URL = "https://cwe.mitre.org/data/archive.html"
VERSION_LINK_RE = re.compile(r"/data/xml/cwec_v([0-9]+(?:\.[0-9]+)*)\.xml\.zip$")


class VersionLinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.versions: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "a":
            return

        attributes = dict(attrs)
        href = attributes.get("href")
        if not href:
            return

        match = VERSION_LINK_RE.search(href)
        if not match:
            return

        self.versions.append(match.group(1))


def fetch_html() -> str:
    request = Request(
        DEFAULT_URL,
        headers={
            "User-Agent": "cwe-version-extractor/1.0 (+https://github.com/csaf-rs/cwe)"
        },
    )

    try:
        with urlopen(request, timeout=30) as response:
            charset = response.headers.get_content_charset() or "utf-8"
            return response.read().decode(charset, errors="replace")
    except HTTPError as exc:
        raise RuntimeError(f"request failed with HTTP {exc.code}: {DEFAULT_URL}") from exc
    except URLError as exc:
        raise RuntimeError(f"request failed for {DEFAULT_URL}: {exc.reason}") from exc


def extract_versions(html: str) -> list[str]:
    parser = VersionLinkParser()
    parser.feed(html)
    return parser.versions


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract available CWE release versions from the MITRE archive page."
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit the versions as a JSON array instead of one version per line",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        html = fetch_html()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    versions = extract_versions(html)

    if not versions:
        print(f"no CWE versions found at {DEFAULT_URL}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(versions))
    else:
        print("\n".join(versions))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
