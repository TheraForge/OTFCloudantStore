# OTFCloudantStore

![Coverage](badges/coverage.svg)

TheraForge's OTFCloudantStore is an iOS/watchOS Swift framework that wraps
`OTFCDTDatastore` with Cloudant-style Codable conversion, local query/index
support, revision-aware persistence helpers, optional CareKit and HealthKit
adapters, watch synchronization helpers, and small network utilities.

Application code owns backend replication and app-level conflict policy. This
library manages local document persistence, CareKit model bridging, HealthKit
sample conversion, and watch payload application. Backend conflict hooks remain
application-layer responsibilities and are not implemented as active backend
conflict resolution in this library.

## TheraForge Frameworks

* [OTFToolBox](../../../OTFToolBox)
* [OTFTemplateBox](../../../OTFTemplateBox)
* [OTFCareKit](../../../OTFCareKit)
* [OTFCDTDatastore](../../../OTFCDTDatastore)
* [OTFCloudClientAPI](../../../OTFCloudClientAPI)

## Change Log

<details open>
  <summary>Release 2.1.0</summary>
  <ul>
    <li>Added incremental watch synchronization payloads for tasks, outcomes, typed deletions, and legacy deletion compatibility.</li>
    <li>Added watch delivery outcomes so callers can distinguish immediate delivery from queued delivery.</li>
    <li>Hardened watch synchronization conflict and deletion handling so newer task and outcome revisions apply while stale, incompatible, or unsafe requests are skipped.</li>
    <li>Preserved unmentioned documents during legacy watch revision merges.</li>
    <li>Improved CareKit queries and outcomes with local sorting and pagination, schedule-overlap task intervals, canonical outcome identity, and stale-duplicate cleanup.</li>
    <li>Added client-side index bootstrap and validation for common CareKit and sorted query paths.</li>
    <li>Improved HealthKit sample identity and metadata conversion, including local propagation of deleted samples from anchored updates.</li>
    <li>Hardened networking by reporting non-success and empty responses as errors while redacting sensitive diagnostic output.</li>
    <li>Updated dependencies to OTFCDTDatastore 2.1.1-tf.3 and OTFCloudClientAPI 2.1.0.</li>
    <li>Expanded unit test coverage and added a checked-in coverage badge workflow with focused maintenance documentation.</li>
  </ul>
</details>

<details>
  <summary>Release 2.0.0</summary>
  <ul>
    <li>Updated dependencies for TheraForge 2.0.0 release.</li>
  </ul>
</details>

<details>
  <summary>Release 1.0.5-beta</summary>
  <ul>
    <li>Improved Readme file.</li>
    <li>Updated company name and copyright date.</li>
  </ul>
</details>

<details>
  <summary>Release 1.0.4-beta</summary>
  <ul>
    <li>Added synchronization.</li>
  </ul>
</details>

<details>
  <summary>Release 1.0.3-beta</summary>
  <ul>
    <li>Added watchOS support.</li>
  </ul>
</details>

<details>
  <summary>Release 1.0.1-beta</summary>
  <ul>
    <li>Removed various warnings. Filter outcome result set based on the date interval.</li>
  </ul>
</details>

<details>
  <summary>Release 1.0.0-beta</summary>
  <ul>
    <li>First beta release of the framework.</li>
  </ul>
</details>

## Table of Contents

