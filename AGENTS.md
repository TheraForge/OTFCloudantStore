# AGENTS.md

## Project Structure & Module Organization

`OTFCloudantStore` is an iOS/watchOS Swift framework distributed through CocoaPods. Open the repository through `OTFCloudantStore.xcworkspace`, not the project file, so the Pods project is available.

- `OTFCloudantStore.xcodeproj` and `OTFCloudantStore.xcworkspace`: Xcode project and CocoaPods workspace.
- `OTFCloudantStore/Classes`: framework source included by `OTFCloudantStore.podspec`.
- `OTFCloudantStore/Classes/Codable`: Cloudant encoder, decoder, and date formatting support.
- `OTFCloudantStore/Classes/Store`: core store, query, networking, and synchronization APIs.
- `OTFCloudantStore/Classes/Store/Apple/CareKit`, `HealthKit`, `ResearchKit`: optional platform integrations guarded by `CARE` and `HEALTH` compilation conditions.
- `OTFCloudantStore/Classes/Store/Synchronization`: watch and remote synchronization code.
- `App`: small host app, storyboards, assets, Info.plist, and entitlements used by schemes/tests.
- `OTFCloudantStoreTests`: XCTest target covering Codable, CareKit contracts, HealthKit conversion, networking, sync, watch delivery, and legacy integration paths.
- `Scripts/generate_coverage_badge.rb` and `badges/coverage.svg`: local coverage badge tooling and checked-in badge.
- `Podfile`, `Podfile.lock`, `OTFCloudantStore.podspec`: dependency and pod publishing configuration.

Place new framework code under the closest existing domain folder. Keep platform-specific code behind the existing `#if CARE`, `#if HEALTH`, or `#if CARE && HEALTH` gates.

## Build, Test, and Development Commands

```sh
open OTFCloudantStore.xcworkspace
```
Open the CocoaPods workspace in Xcode.

```sh
pod install
```
Install Pods.

```sh
xcodebuild -list -workspace OTFCloudantStore.xcworkspace
```
List available workspace schemes, including `OTFCloudantStore`, `OTFCloudantStore Care`, `OTFCloudantStore Health`, `OTFCloudantStore CareHealth`, `OTFCloudantStoreWatch`, `App`, and `OTFCloudantStoreTests`.

```sh
xcodebuild -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStore build
xcodebuild -workspace OTFCloudantStore.xcworkspace -scheme "OTFCloudantStore CareHealth" build
```
Build the base framework or the CareKit plus HealthKit variant.

```sh
xcodebuild -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -showdestinations
export OTF_TEST_DESTINATION='platform=iOS Simulator,id=<SIMULATOR_UDID>'
xcodebuild test -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -destination "$OTF_TEST_DESTINATION"
```
List available destinations, replace `<SIMULATOR_UDID>` with a simulator
identifier, and run XCTest with that portable destination setting.

```sh
xcodebuild test -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -destination "$OTF_TEST_DESTINATION" -only-testing:OTFCloudantStoreTests/CloudantCodableTests
```
Run one test class. Add `/testMethodName` to target a single test method.

```sh
swiftlint lint --config .swiftlint.yml
```
Run SwiftLint when it is installed locally. No SwiftFormat configuration is present.

```sh
xcodebuild test -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -destination "$OTF_TEST_DESTINATION" -enableCodeCoverage YES -resultBundlePath /tmp/OTFCloudantStore-coverage.xcresult
xcrun xccov view --report --only-targets /tmp/OTFCloudantStore-coverage.xcresult
ruby Scripts/generate_coverage_badge.rb /tmp/OTFCloudantStore-coverage.xcresult
```
Regenerate `badges/coverage.svg` from an Xcode coverage result.

## Coding Style & Naming Conventions

Swift uses four-space indentation in most files, explicit access control for public framework APIs, and XCTest methods named `test...`. Types and files usually carry the `OTFCloudant...` prefix for framework models and services; extension files follow `Type+Extension.swift` or `OTFCloudantStore+Domain.swift`.

Keep code organized by capability: Codable helpers in `Classes/Codable`, store/query/network code in `Classes/Store`, Apple integration adapters under `Classes/Store/Apple`, and watch/remote sync under `Classes/Store/Synchronization`. Prefer the existing completion-handler and `Result` patterns unless touching code that already uses another style.

