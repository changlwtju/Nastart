#!/usr/bin/env python3
"""Check that non-system @rpath libraries used by a tvOS app are embedded.

Run against the frozen .app before installation. Codesign verification remains
an independent gate; a fully signed app can still omit a required framework.
"""
import argparse
from pathlib import Path
import subprocess
import sys


def missing_libraries(app: Path) -> list[str]:
    missing = []
    for binary in app.rglob('*'):
        if not binary.is_file():
            continue
        with binary.open('rb') as stream:
            if stream.read(4) not in [bytes.fromhex(x) for x in ('cffaedfe', 'cefaedfe', 'cafebabe', 'bebafeca')]:
                continue
        output = subprocess.check_output(['xcrun', 'otool', '-L', str(binary)], text=True)
        for line in output.splitlines()[1:]:
            dependency = line.strip().split(' (compatibility version', 1)[0]
            if not dependency.startswith('@rpath/'):
                continue
            relative = dependency.removeprefix('@rpath/')
            # The OS supplies Swift runtime libraries on the deployment target.
            if relative.startswith('libswift'):
                continue
            if relative.endswith('/' + binary.name) and binary.parent.name == Path(relative).parent.name:
                continue  # The dylib's own install-name.
            candidates = [app / 'Frameworks' / relative, binary.parent / relative,
                          binary.parent / 'Frameworks' / relative, app / relative]
            if not any(candidate.is_file() for candidate in candidates):
                missing.append(f'{binary.relative_to(app)}: {dependency}')
    return sorted(set(missing))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    if not args.app.is_dir() or not (args.app / 'Info.plist').is_file():
        parser.error('expected a built .app directory')
    missing = missing_libraries(args.app)
    if missing:
        print('\n'.join(missing), file=sys.stderr)
        return 1
    print('Embedded non-system @rpath libraries are present.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
