# HealthKit Synchronization

This document describes the HealthKit-facing synchronization behavior of
`OTFHealthKitSynchronizer`, `OTFCloudantSample`, and `OTFParsingHelper`.

The synchronizer is compiled only for CareHealth builds under `CARE && HEALTH`.
`OTFCloudantSample` and HealthKit parsing helpers are compiled under `HEALTH`.
Read this with [Synchronization](synchronization.md),
[CareKit Store Contract](carekit-store-contract.md), and
[Querying and Indexes](querying-and-indexes.md) for watch delivery, CareKit
document identity, and client-side index behavior.

## Entry Points and Directions

`OTFHealthKitSynchronizer` fetches HealthKit samples and local
`OTFCloudantSample` documents before applying the requested direction.

| API | Scope |
| --- | --- |
| `syncWithHealthKit(direction:)` | Fetches every sample type in the synchronizer's default `allTypes` set, fetches all Cloudant samples, then syncs according to the direction. |
| `syncWithHealthKit(direction:type:completion:)` | Fetches one `HKSampleType`, fetches all Cloudant samples, then syncs according to the direction and calls `completion` after work is scheduled. |
| `observeOnHKStoreRealTimeUpdates()` | Registers anchored observers for each sample type in `allTypes`. Initial sample batches add Cloudant samples; update batches update Cloudant samples. Deleted HealthKit samples are resolved back to matching Cloudant samples and deleted locally. |

`OTFSyncDirection` has these meanings:

| Direction | Behavior |
| --- | --- |
| `.fromCloudantToHK` | Converts local Cloudant samples to `HKSample` values and saves only samples that are not already present in HealthKit. |
| `.fromHKToCloudant` | Converts fetched HealthKit samples to `OTFCloudantSample` values and adds only samples that are not already present in Cloudant. |
| `.biDirection` | Runs Cloudant-to-HealthKit first, then HealthKit-to-Cloudant, using the fetched snapshots from both stores. |

## Cloudant Sample Mapping

`OTFCloudantSample` is the compact document used by the synchronizer. It stores
the HealthKit sample identity, dates, value, type information, and the minimum
metadata needed for duplicate detection and round-tripping.

| Cloudant field | HealthKit source |
| --- | --- |
| `id` | `HKMetadataKeyExternalUUID` when present; otherwise `HKSample.uuid.uuidString`. |
| `uuid` | The HealthKit sample UUID. |
| `revId` | The HealthKit `sourceRevision.version` when created from HealthKit; CDT revision IDs are attached by store fetches. |
| `patientID` | The initializer's `patientId`. The public synchronizer currently writes HealthKit-originated samples with an empty patient ID. |
| `startDate`, `endDate` | `HKSample.startDate` and `HKSample.endDate`. |
| `syncIdentifier`, `syncVersion` | `HKMetadataKeySyncIdentifier` and `HKMetadataKeySyncVersion`. |
| `typeIdentifier` | `sample.sampleType.identifier`. |
| `type` | `.quantity`, `.category`, or `.correlation`. |
| `unit`, `value` | Preferred unit and numeric value for quantity samples; category raw value for category samples. |
| `samples` | Nested `OTFCloudantSample` values for correlation objects. |
| `metadata` | Boolean category metadata only. Other metadata is not preserved except for external UUID and sync metadata fields above. |

When converting back to HealthKit, `toHKSample()` writes
`HKMetadataKeyExternalUUID`, `HKMetadataKeySyncIdentifier`, and
`HKMetadataKeySyncVersion` into the returned sample metadata. Category samples
also merge preserved boolean metadata.

## Identity and Duplicate Prevention

Identity is based on the external UUID when one exists.

| HealthKit sample state | Cloudant identity |
| --- | --- |
| Sample metadata includes `HKMetadataKeyExternalUUID`. | `OTFCloudantSample.id` equals that external UUID. |
| Sample metadata has no external UUID. | `OTFCloudantSample.id` equals the HealthKit UUID string. |
| Cloudant sample converted back to HealthKit. | The Cloudant `id` is written as `HKMetadataKeyExternalUUID`. |

`OTFCloudantSample.isEqual(to:)` uses the same rule. If the compared HealthKit
sample has an external UUID, it compares that value to the Cloudant `id`;
otherwise it compares the HealthKit UUID string.

Duplicate prevention uses this identity in both directions:

