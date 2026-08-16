# CareKit Store Contract

This document describes the CareKit-facing behavior of `OTFCloudantStore` in
CareHealth builds. It focuses on the contract implemented by the task, outcome,
patient, contact, and care plan extensions, and should be read with
`docs/synchronization.md` for watch payload and deletion delivery semantics.

## Scope

`OTFCloudantStore` implements the CareKit store APIs by encoding CareKit models
as `CDTDocumentRevision` documents. Each document stores an `entityType` field
used by the query layer, and fetched or mutated models receive the current CDT
revision ID through `revId` in `userInfo`.

The supported CareKit domains are:

| Domain | Fetch | Add | Update | Delete |
| --- | --- | --- | --- | --- |
| Tasks | `fetchTasks` | `addTasks` | `updateTasks` | `deleteTasks` |
| Outcomes | `fetchOutcomes` | `addOutcomes` | `updateOutcomes` | `deleteOutcomes` |
| Patients | `fetchPatients` | `addPatients` | `updatePatients` | `deletePatients` |
| Contacts | `fetchContacts` | `addContacts` | `updateContacts` | `deleteContacts` |
| Care plans | `fetchCarePlans` | `addCarePlans` | `updateCarePlans` | `deleteCarePlans` |

## CRUD Behavior

Adds create new CDT documents from the encoded CareKit model. Duplicate document
IDs fail with `OCKStoreError.addFailed`.

Updates persist through the current CDT revision. If the caller does not provide
a `revId`, the store fetches the current revision by document ID before updating.
Missing documents or missing current revisions fail with `OCKStoreError.updateFailed`.

Deletes fetch the current document revision and delete that revision. Missing
documents fail with `OCKStoreError.deleteFailed`.

Task `addUpdateOrDeleteTasks(addOrUpdate:delete:)` first fetches existing tasks,
then splits the input into add, update, and delete batches by task ID. Outcomes
do not have an equivalent split API; `updateOutcomes` remains update-only and
fails for missing outcome documents.

Generic batch helpers process items one by one. When a mixed batch has both
successes and failures, callers should be prepared for the domain wrapper to
report the successful items and then map the failed items to a CareKit store
error. Prefer homogeneous batches when the caller needs all-or-nothing behavior.

## Delegate Notifications

Domain delegates are notified only after successful mutations. Failure paths do
not notify delegates.

| Mutation | Delegate callback |
| --- | --- |
| Add tasks | `taskStore(_:didAddTasks:)` |
| Update tasks | `taskStore(_:didUpdateTasks:)` |
| Delete tasks | `taskStore(_:didDeleteTasks:)` |
| Add outcomes | `outcomeStore(_:didAddOutcomes:)` |
| Update outcomes | `outcomeStore(_:didUpdateOutcomes:)` |
| Delete outcomes | `outcomeStore(_:didDeleteOutcomes:)` |
| Add patients | `patientStore(_:didAddPatients:)` |
| Update patients | `patientStore(_:didUpdatePatients:)` |
| Delete patients | `patientStore(_:didDeletePatients:)` |
| Add contacts | `contactStore(_:didAddContacts:)` |
| Update contacts | `contactStore(_:didUpdateContacts:)` |
| Delete contacts | `contactStore(_:didDeleteContacts:)` |
| Add care plans | `carePlanStore(_:didAddCarePlans:)` |
| Update care plans | `carePlanStore(_:didUpdateCarePlans:)` |
| Delete care plans | `carePlanStore(_:didDeleteCarePlans:)` |

Incremental watch apply also sends task and outcome delegate notifications for
applied creates, updates, and validated deletions. Skipped incoming revisions and
unsafe deletion requests do not notify delegates.

## Fetch Ordering and Pagination

CareKit fetches preserve CareKit query semantics by doing local post-processing
when datastore ordering alone is not sufficient.

| Domain | Local post-processing |
| --- | --- |
| Tasks | When sort descriptors are present, fetches ignore datastore sort, limit, and offset, then apply stable multi-sort and pagination locally. |
| Outcomes | Fetches normalize duplicate logical outcomes, apply any required date filtering, sort by requested date order, then paginate locally. |
| Patients | When sort descriptors are present, fetches ignore datastore limit and offset, then sort and paginate locally. |
| Contacts | When sort descriptors are present, fetches ignore datastore limit and offset, then sort and paginate locally. Name sorting is case-insensitive. |
| Care plans | When sort descriptors are present, fetches ignore datastore sort, limit, and offset, then sort and paginate locally. |

