# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.9.x   | :white_check_mark: |
| < 1.9   | :x:                |

Only the current minor release line is supported. Security fixes are published
as a new release rather than backported, so please update before reporting.

## Reporting a Vulnerability

Please report security issues privately through GitHub Security Advisories
rather than opening a public issue:

**[Report a vulnerability →](https://github.com/filippocappa/hum/security/advisories/new)**

You can also reach this from the repository's **Security** tab → **Advisories**
→ **Report a vulnerability**.

Please include:

- The version of Hum affected
- Your macOS version
- Steps to reproduce, and what an attacker could achieve
- Any relevant logs or a proof of concept

You can expect an initial response within a few days. If the report is
confirmed, a fix and an advisory will be published together, and you will be
credited unless you prefer otherwise.

## Scope

Hum is a sandboxed menu bar app that synthesises audio locally. It makes no
network requests, collects no data, and stores only its own slider positions in
`UserDefaults`. Reports that are most relevant therefore concern:

- The `SMAppService` login item registration
- The global hotkey registration
- Anything in the release artefacts or the build script

Releases are ad-hoc signed rather than notarised, so verify downloads against
the checksums on the release page.
