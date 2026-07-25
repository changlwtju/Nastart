# Nastart Competitive Landscape

Version: 0.1  
Status: Draft  
Last updated: 2026-07-25

## 1. Purpose

This document records the early competitive framing for Nastart.

The goal is not to avoid all feature overlap. NAS and HomeLab apps inevitably
share basic functionality. The goal is to avoid building a product whose core
workflow feels interchangeable with existing apps.

## 2. Competitor Categories

### 2.1 Server Operations Apps

Examples:

- MyServers
- NeoServer
- ServerCat
- WebSSH-style tools

Typical strengths:

- SSH
- SFTP
- server metrics
- Docker management
- scripts
- terminal-like workflows
- Proxmox or Linux server operations

Nastart should not primarily compete as a generic mobile operations console.

### 2.2 NAS Media and File Apps

Examples:

- DS One
- Synology media/file apps
- Jellyfin/Plex/Emby clients

Typical strengths:

- media playback
- file browsing
- subtitle support
- music and audiobook consumption
- Apple TV media experience

Nastart should not primarily compete as a media player.

### 2.3 NAS Vendor Utilities

Examples:

- DS finder
- vendor management apps

Typical strengths:

- device management
- vendor-specific status
- official compatibility
- setup and alerts

Nastart should support vendor integrations, but avoid becoming a vendor-only
utility.

### 2.4 Self-Hosted Dashboards

Examples:

- Homepage
- Homarr
- Dashy

Typical strengths:

- web dashboard
- Docker labels
- service widgets
- YAML or web-based configuration
- extensible service metadata

Nastart can learn from these tools, but must create a better native mobile and
Apple ecosystem experience.

## 3. Nastart Differentiation

Nastart's defensible area:

```text
Automatic discovery
+ intelligent access routing
+ native Apple launchpad
+ connection diagnosis
+ lifecycle reminders
+ local-first security
```

## 4. Feature Overlap Policy

Allowed overlap:

- connecting NAS
- adding services
- displaying status
- opening WebUI
- Docker detection
- basic widgets

Avoid over-indexing on:

- SSH terminal
- SFTP file manager
- full Docker admin suite
- full media playback
- generic server management
- basic bookmark grid only

## 5. Product Opportunity

Nastart should own the workflow:

1. Discover my NAS and services.
2. Understand how I can safely reach them.
3. Generate a beautiful native launchpad.
4. Tell me what is broken before I notice.
5. Remind me before certificates, domains, storage, or backups become urgent.

This is more specific than a server admin app and more helpful than a static
dashboard.

