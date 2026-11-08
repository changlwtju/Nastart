# iPhone 13 VPN + DSM connection: intermittent failure

Status: not currently reproducible. On 2026-09-27 the user kept the VPN connected, disconnected the existing DSM session in NAStart, and successfully logged in again through the public domain and port. Do not treat VPN presence or IPv6 as the root cause.

## Evidence from the failed attempt

- Device: iPhone 13, iOS 16.3.1, Wi-Fi; VPN was connected. DSM discovery and a LAN login worked.
- NAStart's persisted diagnostics repeatedly recorded `diagnostics.api_info.missing`, then `diagnostics.login.attempt_failed error=timeout` for `SYNO.API.Auth` on the public `:5001` endpoint. The login request did not receive a DSM authentication error.
- iOS unified logs at 07:48 show the `:5001` request using `utun5` and the system HTTPS proxy `127.0.0.1:1082`. The local proxy returned `HTTP/1.1 503 Service Unavailable` during CONNECT, before TLS to DSM.
- Shadowrocket was the active tunnel app. Its rule test for the domain matched `DOMAIN-SUFFIX,cn,DIRECT`. The system proxy settings on `utun5` still pointed HTTP and HTTPS to `127.0.0.1:1082`; a DIRECT rule does not itself prove the app bypassed that local proxy.
- With VPN still enabled later, Safari refreshed the unauthenticated DSM API successfully. iOS logs show that successful request also went through `127.0.0.1:1082`. This points to an intermittent proxy/tunnel state, not a persistent domain rule mismatch.
- DNS recheck after the user's change: authoritative and public resolvers returned an A record and no AAAA record.

## Next occurrence

Before toggling VPN or changing NAS settings, capture the time, NAStart diagnostic export, Shadowrocket connection/diagnostic log, and iOS unified log around the failing request. Compare the local proxy CONNECT result and tunnel state with a successful request. Confirm whether Safari's unauthenticated `/webapi/query.cgi` endpoint fails at the same time. Keep credentials, OTP, session IDs, and full request URLs out of shared logs.

No VPN configuration change was made. Shadowrocket proxy logging was temporarily enabled for inspection and then restored to off. NAStart's remote connection error copy now includes VPN, proxy, and DNS checks; the current iPhone 13 build includes that copy.
