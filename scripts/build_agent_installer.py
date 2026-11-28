#!/usr/bin/env python3
"""Build the self-contained shell installer for the website."""

import base64
import gzip
import io
from pathlib import Path
import re
import sys
import tarfile
import textwrap


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: build_agent_installer.py OUTPUT.sh")
    root = Path(__file__).resolve().parents[1]
    agent = root / "agent"
    match = re.search(r'^AGENT_VERSION\s*=\s*"(\d+\.\d+\.\d+)"\s*$',
                      (agent / "nastart_agent.py").read_text(), re.ASCII | re.MULTILINE)
    if not match:
        raise SystemExit("Expected a numeric AGENT_VERSION in nastart_agent.py")

    archive = io.BytesIO()
    with tarfile.open(fileobj=archive, mode="w", format=tarfile.USTAR_FORMAT) as bundle:
        for name in ("nastart_agent.py", "qrencoder.py", "qrencoder-LICENSE.txt"):
            content = (agent / name).read_bytes()
            info = tarfile.TarInfo(name)
            info.size = len(content)
            info.mode = 0o644
            bundle.addfile(info, io.BytesIO(content))
    encoded = base64.b64encode(gzip.compress(archive.getvalue(), mtime=0)).decode("ascii")
    script = (root / "scripts" / "install_agent.sh").read_text().split("\n", 1)[1]
    output = Path(sys.argv[1])
    output.write_text(
        f"#!/bin/sh\nnastart_release_version='{match[1]}'\n"
        "nastart_release_payload() {\n    cat <<'NASTART_PAYLOAD'\n"
        + "\n".join(textwrap.wrap(encoded, 76))
        + "\nNASTART_PAYLOAD\n}\n\n" + script,
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