| Direction | Duplicate check |
| --- | --- |
| Cloudant to HealthKit | `storSample(sample:cloudantSample:)` scans fetched HealthKit samples and saves only when no equal sample exists. |
| HealthKit to Cloudant | `syncHealthKitSamplesToCloudant()` scans fetched Cloudant samples and adds only when no equal sample exists. |

## Supported Sample Type Groups

The compact `OTFCloudantSample` round-trips these HealthKit sample groups:

| Group | Notes |
| --- | --- |
| Quantity samples | Stores preferred unit strings and numeric values. `OTFParsingHelper.processUnitString(_:)` must recognize the unit before the Cloudant sample can be converted back to `HKQuantitySample`. |
| Category samples | Stores the raw category value and preserves supported boolean metadata. |
| Correlation samples | Stores nested compact Cloudant samples and recreates `HKCorrelation` objects from nested samples that can be converted back to HealthKit. |

`OTFParsingHelper.getSampleType(for:)` also resolves identifiers for broader
HealthKit wrapper support:

| Group | Examples |
| --- | --- |
| Quantity, category, and correlation types | Step count, sleep analysis, blood pressure. |
| Workouts | `HKObjectType.workoutType()` and workout event/configuration wrappers. |
| Audiograms | `HKObjectType.audiogramSampleType()` and sensitivity point wrappers. |
| Documents | CDA document type and CDA document sample wrappers. |
| Clinical records | Allergy, condition, immunization, lab result, medication, procedure, vital sign, and coverage records where available. |
| Heartbeat series | `HKSeriesType.heartbeat()` parsing and heartbeat series wrappers. |

The synchronizer's default `allTypes` set includes many quantity, category,
correlation, workout, audiogram, CDA document, clinical record, and ECG sample
types, with additional symptom and mobility types added behind iOS availability
checks. Membership in `allTypes` does not mean that the synchronizer can safely
round-trip every listed family. Its persistence path converts fetched and
anchored samples directly through `OTFCloudantSample`, whose supported compact
sample groups are quantity, category, and correlation. The synchronizer does not
route workouts, audiograms, documents, clinical records, heartbeat series, or
ECG samples through their dedicated `OTFCloudantHK*` wrappers. Those wrappers and
parser types are separate conversion APIs, not evidence of synchronizer support
for those sample families.

## Anchored Updates

`observeOnHKStoreRealTimeUpdates()` uses anchored object queries through the
HealthKit client seam.

| Anchored result | Cloudant behavior |
| --- | --- |
| Initial samples | Convert samples to `OTFCloudantSample` and call `addSamples`. |
| Updated samples | Convert samples to `OTFCloudantSample` and call `updateSamples`. |
| Deleted samples | Fetch matching Cloudant samples by sample type group and deleted HealthKit UUID, then call `deleteSamples` for the fetched documents. |

Deleted sample lookup uses `collection(healthKitSampleType:)` with a `uuid`
selector. HealthKit correlation types map to `.correlation`, category types map
to `.category`, and other deleted sample types map to `.quantity` for this
lookup. If the lookup fails, no Cloudant delete is attempted.

Anchored updates are local Cloudant mutations. They do not send watch payloads
directly; watch delivery remains covered by
[Synchronization](synchronization.md).

## Availability and Authorization

Both `syncWithHealthKit` methods exit before fetching or writing when
`HKHealthStore.isHealthDataAvailable()` is false. The typed
`syncWithHealthKit(direction:type:completion:)` overload returns immediately in
that case and does not call its completion closure.

`observeOnHKStoreRealTimeUpdates()` registers realtime observers without its own
Health data availability guard. Call it only after the app has confirmed
HealthKit is available for the current device and user flow.

This library does not request HealthKit authorization. The app must configure
the HealthKit capability, usage descriptions, and read/write authorization for
the sample types it asks the synchronizer to fetch, save, or observe. Fetch
errors are logged; failed HealthKit fetches do not produce Cloudant writes for
that sample type. If the Cloudant sample fetch fails, HealthKit-to-Cloudant sync
continues with an empty local Cloudant snapshot, so fetched HealthKit samples may
be added.

HealthKit save failures are logged by the synchronizer and are not retried here.
Application code should handle authorization, user consent, and retry policy
outside this layer.

## Verification

The behavior above is covered primarily by:

- `OTFCloudantStoreTests/HealthKitConversionSynchronizerTests.swift`
- `OTFCloudantStoreTests/InternalTestSeamTests.swift`

Run targeted XCTest only when Swift behavior changes. For docs-only edits, use
Markdown sanity checks for trailing whitespace and unfinished marker text.
