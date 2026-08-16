# Testing

This document summarizes the active verification workflow for maintainers. It is
intended to complement the focused behavior docs:
[Synchronization](synchronization.md),
[CareKit Store Contract](carekit-store-contract.md),
[Querying and Indexes](querying-and-indexes.md), and
[HealthKit Synchronization](healthkit-synchronization.md).

## Standard Commands

Install workspace dependencies when needed:

```sh
pod install
```

List the available destinations and select a simulator for the test commands:

```sh
xcodebuild -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -showdestinations
export OTF_TEST_DESTINATION='platform=iOS Simulator,id=<SIMULATOR_UDID>'
xcodebuild test -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -destination "$OTF_TEST_DESTINATION"
```

Replace `<SIMULATOR_UDID>` with an available simulator identifier from the
first command.

Run with coverage and regenerate the checked-in badge:

```sh
xcodebuild test -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -destination "$OTF_TEST_DESTINATION" -enableCodeCoverage YES -resultBundlePath /tmp/OTFCloudantStore-coverage.xcresult
xcrun xccov view --report --only-targets /tmp/OTFCloudantStore-coverage.xcresult
ruby Scripts/generate_coverage_badge.rb /tmp/OTFCloudantStore-coverage.xcresult
```

For docs-only changes, run Markdown sanity checks instead of the full Xcode
suite unless Swift behavior also changed:

```sh
rg -n '[[:blank:]]$' docs
rg -n -i 'to(do)|tb(d)|fix(me)|place(holder)|lo(rem)|x(xx)' docs
```

## Test Map

| Area | Primary tests |
| --- | --- |
| Codable dictionaries, dates, data, errors, query helpers, and utility extensions | `CloudantCodableTests.swift` |
| CareKit CRUD, query adapters, local sorting, pagination, task intervals, outcome identity, and index behavior | `CareKitStoreContractTests.swift`, `InternalTestSeamTests.swift` |
| Watch routing, incremental payloads, conflict handling, deletion safety, and delivery outcomes | `SynchronizationAlgorithmTests.swift`, `WatchDeliveryOutcomeTests.swift` |
| HealthKit sample conversion, supported type parsing, duplicate prevention, anchored updates, and availability handling | `HealthKitConversionSynchronizerTests.swift` |
| Network request behavior, StoreService seams, SwiftUI environment store access, and ResearchKit result coding | `NetworkStoreServiceResearchKitTests.swift` |

## Maintainer Notes

`CloudantEncoder` and `CloudantDecoder` default to ISO-8601 date strategies and
deferred `Data` strategies. `CloudantEncoder.encode(_:)` requires a top-level
dictionary. Decoder errors preserve useful coding paths for malformed values,
numeric overflow, invalid base64 data, and malformed ISO-8601 strings.

`CDTDocumentRevision.encodedDictionary(fromEntity:)` adds `entityType`, CareKit
task `startDate` and `endDate` metadata, and canonical outcome document IDs in
the form `<taskUUID>_<occurrenceIndex>`. See
[CareKit Store Contract](carekit-store-contract.md) for outcome identity rules.

`OTFNetwork.sendRequest(urlRequest:)` fails non-2xx HTTP responses with
`OTFNetworkError.httpStatus`, reports `OTFNetworkError.emptyData` when no data
or error is returned, and gives transport errors precedence. Endpoint GET
requests append percent-escaped query values; POST requests do not append
`params`.

`OTFCloudantORKResult.userInfo` must contain only JSON-serializable values. It
is encoded as JSON `Data` and decoded back into a `[String: Any]` dictionary.
Non-JSON values fail encoding, and invalid user info data fails decoding.
