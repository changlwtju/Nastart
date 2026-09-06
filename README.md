# Nastart

Nastart is a local-first NAS and HomeLab companion for Apple platforms.

The first product version is optimized for Synology DSM users while keeping the
architecture open for other NAS and HomeLab systems. V1 should prioritize
automatic DSM API, app-side probing, and optional Agent flows for Synology DSM.
Manual entry remains a fallback, not the primary experience. Deep support for
other NAS platforms is planned for later versions through the Agent/provider
architecture.

The optional Nastart Agent is intended to run as a Docker container on the
user's own NAS or Linux host. Synology is the primary tested target for v1.
Other Docker-capable NAS systems are a future compatibility path through the
same Agent/provider architecture.

It is intended to become an intelligent launchpad, service discovery center,
status monitor, and lifecycle assistant for NAS users, starting with iPhone and
iPad, then expanding toward macOS and other Apple platforms.

## Playback Architecture Decision

视频播放集中优化 Greenfield 新架构，旧架构仅作回退与必要对照；验收完成后删除旧架构。播放入口只保留新/旧两项选择。后续工作遵循 [ADR 0002：新播放架构唯一优化主线](docs/adr/0002-single-playback-optimization-mainline.md)。

## Product Direction

Nastart is not planned as a simple mobile clone of Homepage, Homarr, MyServers,
or DS One. Its core position is:

> A beautiful, secure, local-first control center for NAS services, access
> diagnosis, service discovery, and lifecycle reminders.

## Initial Principles

- User data security comes first.
- The client is never trusted as a security boundary.
- Local-first is the default.
- iCloud/CloudKit sync should support Apple-device continuity without exposing
  plaintext NAS secrets.
- Agent permissions should be minimal and explainable.
- The product should be Synology-first in v1, but provider-ready for future NAS
  platforms.
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
