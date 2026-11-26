#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
image=$(NASTART_DOCKERHUB_NAMESPACE=changlwtju sh "$root/agent/compose.sh" --image)
version=${image##*:}
revision=${SPK_BUILD_NUMBER:-0008}
output=${1:-"${TMPDIR:-/tmp}/nastart-agent-$version-$revision.spk"}
if (( $# > 1 )); then
    echo "Usage: SPK_BUILD_NUMBER=0008 $0 [output.spk]" >&2
    exit 2
fi

python3 - "$root/spk" "$output" "$image" "$revision" <<'PY'
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tarfile
import tempfile


def require(condition, message):
    if not condition:
        raise SystemExit(f"Invalid SPK: {message}")


def archive(entries, first=None):
    stream = io.BytesIO()
    directories = {parent.as_posix() for name in entries for parent in Path(name).parents if parent != Path(".")}
    with tarfile.open(fileobj=stream, mode="w", format=tarfile.USTAR_FORMAT) as tar:
        # DSM's package parser expects INFO to be the first entry in the
        # outer SPK tar. Directory entries before INFO make Package Center
        # reject the package as "format incorrect" (same error as the
        # omervk.com SPK case: INFO must come first, no "./" prefix).
        if first is not None and first in entries:
            content, mode = entries[first]
            member = tarfile.TarInfo(first)
            member.size = len(content)
            member.mode = mode
            member.uname = member.gname = "root"
            tar.addfile(member, io.BytesIO(content))
        for name in sorted(directories):
            member = tarfile.TarInfo(name)
            member.type = tarfile.DIRTYPE
            member.mode = 0o755
            member.uname = member.gname = "root"
            tar.addfile(member)
        for name, (content, mode) in sorted(entries.items()):
            if name == first:
                continue
            member = tarfile.TarInfo(name)
            member.size = len(content)
            member.mode = mode
            member.uname = member.gname = "root"
            tar.addfile(member, io.BytesIO(content))
    return stream.getvalue()


def read_archive(blob):
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r:*") as tar:
        files = {}
        for member in tar:
            if member.isdir():
                require(member.mode == 0o755, f"invalid directory mode for {member.name}")
                continue
            require(member.isfile() and member.name not in files, f"invalid member {member.name}")
            files[member.name] = (tar.extractfile(member).read(), member.mode)
        return files


def source(path, executable=False):
    file = spk / path
    if executable:
        require(file.stat().st_mode & 0o111 == 0o111, f"{path} must be executable")
        for shell in ("bash", "sh"):
            subprocess.run([shell, "-n", str(file)], check=True)
    return file.read_bytes(), 0o755 if executable else 0o644


spk, output = map(Path, sys.argv[1:3])
image, revision = sys.argv[3:]
version = image.rsplit(":", 1)[-1]
require(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version), "AGENT_VERSION must be numeric X.Y.Z")
require(re.fullmatch(r"[0-9]{4}", revision) and int(revision) > 0, "build number must be 0001–9999")
require(output.suffix == ".spk", "output filename must end in .spk")

package_files = {
    "project/compose.yaml": (source("package/compose.yaml")[0].replace(b"@AGENT_IMAGE@", image.encode()), 0o644),
    "port_conf/nastart-agent.sc": source("package/port_conf/nastart-agent.sc"),
}
package_tgz = gzip.compress(archive(package_files), mtime=0)
pkg_version = f"{version}-{revision}"
info = (spk / "INFO").read_text().replace("@AGENT_VERSION@", version).replace("@SPK_BUILD_NUMBER@", revision)
info += f'checksum="{hashlib.md5(package_tgz).hexdigest()}"\n'
files = {
    "INFO": (info.encode(), 0o644),
    "package.tgz": (package_tgz, 0o644),
    "LICENSE": source("LICENSE"),
    "conf/privilege": source("conf/privilege"),
    "conf/resource": source("conf/resource"),
}
hooks = "preinst postinst preuninst postuninst preupgrade postupgrade start-stop-status".split()
for hook in hooks:
    files[f"scripts/{hook}"] = source(f"scripts/{hook}", executable=True)
icons = {"PACKAGE_ICON.PNG": 64, "PACKAGE_ICON_256.PNG": 256}
for icon in icons:
    files[icon] = source(icon)

blob = archive(files, first="INFO")
packed = read_archive(blob)
require(packed.keys() == files.keys(), "outer archive layout")
values = {}
for line in packed["INFO"][0].decode().splitlines():
    entry = re.fullmatch(r'([a-z_]+)="([^"]+)"', line)
    require(entry and entry[1] not in values, f"invalid INFO line {line!r}")
    values[entry[1]] = entry[2]
for field, expected in {
    "package": "nastart-agent",
    "version": pkg_version,
    "arch": "x86_64 armv8",
    "os_min_ver": "7.2-69057",
    "install_dep_packages": "ContainerManager>=20.10.23-1437",
    "checksum": hashlib.md5(packed["package.tgz"][0]).hexdigest(),
}.items():
    require(values.get(field) == expected, f"INFO {field}")
for field in ("displayname", "maintainer", "description"):
    require(values.get(field), f"missing INFO {field}")
for icon, size in icons.items():
    png = packed[icon][0]
    require(png[:16] == b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR", f"{icon} PNG header")
    require(struct.unpack(">II", png[16:24]) == (size, size), f"{icon} must be {size}×{size}")
require(0 < len(packed["LICENSE"][0]) < 1_000_000, "LICENSE size")
privilege = json.loads(packed["conf/privilege"][0])
require(privilege == {"defaults": {"run-as": "package"}},
        "DSM privilege must use the package user without requesting group membership")
inner = read_archive(packed["package.tgz"][0])
require(inner == package_files, "package.tgz layout or file modes")
resources = json.loads(packed["conf/resource"][0])
port_file = resources["port-config"]["protocol-file"]
require(port_file in inner and b'dst.ports="8787/tcp"' in inner[port_file][0], "TCP 8787 port registration")
projects = resources["docker-project"]["projects"]
require(len(projects) == 1 and projects[0] == {
    "name": "nastart-agent-spk", "path": "project", "build_params": {"build": False},
}, "Container Manager project registration")
template = inner["project/compose.yaml"][0]
require(template.count(image.encode()) == 2 and b"@AGENT_IMAGE@" not in template,
        "project image must use the released Agent build")
for token in (b"NASTART_SPK_UID", b"NASTART_SPK_GID", b"NASTART_SPK_DATA_DIR",
              b"NASTART_SPK_DOCKER_GID"):
    require(b"${" + token + b"}" in template, f"missing Compose substitution {token!r}")
require(all(packed[f"scripts/{hook}"][1] == 0o755 for hook in hooks), "lifecycle hook modes")

# Publish only the archive that passed validation.
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.NamedTemporaryFile(dir=output.parent, prefix=f".{output.name}.", delete=False) as temp:
    pending = Path(temp.name)
    try:
        temp.write(blob)
        temp.close()
        pending.chmod(0o644)
        pending.replace(output)
    finally:
        pending.unlink(missing_ok=True)

print(f"SPK structure verified ({pkg_version}, {image}, {len(blob)} bytes)")
print(output.resolve())
print(f"SHA-256 {hashlib.sha256(blob).hexdigest()}")
PY