Local pagination is applied after local sorting and normalization. `offset` is
clamped at zero, and `limit` is clamped at zero when present. Ties preserve the
original fetched order unless a later descriptor breaks the tie.

## Task Date Intervals

Task date queries use schedule overlap, not exact start-date equality. An
`OCKTaskQuery(dateInterval:)` maps to:

```text
startDate <= query.end
AND (endDate does not exist OR endDate >= query.start)
```

`startDate` and `endDate` are stored as ISO-8601 task schedule metadata. Open
ended schedules omit `endDate` and match future intervals. The helper
`backfillTaskDateMetadataIfNeeded()` fills missing task date metadata from the
stored CareKit schedule so older backend-style task documents become queryable.

## Outcome Identity and Deletion

Outcome logical identity is the event occurrence, not the document revision:

```text
<taskUUID>|<occurrenceIndex>
```

New outcome documents are canonicalized to this document ID:

```text
<taskUUID>_<occurrenceIndex>
```

This canonical document ID is used for normal add, update, fetch, and delete
paths. Legacy documents with other IDs may still exist after older sync flows or
replication conflicts.

`fetchOutcomes` groups fetched outcomes by logical identity and emits only the
preferred winner for each occurrence. The winner is chosen by the newest version
date (`deletedDate`, then `updatedDate`, then `createdDate`, then
`effectiveDate`), with canonical document IDs preferred as a tie-breaker. If the
winner is soft-deleted, the logical outcome is hidden from fetch results.

`deleteOutcomes` expands each requested outcome to all local documents with the
same logical identity. This removes both canonical and legacy duplicate outcome
documents. If deletion hits a CDT conflict, the store attempts outcome conflict
resolution and retries before reporting failure.

`outcomeDeletionDocumentIDs(for:)` returns the document IDs the store would
delete for a logical outcome. `outcomeDeletionDocumentIDs(matchingDeletedDocumentIDs:)`
expands canonical legacy deletion IDs to matching duplicate documents.

`affectedDatesForDeletedOutcomeDocumentIDs(_:)` maps canonical outcome document
IDs back to task schedule event start dates. It returns sorted unique dates for
document IDs whose task and occurrence can be resolved locally.

`pruneStaleOutcomeDocuments()` is a local cleanup helper. It migrates the newest
non-deleted winner to its canonical document ID, removes older duplicates and
tombstone documents, and removes every document for a logical outcome when the
winning version is soft-deleted. The return value is the number of deleted or
migrated local documents.

## Deletion Safety

Outcome deletion safety is based on logical identity. A typed outcome deletion
from watch sync deletes only documents that decode as `OCKOutcome` and whose
`taskUUID` and `taskOccurrenceIndex` match the requested logical identity or
canonical document ID. Mismatched, malformed, or wrong-entity documents are
preserved and counted as skipped deletions by the incremental sync receiver.

Typed task deletions similarly delete only documents that are stored as
`OCKTask`. Unknown legacy deletion IDs are skipped without deleting unrelated
documents.

## Failure Behavior

Domain methods map `OTFCloudantError` to the corresponding `OCKStoreError`.

| Condition | Result |
| --- | --- |
| Duplicate add | `.addFailed` |
| Missing document update | `.updateFailed` |
| Missing document delete | `.deleteFailed` |
| Malformed fetched documents with no successful decoded items | `.fetchFailed` |
| Malformed fetched documents mixed with successfully decoded items | Successful decoded items are returned. |
| Failed mutation | No domain delegate notification is sent. |

Fetches return an empty success when no matching documents and no decode errors
are found. Fetches fail only when matching documents are present but cannot be
decoded and no valid item is returned.

## Verification

The behavior above is covered primarily by:

- `OTFCloudantStoreTests/CareKitStoreContractTests.swift`
- `OTFCloudantStoreTests/SynchronizationAlgorithmTests.swift`
- `OTFCloudantStoreTests/WatchDeliveryOutcomeTests.swift`

Run targeted XCTest only when Swift behavior changes. For docs-only edits, use
Markdown sanity checks for trailing whitespace and unfinished marker text.