SwiftLint is configured in `.swiftlint.yml` with Xcode output, excluded `Pods` and build artifacts, relaxed line/file length thresholds, and opt-in rules such as `first_where`, `empty_string`, and `fatal_error_message`.

## Testing Guidelines

Tests use XCTest only. The main target is `OTFCloudantStoreTests`; there are no separate UI test, Quick/Nimble, Swift Testing, or snapshot targets in this repository.

Name new tests after the behavior they protect, for example `testSynchronizeWatchOSRoutesToPullRevisions`. Keep fakes, spies, and fixtures private inside the relevant test file unless they are shared by existing test base classes such as `OTFCloudantTests` or `CareKitStoreContractTestCase`.

Some legacy HealthKit tests require simulator Health permissions and may return early when authorization is unavailable. Cloudant replication helpers read `OTFCLOUDANT_SYNC_TARGET_URL`, `OTFCLOUDANT_SYNC_USERNAME`, `OTFCLOUDANT_SYNC_PASSWORD`, and `OTFCLOUDANT_SYNC_API_KEY`; do not commit real values.

Whenever test targets are added, removed, renamed, or significantly reorganized, update the coverage badge and any related coverage documentation or scripts so they continue to reflect the current test configuration.

## Commit & Pull Request Guidelines

Recent history mixes concise imperative summaries (`Harden watch sync merge safety`, `Add manual test coverage badge`) with occasional Conventional Commit-style prefixes for test and chore work (`test: cover CareKit store contracts`, `chore: bump podspec version...`). Prefer a short imperative subject; use a `test:` or `chore:` prefix when it matches the change.

Before opening a PR, include a brief description, test evidence, coverage badge updates when applicable, and notes for dependency, podspec, entitlement, signing, or release changes. No checked-in GitHub Actions, Danger, Fastlane, Makefile, or release workflow is currently documented.

## Architecture Overview

The framework wraps `OTFCDTDatastore` with Cloudant-style Codable conversion, typed query construction, network helpers, and optional CareKit/HealthKit adapters. `OTFCloudantStore` is the central entry point and manages local datastore indexes, CRUD/query behavior, remote synchronization, and delegate notifications.

Conditional schemes and pod subspecs enable `CLOUDANT`, `CARE`, `HEALTH`, or `CARE HEALTH` builds. When changing shared store behavior, verify the base and relevant conditional scheme because platform integrations compile different code paths.

## Security & Configuration Tips

Do not commit secrets, `.env` files, generated build products, or local Xcode user data; `.gitignore` already excludes those paths plus `Pods/`, `Podfile.lock`, and `build/`. Be careful with `App/App.entitlements`, `App/AppCareHealth.entitlements`, bundle identifiers, development team settings, and HealthKit usage descriptions in plist files.

The podspec is the source of published dependency declarations. The `Podfile` is local workspace setup and includes a sibling-path dependency for `OTFCDTDatastore`.

## Agent-Specific Instructions

- Prefer minimal, targeted changes that follow existing folders, prefixes, and conditional compilation gates.
- Run the relevant build, test, coverage, and SwiftLint commands before finishing when the change touches Swift behavior.
- Update tests when behavior changes, especially sync, query, Codable, CareKit, HealthKit, or watch delivery logic.
- Update fixtures, generated files, and `badges/coverage.svg` when related tests or coverage inputs change.
- Do not introduce new dependencies without clear justification and corresponding `Podfile`/podspec updates.
- Do not modify signing, bundle identifiers, entitlements, HealthKit permissions, pod release settings, or CI/release automation unless explicitly requested.

## Documentation Audit Guidance

- For branch documentation audits, compare `git diff main...HEAD` against the current code and tests, then document only behavior that is implemented or intentionally planned.
- Prefer focused docs under `docs/` over long README sections. Keep root `AGENTS.md` limited to durable repository guidance.
- For docs-only changes, run Markdown sanity checks for trailing whitespace, placeholder text, and relevant links. Run targeted Xcode tests only when Swift behavior changes.
- Preserve synchronization invariants: legacy snapshot merges must not delete unmentioned documents, typed outcome deletions must validate logical identity, non-deletion skips must not count as delivery failure, and backend conflict hooks must not be documented as implemented in this library.
