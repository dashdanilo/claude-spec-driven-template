# Architecture

> Last reviewed: YYYY-MM-DD
> Replace this template with your actual architecture.

## Overview

One paragraph describing the system at a high level. What does it do, who uses it, what is the deployment model.

## High-level diagram

ASCII or mermaid diagram showing the major components and how they communicate.

```
┌──────────────┐         ┌──────────────┐
│  Frontend    │────────→│  Backend API │
│              │  HTTPS  │              │
└──────────────┘         └──────┬───────┘
                                │
                ┌───────────────┼───────────────┐
                ↓               ↓               ↓
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │ Database  │   │ External  │   │ External  │
        │           │   │ Service A │   │ Service B │
        └───────────┘   └───────────┘   └───────────┘
```

## Trust model

Describe what runs where and what has access to what.

- **Client (browser):** zero secrets, only `NEXT_PUBLIC_*` env vars
- **Server:** has DB credentials, internal service tokens
- **Orchestration layer:** has all external API keys
- **External services:** isolated, each with own rate limits

## Main data flows

### Flow 1: <name>
1. ...
2. ...

### Flow 2: <name>
1. ...
2. ...

## Decisions

Major architectural decisions live in `docs/decisions/` as numbered ADRs. Examples:

- `0001-example.md` summarizes the format

## Constraints

- Budget, performance, compliance, or other hard limits

## Open questions

Decisions that are not yet made but will need to be soon.
