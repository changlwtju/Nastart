# libsmb2 as used by Nastart

Upstream: https://github.com/sahlberg/libsmb2, version 3.0.1 (`idf_component.yml`), `lib` and
`include` only. License: LGPL-2.1, see `COPYING` and `LICENCE-LGPL-2.1.txt`. Not all upstream
files are kept: tests, examples, utilities and other platforms' folders are removed.

Nastart changed these files on 2026-10-26, as LGPL-2.1 section 2(a) asks to be stated:

- `include/libsmb2-private.h`, `lib/socket.c`: receive bounds and reply span checks; reject
  replies that should have been signed and were not.
- `lib/smb2-cmd-create.c`, `lib/smb2-cmd-read.c`, `lib/smb2-cmd-query-directory.c`,
  `lib/smb2-cmd-negotiate.c`, `lib/smb2-cmd-session-setup.c`: validate variable-length reply
  fields before use.
- `include/smb2/libsmb2.h`, `lib/libsmb2.c`: `nastart_smb2_connect_numeric_async` and
  `nastart_smb2_connect_share_resolved_async`, which connect to an already resolved address
  while keeping the server's name, and report when authentication starts.

On 2026-11-07, `include/smb2/nastart-symbols.h` and an include of it in `libsmb2.h`, `smb2.h`,
`libsmb2-raw.h`, `libsmb2-private.h` and `module.modulemap` rename the functions Nastart calls, so
they cannot bind to the copy of libsmb2 inside MobileVLCKit.

Also on 2026-11-07, the receive frame bound in `lib/socket.c` rose from 256 KiB to 1 MiB + 64 KiB,
because NetworkMedia reads up to 1 MiB at a time.

The list above comes from the changed-file records of that work; the exact upstream diff has not
been regenerated, since the pinned upstream copy is not in this repository. Regenerate and attach
it before any public release.
