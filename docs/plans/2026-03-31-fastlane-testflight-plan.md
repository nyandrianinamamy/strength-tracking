# Fastlane + TestFlight CI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automate signed iOS builds and TestFlight uploads on tag push (`v*`) using Fastlane, alongside the existing SideStore IPA workflow.

**Architecture:** Add Fastlane to `ios/` with `match` for code signing (certs stored in a private GitHub repo) and `pilot` for TestFlight upload. The existing `build-ios.yml` gains a second parallel job that runs the Fastlane `beta` lane. App Store Connect API key authentication is used (no Apple ID password needed).

**Tech Stack:** Fastlane, fastlane match, GitHub Actions (macos-latest), App Store Connect API, Flutter

---

## Pre-requisites (Manual — Do These First)

Before any code tasks, complete these one-time setup steps:

### P1: Create private certs repo

1. Go to github.com → New repository
2. Name: `ios-certs` (or similar)
3. Visibility: **Private**
4. Initialize with README: yes
5. Note the SSH URL: `git@github.com:nyandrianinamamy/ios-certs.git`

### P2: Generate App Store Connect API Key

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Users and Access → Integrations → App Store Connect API → Keys
3. Click **+** → Name: "Fastlane CI", Access: **App Manager**
4. Download the `.p8` file — **you can only download it once**
5. Note the **Key ID** (e.g. `ABC123DEF4`) and **Issuer ID** (shown at top of page)
6. Base64-encode the key: `base64 -i AuthKey_ABC123DEF4.p8 | tr -d '\n'`

### P3: Generate SSH deploy key for certs repo

```bash
ssh-keygen -t ed25519 -C "match-deploy-key" -f match_deploy_key -N ""
```

1. Add `match_deploy_key.pub` as a **Deploy Key** (with write access) on the `ios-certs` repo: Settings → Deploy keys → Add
2. The private key (`match_deploy_key`) will be stored as a GitHub secret

### P4: Create the App on App Store Connect

1. Go to App Store Connect → Apps → **+** → New App
2. Platform: iOS
3. Name: `Kotrana: Musculation`
4. Bundle ID: `dev.mamy-r.kotrana`
5. SKU: `kotrana-musculation`

### P5: Add GitHub Secrets

Go to the `strength-tracking` repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret name | Value |
|-------------|-------|
| `MATCH_GIT_URL` | `git@github.com:nyandrianinamamy/ios-certs.git` |
| `MATCH_PASSWORD` | A strong passphrase you choose (encrypts certs at rest) |
| `APP_STORE_CONNECT_API_KEY_ID` | The Key ID from P2 |
| `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID from P2 |
| `APP_STORE_CONNECT_API_KEY` | Base64-encoded .p8 content from P2 |
| `MATCH_DEPLOY_KEY` | Contents of `match_deploy_key` private key file from P3 |

---

## Task 1: Create Gemfile

**Files:**
- Create: `ios/Gemfile`

**Step 1: Create the Gemfile**

```ruby
source "https://rubygems.org"

gem "fastlane", "~> 2.226"
gem "cocoapods", "~> 1.16"
```

**Step 2: Install and generate lockfile**

Run: `cd ios && bundle install`
Expected: Gemfile.lock is created

**Step 3: Commit**

```bash
git add ios/Gemfile ios/Gemfile.lock
git commit -m "chore: add Gemfile for fastlane"
```

---

## Task 2: Create Fastlane Appfile

**Files:**
- Create: `ios/fastlane/Appfile`

**Step 1: Create the Appfile**

```ruby
app_identifier("dev.mamy-r.kotrana")
team_id("6B673XM2ST")
```

**Step 2: Commit**

```bash
git add ios/fastlane/Appfile
git commit -m "chore: add fastlane Appfile"
```

---

## Task 3: Create Fastlane Matchfile

**Files:**
- Create: `ios/fastlane/Matchfile`

**Step 1: Create the Matchfile**

```ruby
git_url(ENV["MATCH_GIT_URL"] || "git@github.com:nyandrianinamamy/ios-certs.git")
storage_mode("git")
type("appstore")
app_identifier(["dev.mamy-r.kotrana"])
team_id("6B673XM2ST")
```

**Step 2: Commit**

```bash
git add ios/fastlane/Matchfile
git commit -m "chore: add fastlane Matchfile"
```

---

## Task 4: Create Fastlane Fastfile

**Files:**
- Create: `ios/fastlane/Fastfile`

**Step 1: Create the Fastfile**

```ruby
default_platform(:ios)

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    setup_ci

    # Authenticate with App Store Connect API
    api_key = app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_API_KEY"],
      is_key_content_base64: true,
    )

    # Fetch signing certificates and profiles
    match(
      type: "appstore",
      readonly: true,
      api_key: api_key,
    )

    # Build the Flutter app (signed)
    # Flutter build must be run before this lane — see CI workflow
    # This lane handles signing + upload only

    # Build the Xcode archive with proper signing
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store",
      export_options: {
        provisioningProfiles: {
          "dev.mamy-r.kotrana" => "match AppStore dev.mamy-r.kotrana",
        },
      },
      output_directory: "../build/ios/ipa",
      output_name: "Kotrana.ipa",
    )

    # Upload to TestFlight
    upload_to_testflight(
      api_key: api_key,
      skip_waiting_for_build_processing: true,
      ipa: "../build/ios/ipa/Kotrana.ipa",
    )
  end
