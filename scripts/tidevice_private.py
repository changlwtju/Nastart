#!/usr/bin/python3
"""Run installed tidevice with a private writable cache, without changing HOME.
Uses the system Python where this Mac's tidevice is installed. Override cache
with NASTART_TIDEVICE_CACHE. No install, device or WDA mutation by itself.
"""
import os
from pathlib import Path
import tidevice._utils as utils

cache = Path(os.environ.get('NASTART_TIDEVICE_CACHE',
    str(Path.home()/'Library/Application Support/Nastart/Tools/tidevice-cache')))
def appdir(*parts):
    path = cache.joinpath(*parts)
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    return str(path)
utils.get_app_dir = appdir
import tidevice._device as device
device.get_app_dir = appdir
from tidevice.__main__ import main
if __name__ == '__main__':
    main()
