# Cloud

This directory is reserved for optional first-party Nastart Cloud work.

V1 should prioritize iCloud/CloudKit sync for Apple-device continuity. A custom
Nastart Cloud backend is not required for the first local-first product
experience.

Potential future Nastart Cloud responsibilities:

- encrypted sync
- push notifications
- account and billing
- backup and restore
- multi-device continuity

Cloud must not store NAS credentials or other sensitive user secrets in
plaintext.