end
```

**Step 2: Commit**

```bash
git add ios/fastlane/Fastfile
git commit -m "chore: add fastlane Fastfile with beta lane"
```

---

## Task 5: Initialize match locally

This must be done on your Mac, not in CI.

**Step 1: Install fastlane locally**

```bash
cd ios && bundle install
```

**Step 2: Generate appstore certs and profiles**

```bash
cd ios && bundle exec fastlane match appstore
```

This will:
- Generate a distribution certificate
- Generate an App Store provisioning profile for `dev.mamy-r.kotrana`
- Encrypt and push both to the `ios-certs` repo

You'll be prompted for the `MATCH_PASSWORD` — use the same passphrase you set in the GitHub secret.

**Step 3: Verify match created the profiles**

```bash
cd ios && bundle exec fastlane match appstore --readonly
```

Expected: "All required keys, certificates and provisioning profiles are installed"

---

## Task 6: Update GitHub Actions workflow

**Files:**
- Modify: `.github/workflows/build-ios.yml`

**Step 1: Rename existing job and add TestFlight job**

The full updated workflow:

```yaml
name: Build iOS

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write
  pull-requests: write

jobs:
  # ─── Existing SideStore IPA build (unchanged logic) ───
  build-sidestore:
    runs-on: macos-latest
    outputs:
      tag: ${{ steps.version.outputs.tag }}
      number: ${{ steps.version.outputs.number }}
      sidestore_size: ${{ steps.ipa.outputs.sidestore_size }}
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Flutter dependencies
        run: flutter pub get

      - name: Install CocoaPods dependencies
        run: cd ios && pod install

      - name: Extract version from tag
        id: version
        run: |
          TAG="${GITHUB_REF#refs/tags/}"
          echo "tag=${TAG}" >> "$GITHUB_OUTPUT"
          echo "number=${TAG#v}" >> "$GITHUB_OUTPUT"

      - name: Build unsigned iOS app
        run: flutter build ios --release --no-codesign --build-name=${{ steps.version.outputs.number }}

      - name: Package IPA variants
        run: |
          package_ipa() {
            local bundle_root="$1"
            local output_file="$2"
            local strip_watch="$3"
            local payload_dir="$bundle_root/Payload"

            rm -rf "$bundle_root" "$output_file"
            mkdir -p "$payload_dir"

            ditto build/ios/iphoneos/Runner.app "$payload_dir/Runner.app"

            if [ "$strip_watch" = "true" ]; then
              rm -rf "$payload_dir/Runner.app/Watch"
            fi

            find "$payload_dir" -name "_CodeSignature" -type d -prune -exec rm -rf {} +
            find "$payload_dir" -name "embedded.mobileprovision" -type f -delete
            xattr -cr "$payload_dir" || true
            ditto -c -k --sequesterRsrc --keepParent "$payload_dir" "$output_file"
          }

          package_ipa build/full-ipa build/StrengthApp.ipa false
          package_ipa build/sidestore-ipa build/StrengthApp-sidestore.ipa true

      - name: Validate IPA contents
        run: |
          python3 - <<'PYEOF'
          import sys
          import zipfile

          def validate(path: str, expect_watch: bool) -> None:
              with zipfile.ZipFile(path) as zf:
                  names = zf.namelist()

              def has_entry(entry: str) -> bool:
                  return entry in names or any(name.startswith(entry) for name in names)

              required_entries = [
                  "Payload/",
                  "Payload/Runner.app/",
                  "Payload/Runner.app/Info.plist",
                  "Payload/Runner.app/Runner",
              ]

              missing = [name for name in required_entries if not has_entry(name)]
              if missing:
                  print(f"{path}: missing expected IPA entries: {missing}", file=sys.stderr)
                  sys.exit(1)

              has_watch = any(name.startswith("Payload/Runner.app/Watch/") for name in names)
              if has_watch != expect_watch:
                  state = "present" if has_watch else "missing"
                  print(f"{path}: watch bundle unexpectedly {state}", file=sys.stderr)
                  sys.exit(1)

              print(f"Validated {path} (watch bundle {'present' if has_watch else 'absent'})")

          validate("build/StrengthApp.ipa", expect_watch=True)
          validate("build/StrengthApp-sidestore.ipa", expect_watch=False)
          PYEOF

      - name: Get IPA sizes
        id: ipa
        run: |
          echo "full_size=$(stat -f%z build/StrengthApp.ipa)" >> "$GITHUB_OUTPUT"
          echo "sidestore_size=$(stat -f%z build/StrengthApp-sidestore.ipa)" >> "$GITHUB_OUTPUT"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: ${{ steps.version.outputs.tag }}
          files: |
            build/StrengthApp.ipa
            build/StrengthApp-sidestore.ipa
          generate_release_notes: true

  # ─── TestFlight upload via Fastlane ───
  build-testflight:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Flutter dependencies
        run: flutter pub get

      - name: Install CocoaPods dependencies
        run: cd ios && pod install

      - name: Extract version from tag
        id: version
        run: |
          TAG="${GITHUB_REF#refs/tags/}"
          echo "tag=${TAG}" >> "$GITHUB_OUTPUT"
          echo "number=${TAG#v}" >> "$GITHUB_OUTPUT"

      - name: Build Flutter iOS (release, no-codesign)
        run: flutter build ios --release --no-codesign --build-name=${{ steps.version.outputs.number }}

      - name: Setup Ruby and Fastlane
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true
          working-directory: ios

      - name: Setup SSH for match
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.MATCH_DEPLOY_KEY }}

      - name: Build and upload to TestFlight
        working-directory: ios
        env:
          MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
        run: bundle exec fastlane beta

  # ─── Update SideStore source JSON ───
  update-sidestore:
    runs-on: macos-latest
    needs: build-sidestore
    steps:
      - uses: actions/checkout@v4

      - name: Create branch and update SideStore source JSON
        env:
          TAG: ${{ needs.build-sidestore.outputs.tag }}
          IPA_SIZE: ${{ needs.build-sidestore.outputs.sidestore_size }}
        run: |
          git fetch origin main
          git checkout -B chore/sidestore-${{ needs.build-sidestore.outputs.tag }} origin/main

          export DATE=$(date -u +"%Y-%m-%d")
          export DOWNLOAD_URL="https://github.com/nyandrianinamamy/strength-tracking/releases/download/${TAG}/StrengthApp-sidestore.ipa"

          python3 - <<'PYEOF'
          import json, os

          tag = os.environ["TAG"]
          version = tag.lstrip("v")
          date = os.environ["DATE"]
          size = int(os.environ["IPA_SIZE"])
          download_url = os.environ["DOWNLOAD_URL"]

          with open("sidestore-source.json", "r") as f:
              source = json.load(f)

          new_version = {
              "version": version,
              "date": date,
              "downloadURL": download_url,
              "size": size,
              "localizedDescription": f"Release {tag}"
          }

          versions = source["apps"][0]["versions"]
          versions = [v for v in versions if v["version"] != version]
          versions.insert(0, new_version)
          source["apps"][0]["versions"] = versions

          with open("sidestore-source.json", "w") as f:
              json.dump(source, f, indent=2)
              f.write("\n")
          PYEOF

          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add sidestore-source.json
          git commit -m "chore: update SideStore source for ${{ needs.build-sidestore.outputs.tag }}"
          git push -u origin chore/sidestore-${{ needs.build-sidestore.outputs.tag }}

      - name: Create and merge PR
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          PR_URL=$(gh pr create \
            --title "chore: update SideStore source for ${{ needs.build-sidestore.outputs.tag }}" \
            --body "Auto-generated by the iOS build workflow. Updates \`sidestore-source.json\` with release metadata for ${{ needs.build-sidestore.outputs.tag }}." \
            --base main \
            --head chore/sidestore-${{ needs.build-sidestore.outputs.tag }})

          gh pr merge "$PR_URL" --squash --auto --delete-branch
