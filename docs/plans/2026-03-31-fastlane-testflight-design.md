# Fastlane + TestFlight CI

**Date:** 2026-03-31

## Goal

Automate TestFlight uploads via GitHub Actions on tag push (`v*`), alongside the existing SideStore IPA build.

## Architecture

```
Tag push (v*) → GitHub Actions
  ├── Job 1: SideStore IPA (existing, unsigned)
  └── Job 2: TestFlight
        ├── fastlane match (fetch certs from private repo)
        ├── flutter build ipa (signed)
        └── fastlane pilot upload (→ TestFlight)
```

## New files

- `ios/Gemfile` — pins fastlane version
- `ios/fastlane/Fastfile` — `beta` lane (match → build → upload)
- `ios/fastlane/Appfile` — app_identifier, team_id, Apple ID
- `ios/fastlane/Matchfile` — match config (git repo URL, type)
- `ios/ExportOptions.plist` — export settings for app-store distribution

## Modified files

- `.github/workflows/build-ios.yml` — add TestFlight job alongside existing SideStore job

## GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `MATCH_GIT_URL` | Private repo URL for certs |
| `MATCH_PASSWORD` | Encrypts certs at rest in the repo |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API key issuer ID |
| `APP_STORE_CONNECT_API_KEY` | Base64-encoded .p8 key file |
| `MATCH_DEPLOY_KEY` | SSH deploy key for the private certs repo |

## Pre-requisites (manual, one-time)

1. Create private GitHub repo for certs (e.g. `ios-certs`)
2. Generate App Store Connect API Key (App Store Connect → Users & Access → Integrations → Keys)
3. Run `fastlane match init` + `fastlane match appstore` locally to generate and store certs
4. Add all secrets to GitHub repo settings

## Unchanged

- SideStore IPA job runs as before
- Tag-based trigger (`v*`) — both jobs run in parallel
- SideStore source JSON update PR logic
