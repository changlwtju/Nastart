# Nastart

Nastart is a local-first NAS and HomeLab companion for Apple platforms.

It is intended to become an intelligent launchpad, service discovery center,
status monitor, and lifecycle assistant for NAS users, starting with iPhone and
iPad, then expanding toward macOS and other Apple platforms.

## Product Direction

Nastart is not planned as a simple mobile clone of Homepage, Homarr, MyServers,
or DS One. Its core position is:

> A beautiful, secure, local-first control center for NAS services, access
> diagnosis, service discovery, and lifecycle reminders.

## Initial Principles

- User data security comes first.
- The client is never trusted as a security boundary.
- Local-first is the default.
- Cloud sync is optional and should only see encrypted user data.
- Agent permissions should be minimal and explainable.
- The product should support Synology first, but not become Synology-only.
- iPhone and iPad should be planned from day one.

## Repository Structure

```text
Nastart/
├── README.md
├── docs/
│   ├── README.md
│   ├── strategy/
│   ├── product/
│   ├── research/
│   ├── security/
│   ├── architecture/
│   ├── project/
│   ├── design/
│   └── adr/
├── ios/
├── agent/
├── cloud/
└── website/
```

## Current Status

This project is currently in product definition and architecture planning.
The first local files are generated from the shared ChatGPT planning
conversation about Nastart.