```

**Step 2: Verify the YAML is valid**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-ios.yml'))"`
Expected: No output (valid YAML)

**Step 3: Commit**

```bash
git add .github/workflows/build-ios.yml
git commit -m "ci: add TestFlight upload job via Fastlane"
```

---

## Task 7: Add Fastlane to .gitignore

**Files:**
- Modify: `.gitignore`

**Step 1: Add Fastlane-specific ignores**

Append to `.gitignore`:

```
# Fastlane
ios/fastlane/report.xml
ios/fastlane/Preview.html
ios/fastlane/screenshots
ios/fastlane/test_output
ios/fastlane/README.md
```

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add fastlane entries to .gitignore"
```

---

## Task 8: Test locally (dry run)

**Step 1: Verify Fastlane loads correctly**

```bash
cd ios && bundle exec fastlane lanes
```

Expected: Shows `beta` lane under `ios` platform

**Step 2: Verify match can connect (requires P1-P5 complete)**

```bash
cd ios && bundle exec fastlane match appstore --readonly
```

Expected: "All required keys, certificates and provisioning profiles are installed"

---

## Summary of execution order

1. Tasks 1-4: Create Fastlane files (can be done immediately)
2. Pre-requisites P1-P5: Manual Apple/GitHub setup
3. Task 5: Initialize match locally (requires P1-P5)
4. Task 6: Update GitHub Actions workflow
5. Task 7: Update .gitignore
6. Task 8: Local dry run
7. Push tag to test end-to-end
