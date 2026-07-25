# Nastart Security Architecture

Version: 0.1  
Status: Draft  
Last updated: 2026-07-25

## 1. Security Vision

Security is not a feature of Nastart. It is a product foundation.

Nastart connects to private NAS devices, local services, domains, certificates,
Docker APIs, and potentially automation workflows. A weak security model would
turn convenience into risk.

## 2. Core Principles

- Never trust the client.
- User NAS credentials must remain local whenever possible.
- Cloud services should only see encrypted user data.
- Agent permissions must be minimal and auditable.
- Sensitive data must not appear in logs.
- High-risk operations require explicit user confirmation.
- App cracking should not expose user NAS data or backend control.
- Security architecture is a living document.

## 3. Threat Assumptions

Assume the following can happen:

- The IPA is decrypted, modified, or re-signed.
- The app runs on a jailbroken or compromised device.
- Frida or similar tools hook app runtime behavior.
- API requests are inspected.
- A user installs a cracked version through unofficial channels.
- Local network traffic may be observed.
- A NAS may use HTTP or a self-signed certificate.
- Docker Socket exposure can become a critical privilege escalation path.

The goal is not to make the app impossible to crack. The goal is to keep user
data and NAS control safe even when the client is untrusted.

## 4. Data Classification

| Level | Examples | Storage Requirement |
|---|---|---|
| S0 Public | app marketing copy, public docs | no special handling |
| S1 Low Risk | service display names, themes | local database acceptable |
| S2 Private | NAS address, service URLs, topology | encrypted local storage preferred |
| S3 Sensitive | tokens, passwords, API keys, certificate fingerprints | Keychain required |
| S4 Critical | private keys, DNS API tokens, Agent admin tokens | Keychain/Secure Enclave/Agent-side vault |

## 5. iOS Security Model

Recommended mechanisms:

- Keychain for credentials and tokens
- Secure Enclave when biometric-protected keys are needed
- LocalAuthentication for Face ID / passcode confirmation
- App Attest or DeviceCheck for server-side abuse reduction
- OSLog privacy annotations for logs
- App Transport Security with narrow exceptions only

Jailbreak and tamper detection may be implemented as risk signals, not as the
primary security boundary.

## 6. Network Security

Default rules:

- Prefer HTTPS.
- Do not globally disable ATS.
- Allow HTTP only for explicit local or user-approved services.
- For self-signed certificates, allow user-confirmed certificate pinning.
- Re-warn the user when a pinned certificate changes.
- Never silently trust every invalid certificate.

## 7. Agent Security Model

The Agent should run on the NAS or HomeLab machine and expose a narrow API to
the app.

Design rules:

- Pairing must be explicit.
- Agent tokens must be scoped.
- Read-only mode should be the default.
- Docker Socket access should be isolated behind Agent policy.
- Dangerous operations need confirmation and audit logs.
- The Agent should not expose unnecessary host capabilities.

Suggested permission levels:

| Level | Capabilities |
|---|---|
| Read | status, containers, services, package metadata |
| Diagnose | network checks, certificate checks, logs without secrets |
| Control | restart service/container, refresh metadata |
| Admin | certificate automation, privileged system actions |

## 8. Cloud Security Model

Cloud is optional.

If implemented:

- Use end-to-end encryption for user data.
- Do not store NAS passwords or private tokens in plaintext.
- Store billing identity separately from NAS secrets.
- Membership state must not grant NAS access by itself.
- Server APIs must validate authorization independently.

## 9. WebView Security

The built-in browser should be isolated:

- Do not inject app credentials into arbitrary pages.
- Keep cookies scoped to each service when possible.
- Provide clear warnings for HTTP and invalid certificates.
- Allow users to open services in Safari.
- Avoid public browsing features unrelated to user-owned services.

## 10. Membership and Anti-Crack Strategy

Anti-crack work should reduce abuse, not protect secrets.

Recommended:

- Store purchases through StoreKit 2.
- Validate receipts or transactions server-side if Cloud is used.
- Treat membership as entitlement, not as a security boundary.
- Do not embed backend master secrets in the app.
- Use App Attest for abuse reduction where appropriate.

## 11. Logging and Privacy

Logs must not include:

- passwords
- tokens
- private keys
- DNS API credentials
- full internal URLs with secrets
- cookies

Diagnostics should support redaction before export.

## 12. MVP Security Checklist

- [ ] NAS credentials stored in Keychain
- [ ] No global ATS disable
- [ ] Explicit HTTP warnings
- [ ] Self-signed certificate fingerprint confirmation
- [ ] Agent pairing design documented
- [ ] Docker read-only path defined
- [ ] No sensitive data in logs
- [ ] Privacy policy draft created
- [ ] Support page planned
- [ ] Threat model drafted

