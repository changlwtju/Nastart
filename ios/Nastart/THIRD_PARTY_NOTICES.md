# Third-Party Notices

## MobileVLCKit

Nastart optionally includes MobileVLCKit 3.7.3 for media formats and codecs
that AVPlayer cannot decode.

- Project: https://code.videolan.org/videolan/VLCKit
- Source mirror: https://github.com/videolan/vlckit
- License: GNU Lesser General Public License, version 2.1 or later
- License text: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html

MobileVLCKit is not required by the AVPlayer-only build. Public releases that
include it must retain applicable copyright and license notices and satisfy the
LGPL's library replacement or relinking requirements. Verify those obligations
against the exact archived binary and distribution method before release.

## libsmb2

Nastart uses libsmb2 3.0.1 for read-only access to SMB shares.

- Project: https://github.com/sahlberg/libsmb2
- License: GNU Lesser General Public License, version 2.1 or later
- Source and Nastart's changes: `Packages/LibSMB2`, see `NASTART-MODIFICATIONS.md`

libsmb2 ships as its own dynamic framework (`LibSMB2.framework`). Public releases must retain
this notice and the license text, offer the corresponding source of the modified library, and
satisfy the LGPL's library replacement requirement. Verify those obligations against the exact
archived binary and distribution method before release.