* [Requirements](#requirements)
* [Installation](#installation)
* [Subspecs and Compilation Flags](#subspecs-and-compilation-flags)
* [Store Initialization and Indexes](#store-initialization-and-indexes)
* [Revision-Aware CRUD](#revision-aware-crud)
* [Querying](#querying)
* [Synchronization](#synchronization)
  * [OTFWatchConnectivityPeer](#otfwatchconnectivitypeer)
* [CareKit Integration](#carekit-integration)
* [HealthKit Integration](#healthkit-integration)
* [Errors](#errors)
* [Focused Documentation](#focused-documentation)
* [Testing and Coverage](#testing-and-coverage)
* [License](#license)

## Requirements

The OTFCloudantStore framework supports iOS and watchOS. The podspec currently
declares iOS 16.0 and watchOS 9.0 deployment targets. Development requires
Xcode 16 or later, matching the OTFMagicBox application toolchain requirement.

## Installation

OTFCloudantStore is available through
[CocoaPods](https://cocoapods.org). Add the pod to your Podfile:

```ruby
pod "OTFCloudantStore"
```

The default subspec is `CloudantOnly`. Choose an explicit subspec when the app
needs CareKit, HealthKit, or both:

```ruby
pod "OTFCloudantStore/CloudantOnly"
pod "OTFCloudantStore/CloudantCare"
pod "OTFCloudantStore/CloudantHealth"
pod "OTFCloudantStore/CloudantCareHealth"
```

The podspec is the source of published dependency declarations.

## Subspecs and Compilation Flags

The podspec uses `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to compile optional
platform integrations.

| Subspec | Flags | Use when |
| --- | --- | --- |
| `CloudantOnly` | `CLOUDANT` | The app needs the base install without CareKit or HealthKit APIs. |
| `CloudantCare` | `CARE` | The app needs CareKit dependencies and CARE-only code. The CareKit store APIs in this README require `CloudantCareHealth`. |
| `CloudantHealth` | `HEALTH` | The app needs HealthKit sample and parsing types. `OTFHealthKitSynchronizer` requires `CloudantCareHealth`. |
| `CloudantCareHealth` | `CARE HEALTH` | The app needs CareKit store APIs, generic CRUD/query conveniences, and `OTFHealthKitSynchronizer`. |

The generic CRUD convenience APIs compile behind `CARE && HEALTH`.
`OTFCloudantQuery` compiles behind `HEALTH`, and the store collection helpers
shown below compile behind `CARE && HEALTH`. Use `CloudantCareHealth` for the
complete CRUD and query examples in this README.

## Store Initialization and Indexes

`OTFCloudantStore` creates or opens a named local CDT datastore under the app's
documents directory. The public initializer also bootstraps the required
client-side indexes used by common CareKit and HealthKit query paths.

```swift
import OTFCloudantStore

do {
    let store = try OTFCloudantStore(storeName: "local_db")
    let missingIndexes = store.validateClientSideIndexes()
    if !missingIndexes.isEmpty {
        // Log or report missing local index definitions.
    }
} catch {
    // Handle local store initialization errors.
}
```

`ensureClientSideIndexes()` creates missing required indexes and returns any
definitions that are still missing after bootstrap. `validateClientSideIndexes()`
does not mutate the datastore; it reports missing definitions for diagnostics.
See [Querying and Indexes](docs/querying-and-indexes.md) for the index matrix
and sorted-query rules.

## Revision-Aware CRUD

Generic entities stored through the convenience CRUD APIs must conform to
`Codable`, `Identifiable`, and `OTFCloudantRevision`, with `String` identifiers.
`id` maps to the Cloudant document ID. `revId` stores the current CDT document
revision, which is needed for update and delete safety.

These convenience APIs require `CloudantCareHealth`.

```swift
struct Appointment: Codable, Identifiable, OTFCloudantRevision {
    var id: String
    var revId: String?
    var title: String
    var updatedDate: String
}
```

### Add

`add` creates new CDT documents from encoded entities and returns the saved
entities with their new `revId` values when decoding succeeds.

```swift
func addAppointment(to store: OTFCloudantStore) {
    let appointment = Appointment(
        id: "appointment-1",
        revId: nil,
        title: "Family Practice Doctor",
        updatedDate: "2026-07-04T00:00:00Z"
    )

    store.add([appointment]) { result in
        switch result {
        case .success(let savedAppointments):
            print(savedAppointments.first?.revId ?? "missing revision")
        case .failure(let error):
            print(error.localizedDescription)
        }
    }
}
```

### Fetch

Use `get` on an `OTFCloudantQuery` for simple Cloudant-style selectors, or use
`fetch(cloudantQuery:)` for CareKit query adapter paths.

```swift
func fetchAppointments(from store: OTFCloudantStore) {
    let query = store
        .collection(className: "Appointment")
        .where("title", isEqualTo: "Family Practice Doctor")
        .sort(ascendingBy: "updatedDate")

    query.get { (result: Result<[Appointment], OTFCloudantError>) in
        switch result {
        case .success(let appointments):
            print("Fetched \(appointments.count) appointments")
        case .failure(let error):
            print(error.localizedDescription)
        }
    }
}
```

### Update

`update` writes the encoded entity body using the current document revision.
When `revId` is nil, the store fetches the current revision for the document ID
before updating.

```swift
func updateAppointment(_ appointment: Appointment, in store: OTFCloudantStore) {
    var edited = appointment
    edited.title = "Updated Appointment"

    store.update([edited]) { result in
        if case .failure(let error) = result {
            print(error.localizedDescription)
        }
    }
}
```

### Delete

`delete` resolves the current CDT revision for each document ID and deletes that
revision.

```swift
func deleteAppointment(_ appointment: Appointment, from store: OTFCloudantStore) {
    store.delete([appointment]) { result in
        if case .failure(let error) = result {
            print(error.localizedDescription)
        }
    }
}
```

## Querying

`OTFCloudantQuery` builds selector dictionaries for datastore `find` calls. A
CareKit constructor seeds the selector with `entityType`; HealthKit constructors
seed `entityType` and sample `type`.

```swift
let query = store
    .collection(className: "Appointment")
    .where("title", isEqualTo: "Family Practice Doctor")
    .where("updatedDate", isGreeterThanOrEqualTo: "2026-07-01T00:00:00Z")
    .limit(limit: 20)
    .skip(skip: 0)
```

Supported selector helpers include equality, less-than, less-than-or-equal,
greater-than, greater-than-or-equal, not-equal, `in`, `notIn`, `exists`, `mod`,
and `size`. `where(field:mode:equal:)` throws `.invalidValue` when the divisor
is zero.

### Query Components

Use query components when a selector needs to be assembled from reusable pieces.

```swift
let title = OTFCloudantQueryComponent.simpleComponent(
    "title",
    .equal,
    "Family Practice Doctor"
)

let date = OTFCloudantQueryComponent.simpleComponent(
    "updatedDate",
    .greaterThanOrEqual,
    "2026-07-01T00:00:00Z"
)

let combined = OTFCloudantCombinationQueryComponent.combinedQueryComponent(
    title,
    .and,
    date
)

let query = store
    .collection(className: "Appointment")
    .where(query: combined)
```

For broader selectors, combine two `OTFCloudantCombinationQueryComponent`
instances with `OTFCloudantComplexQueryComponent.complexQueryComponent`.

```swift
let urgent = OTFCloudantCombinationQueryComponent.combinedQueryComponent(
    OTFCloudantQueryComponent.simpleComponent("priority", .equal, "urgent"),
    .and,
    OTFCloudantQueryComponent.simpleComponent("status", .notEqualTo, "done")
)

let routine = OTFCloudantCombinationQueryComponent.combinedQueryComponent(
    OTFCloudantQueryComponent.simpleComponent("priority", .equal, "routine"),
    .and,
    OTFCloudantQueryComponent.simpleComponent("status", .equal, "scheduled")
)

let complex = OTFCloudantComplexQueryComponent.complexQueryComponent(
    urgent,
    .or,
    routine
)

let query = store.collection(className: "Appointment").where(query: complex)
```

### Sorting and Pagination

Use `ordered(by:ascending:)`, `sort(ascendingBy:)`, or `sort(descendingBy:)` for
sorted results. Mixed sort directions fail with `.fetchFailed`. Sorted fields
must be indexed; missing sorted-field indexes also complete with `.fetchFailed`
and do not return a successful empty array.

```swift
let query = store
    .collection(className: "Appointment")
    .where("title", isEqualTo: "Family Practice Doctor")
    .sort(descendingBy: "updatedDate")
    .limit(limit: 10)
```

See [Querying and Indexes](docs/querying-and-indexes.md) for supported selector
details, required index definitions, CareKit query adapter mapping, and local
post-processing rules.

## Synchronization

Watch synchronization is explicit and route-based. The store uses the remote
peer assigned at initialization to route requests.

| Target | Behavior |
| --- | --- |
| `.watchOS` | Requests legacy revisions through `pullRevisions`, then merges included task and outcome revisions. |
| `.mobile` | Notifies the watch with `updatewatchOS()` only. It does not push entity revisions. |
| `.watchAppUpdate` | Pushes revisions, then notifies the watch. `synchronizeWatchAppUpdate` reports `.delivered`, `.queued`, or a nonqueueable error through `OTFWatchDeliveryOutcome`. |

Legacy revision merges upsert included tasks and outcomes while preserving
unmentioned local documents. They must not be treated as destructive full
snapshots.

Incremental synchronization uses `OTFWatchSyncPayload`. Payloads can include
task data, outcome data, typed `OTFWatchSyncDeletion` requests, and legacy
deleted document IDs. Receiver replies include apply counters for tasks,
outcomes, deletions, skipped revisions, and skipped deletions.

Typed task deletions validate that the target document is a task. Typed outcome
deletions validate logical outcome identity before deleting, using either the
provided `taskUUID` and `occurrenceIndex` or the canonical document ID form
`<taskUUID>_<occurrenceIndex>`. Non-deletion skips do not count as delivery
failure; skipped typed deletions are treated as sender-side failures because the
receiver could not validate a requested delete safely.

`backfillTaskDateMetadataIfNeeded()` fills missing task `startDate` and
`endDate` metadata from stored CareKit schedules so older documents remain
queryable by task date interval.

See [Synchronization](docs/synchronization.md) for the routing, payload,
conflict, deletion, delivery, and limitation matrices.

### OTFWatchConnectivityPeer

`OTFWatchConnectivityPeer` bridges WatchConnectivity messages for legacy
revision requests, legacy revision pushes, and incremental revision pushes. It
uses immediate `sendMessage` delivery when possible and queues valid sessions
that are not currently reachable with `transferUserInfo`. A queued
`OTFWatchDeliveryOutcome` means the message was handed to WatchConnectivity; it
is not a receiver-apply acknowledgement.

## CareKit Integration

The CareKit store APIs documented here currently require the
`CloudantCareHealth` subspec. `CloudantCare` sets the `CARE` build flag and
pulls CareKit dependencies, but the `OCKStoreProtocol` extensions are gated by
both `CARE` and `HEALTH`.

`CloudantCareHealth` compiles store support for:

* `OCKTask`
* `OCKOutcome`
* `OCKPatient`
* `OCKContact`
* `OCKCarePlan`

CareKit adds, updates, and deletes map encoded CareKit models into CDT
documents, then notify the matching CareKit delegate. Fetches preserve CareKit
query semantics with local post-processing when datastore ordering alone is not
enough. Patients, contacts, care plans, tasks, and outcomes all support local
sorting and pagination paths.

Task date queries use schedule overlap against stored `startDate` and `endDate`
metadata. Outcomes are normalized by logical event identity, using
`taskUUID` plus occurrence index. The canonical outcome document ID is
`<taskUUID>_<occurrenceIndex>`. `pruneStaleOutcomeDocuments()` migrates the
newest duplicate logical outcome to the canonical ID and removes stale duplicate
documents.

See [CareKit Store Contract](docs/carekit-store-contract.md) for CRUD behavior,
delegate notifications, outcome identity, deletion safety, and failure mapping.

## HealthKit Integration

The `CloudantHealth` and `CloudantCareHealth` subspecs compile HealthKit sample
and parsing types. `OTFCloudantSample` stores HealthKit sample identity, dates,
values, type information, source metadata, and selected metadata in compact
documents.

`OTFHealthKitSynchronizer` currently requires `CloudantCareHealth`. It supports
three directions:

| Direction | Meaning |
| --- | --- |
| `.fromCloudantToHK` | Converts local Cloudant samples to `HKSample` values and saves samples that are not already present in HealthKit. |
| `.fromHKToCloudant` | Converts fetched HealthKit samples to `OTFCloudantSample` values and adds samples that are not already present in Cloudant. |
| `.biDirection` | Runs Cloudant-to-HealthKit first, then HealthKit-to-Cloudant using the fetched snapshots from both stores. |

Sample identity prefers `HKMetadataKeyExternalUUID` when present and falls back
to the HealthKit UUID. When a Cloudant sample is converted back to HealthKit,
the Cloudant ID is written as `HKMetadataKeyExternalUUID` so duplicate checks can
match across sync cycles.

Anchored realtime updates add and update local Cloudant samples from HealthKit
changes. Deleted HealthKit samples are resolved back to matching Cloudant
documents and deleted locally when a match is found. The two `syncWithHealthKit`
methods exit early when Health data is unavailable. `observeOnHKStoreRealTimeUpdates()`
does not perform its own availability guard, so call it only after the app has
confirmed HealthKit is available for the current device and user flow.

This library does not request HealthKit authorization. The app must configure
HealthKit capabilities, usage descriptions, and read/write authorization for the
sample types it fetches, saves, or observes.

See [HealthKit Synchronization](docs/healthkit-synchronization.md) for supported
sample type groups, identity rules, anchored update behavior, and authorization
constraints.

## Errors

Public store and query APIs return `OTFCloudantError` for framework-level
failures:

| Error | Typical cause |
| --- | --- |
| `.fetchFailed` | Datastore fetch, decode, or sorted-query validation failure. |
| `.addFailed` | One or more documents could not be created. |
| `.updateFailed` | One or more documents could not be updated. |
| `.deleteFailed` | One or more documents could not be deleted. |
| `.remoteSynchronizationFailed` | Remote or watch synchronization could not complete. |
| `.invalidValue` | A caller supplied an invalid value, such as a zero `$mod` divisor. |
| `.timedOut` | An asynchronous remote operation exceeded its timeout. |

CareKit domain methods map these failures to the corresponding `OCKStoreError`
when satisfying CareKit store protocols.

## Focused Documentation

The README is the entry point. Use the focused docs for detailed contracts and
edge-case matrices:

* [Synchronization](docs/synchronization.md)
* [CareKit Store Contract](docs/carekit-store-contract.md)
* [Querying and Indexes](docs/querying-and-indexes.md)
* [HealthKit Synchronization](docs/healthkit-synchronization.md)
* [Testing](docs/testing.md)

## Testing and Coverage

Run the main XCTest target from the CocoaPods workspace:

```sh
xcodebuild test -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

To update the checked-in coverage badge, run the coverage flow and commit the
regenerated `badges/coverage.svg` file:

```sh
xcodebuild test -workspace OTFCloudantStore.xcworkspace -scheme OTFCloudantStoreTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -enableCodeCoverage YES -resultBundlePath /tmp/OTFCloudantStore-coverage.xcresult
xcrun xccov view --report --only-targets /tmp/OTFCloudantStore-coverage.xcresult
ruby Scripts/generate_coverage_badge.rb /tmp/OTFCloudantStore-coverage.xcresult
```

For test-suite mapping and docs-only verification commands, see
[Testing](docs/testing.md).

## License

This project is made available under the terms of a modified BSD license. See
the [LICENSE](LICENSE.md) file.
