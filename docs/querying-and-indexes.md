# Querying and Indexes

This document describes Cloudant-style query construction, CareKit query
adapters, local post-processing, and required client-side index behavior in
`OTFCloudantStore`.

## Generic Query Builder

`OTFCloudantQuery` builds selectors for datastore `find` calls. Constructors
seed the selector with `entityType`, and HealthKit constructors also seed sample
type fields.

Supported selector helpers include:

| API | Selector |
| --- | --- |
| `where(_:isEqualTo:)` | Field equality |
| `where(_:isLessThan:)` | `$lt` |
| `where(_:isLessThanOrEquaTo:)` | `$lte` |
| `where(_:isGreeterThan:)` | `$gt` |
| `where(_:isGreeterThanOrEqualTo:)` | `$gte` |
| `where(_:notEqualTo:)` | `$ne` |
| `where(field:in:)` | `$in` |
| `where(field:notIn:)` | `$nin` |
| `where(field:exists:)` | `$exists` |
| `where(field:mode:equal:)` | `$mod`; divisor zero throws `invalidValue` |
| `where(field:hasSize:)` | `$size` |
| `where(firstCondition:or:)` | `$or` |
| `where(firstCondition:and:)` | `$and` |
| `where(query:)` | Merges simple, combined, or complex query components |

`limit(limit:)`, `skip(skip:)`, `ordered(by:ascending:)`,
`sort(ascendingBy:)`, and `sort(descendingBy:)` configure pagination and sort
descriptors for generic Cloudant queries.

## Sorted Query Validation

Generic `get`, `getSamples`, and `getCloudantSamples` validate sort descriptors
before calling the datastore.

| Condition | Result |
| --- | --- |
| All sort descriptors use the same direction and every sorted field is indexed. | The datastore query runs. No matches return an empty success. |
| Sort descriptors mix ascending and descending directions. | The completion receives `.fetchFailed` with a same-order validation reason. |
| Any sorted field is not covered by installed indexes. | The completion receives `.fetchFailed`; it does not return an empty success. |

The missing-index error reason still includes the legacy phrase
`the result will be empty`, but the observable behavior is a failed completion.

## CareKit Query Adapters

CareKit adapters map `OCK*Query` values into `OTFQueryProtocol` selectors. Empty
arrays are omitted, single values become direct equality, and multiple values use
`$in`.

| CareKit query | Selector fields | Sort mapping | Local post-processing |
| --- | --- | --- | --- |
| `OCKTaskQuery` | `uuid`, `groupIdentifier`, `carePlanUUID`, `carePlanRemoteID`, `carePlanID`, `remoteID`, `id`, `tag`; `dateInterval` maps to schedule overlap on `startDate` and `endDate`. | `effectiveDate`, `groupIdentifier`, `title`. | If sort descriptors are present, fetches clear datastore sort, limit, and offset, then stable-sort and paginate locally. |
| `OCKOutcomeQuery` | `uuid`, `taskID`, `taskUUID`, `taskRemoteID`, `groupIdentifier`, `remoteID`, `id`, `tag`. | `.date` maps to `createdDate`. | Fetches normalize duplicate logical outcomes. Sort, limit, and offset are applied locally; non-task-scoped date intervals filter by `createdDate`. |
| `OCKPatientQuery` | `uuid`, `remoteID`, `id`, `tag`, `groupIdentifier`. | No datastore sort mapping. | If sort descriptors are present, fetches clear datastore limit and offset, then sort by family name, given name, effective date, or group identifier and paginate locally. |
| `OCKContactQuery` | `uuid`, `carePlanUUID`, `carePlanRemoteID`, `carePlanID`, `remoteID`, `id`, `tag`, `groupIdentifier`. | No datastore sort mapping. | If sort descriptors are present, fetches clear datastore limit and offset, then case-insensitive sort by family name or given name, or sort by effective date, and paginate locally. |
| `OCKCarePlanQuery` | `uuid`, `groupIdentifier`, `patientUUID`, `patientRemoteId`, `patientID`, `remoteID`, `id`, `tag`. | `title`, `effectiveDate`. | If sort descriptors are present, fetches clear datastore sort, limit, and offset, then sort and paginate locally. |

Task date interval support is inclusive schedule overlap:

```text
startDate <= query.end
AND (endDate does not exist OR endDate >= query.start)
```

Outcome date intervals are intentionally different. For task-scoped outcome
queries, the store does not filter by `createdDate` because an outcome can be
created after the event date it completes. For non-task-scoped outcome queries,
the local filter keeps outcomes whose `createdDate` is inside the requested
interval.

## Required Client-Side Indexes

`OTFCloudantStore` bootstraps required datastore indexes during initialization.
These index definitions support entity filtering, common CareKit selectors, and
generic sorted queries:

| Fields |
| --- |
| `id`, `effectiveDate` |
| `entityType` |
| `entityType`, `effectiveDate` |
| `entityType`, `id` |
| `entityType`, `updatedDate` |
| `entityType`, `createdDate` |
| `entityType`, `startDate` |
| `entityType`, `endDate` |
| `entityType`, `startDate`, `endDate` |
| `entityType`, `taskUUID` |
| `entityType`, `uuid` |
| `entityType`, `groupIdentifier` |
| `entityType`, `carePlanUUID` |
| `entityType`, `remoteID` |
| `entityType`, `taskUUID`, `createdDate` |
| `entityType`, `uuid`, `updatedDate` |

The bootstrap normalizes definitions by ignoring `_id` and `_rev` in signatures.
It also prunes duplicate installed indexes that share the same normalized
signature, preferring names with the `otf_index_json_` prefix.

## Index APIs

`ensureClientSideIndexes()` is called by the public store initializer and by the
internal initializer unless index bootstrap is explicitly skipped for tests. It:

1. Prunes duplicate installed indexes.
2. Creates each missing required index with a stable name.
3. Logs any definitions still missing after creation.
4. Returns the remaining missing field sets.

`validateClientSideIndexes()` does not mutate the datastore. It returns the
required field sets that are currently missing and logs when the result is not
empty.

Use `validateClientSideIndexes()` as a runtime or migration diagnostic. Use
`ensureClientSideIndexes()` when a store may have been created before the
current index set was introduced.

## Local Post-Processing Rules

Local post-processing exists to keep CareKit results stable when normalization,
multi-field sorting, or pagination must happen after decoding.

| Domain | Local operation order |
| --- | --- |
| Tasks | Datastore selector fetch, local stable sort when requested, then local pagination when locally sorted. |
| Outcomes | Datastore selector fetch, local task/date filtering where needed, duplicate normalization by logical identity, local stable sort, then local pagination. |
| Patients | Datastore selector fetch, local stable sort when requested, then local pagination when locally sorted. |
| Contacts | Datastore selector fetch, local stable sort when requested, then local pagination when locally sorted. |
| Care plans | Datastore selector fetch, local stable sort when requested, then local pagination when locally sorted. |

When no local sort is requested for tasks, patients, contacts, or care plans,
their adapters allow datastore limit and offset to apply directly. Outcomes
still normalize duplicates before returning results.

## Verification

The behavior above is covered primarily by:

- `OTFCloudantStoreTests/CareKitStoreContractTests.swift`
- `OTFCloudantStoreTests/InternalTestSeamTests.swift`
- `OTFCloudantStoreTests/SynchronizationAlgorithmTests.swift`
- `OTFCloudantStoreTests/WatchDeliveryOutcomeTests.swift`

Run targeted XCTest only when Swift behavior changes. For docs-only edits, use
Markdown sanity checks for trailing whitespace and unfinished marker text.
