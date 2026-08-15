# Synchronization

This document describes the watch synchronization contract implemented by
`OTFCloudantStore`, `OTFWatchConnectivityPeer`, `OTFWatchSyncPayload`,
`OTFWatchSyncDeletion`, and `OTFWatchDeliveryOutcome`.

CareKit task and outcome merge behavior is compiled under the existing
`CARE && HEALTH` gate. In non-CareHealth builds, incremental apply returns an
empty result for CareKit entities.

## Routing

| Entry point | Remote action | Completion behavior |
| --- | --- | --- |
| `synchronize(target: .watchOS)` | Calls `remote.pullRevisions`, then merges each returned revision batch. | Completes once with the pull error, if any. Missing remote returns a remote synchronization error. |
| `synchronize(target: .mobile)` | Calls `remote.updatewatchOS()` only. | Completes immediately after the notification call. It does not push entity revisions. |
| `synchronize(target: .watchAppUpdate)` | Calls `remote.pushRevisions`, then `remote.updatewatchOS()` on success or queueable reachability failure. | Bridges `OTFWatchDeliveryOutcome` into `Error?`: delivered and queued are success, nonqueueable errors fail. |
| `synchronizeWatchAppUpdate` | Same route as `.watchAppUpdate`. | Returns `.delivered`, `.queued`, or a nonqueueable error. |
| `didRequestSynchronization` | Calls the `.mobile` push path only when `remote.automaticallySynchronizes == true`. | Logs automatic sync errors. |

`OTFWatchConnectivityPeer.reply(to:store:sendReply:)` handles three watch
message families:

| Message key | Receiver behavior |
| --- | --- |
| `OCKPeerRevisionRequest` | Builds and replies with a legacy full snapshot. |
| `OCKPeerRevisionPush` | Requests revisions from the peer, merges them locally, and replies with an empty success message or `OCKPeerRevisionErrorKey`. |
| `OCKPeerIncrementalRevisionPush` | Decodes `OTFWatchSyncPayload`, applies it locally, and replies with apply counters or `OCKPeerRevisionErrorKey`. |

## Payloads

### Legacy Snapshot

Legacy revision replies use a dictionary with these keys:

| Key | Value |
| --- | --- |
| `tasks` | JSON-encoded `OCKTask` values as `[Data]`. |
| `outcomes` | JSON-encoded `OCKOutcome` values as `[Data]`. |
| `fullSnapshot` | A marker containing `Data("true".utf8)`. |

`computeRevision(store:completion:)` returns a legacy snapshot only when task
fetching succeeds and at least one task is available. If no snapshot can be
built, the peer replies with `OCKPeerRevisionErrorKey`.

`mergeRevision(_:)` currently uses only the `tasks` and `outcomes` arrays. The
`fullSnapshot` marker does not trigger deletion. Legacy merges upsert included
task and outcome revisions and preserve unmentioned local documents, including
stale task/outcome documents and documents for other entity types.

### Incremental Payload

`OTFWatchSyncPayload` serializes to a watch message dictionary with this shape:

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Defaults to `2`. Payloads with no typed deletions and at least one legacy `deletedDocumentIDs` entry are marked as schema version `1` for compatibility. |
| `tasks` | JSON-encoded `OCKTask` values. |
| `outcomes` | JSON-encoded `OCKOutcome` values. |
| `deletions` | Typed deletion dictionaries built from `OTFWatchSyncDeletion`. |
| `deletedDocumentIDs` | Legacy deletion document IDs. Present only when nonempty. |

An empty payload is not decoded from a received message. Malformed typed
deletion dictionaries also reject the whole payload.

Typed deletion dictionaries contain:

| Field | Meaning |
| --- | --- |
| `documentID` | The requested local document ID. |
| `entityType` | `OCKTask` or `OCKOutcome`. |
| `taskUUID` | Optional outcome logical identity. |
| `occurrenceIndex` | Optional outcome logical identity. |

For outcome deletions, `taskUUID` and `occurrenceIndex` must either both be
present or both be absent. If both are absent, `documentID` must be a canonical
outcome ID in the form `<taskUUID>_<occurrenceIndex>`.

`OTFWatchAuthContext` can add `authSessionID` and
`authCommandGeneration` to outbound messages through
`outboundMessageContextProvider`. These fields are transport metadata; they do
not implement backend conflict resolution or authorization inside this library.

## Conflict

Incoming task and outcome revisions are compared by `updatedDate`, falling back
to `createdDate` when `updatedDate` is unavailable.

| Local state | Incoming state | Result |
| --- | --- | --- |
| No local document for the incoming document ID. | Decodes to a supported entity. | Create the document and count it as applied. |
| Local document has the same entity type, decodes successfully, and has an older comparable date. | Incoming comparable date is newer. | Update the existing revision body and count it as applied. |
| Local document has the same entity type and an equal or newer comparable date. | Incoming comparable date is older or equal. | Skip the incoming revision. |
| Local document has a different `entityType`. | Any incoming task or outcome for the same document ID. | Skip the incoming revision. |
| Local document cannot be decoded as the expected entity type. | Any incoming task or outcome for the same document ID. | Skip the incoming revision. |
| Local or incoming comparable date is unavailable for an existing document. | Any incoming task or outcome for the same document ID. | Skip the incoming revision. |

Legacy snapshot merges catch malformed task and outcome items individually, log
the decode failure, and continue applying valid items. Incremental apply throws
for malformed task or outcome data; the watch peer catches that error and
replies with `OCKPeerRevisionErrorKey`.

## Deletion

Deletions are explicit. Neither legacy snapshots nor incremental payloads delete
documents simply because they are absent from a task or outcome array.

| Request | Local match | Result |
| --- | --- | --- |
| Typed task deletion. | Existing document with `entityType == OCKTask` that decodes as `OCKTask`. | Delete that document and count one deletion. |
| Typed task deletion. | No local document. | Count a skip, but not a skipped deletion failure. |
| Typed task deletion. | Existing non-task or malformed task document. | Preserve it, count a skip, and increment `skippedDeletions`. |
| Typed outcome deletion with logical identity or canonical outcome ID. | Outcome documents whose `taskUUID` and `taskOccurrenceIndex` match the requested logical identity. | Delete all matching logical outcome documents, including legacy duplicate document IDs. |
| Typed outcome deletion. | The requested local document exists but does not validate as the requested logical outcome. | Preserve it, count a skip, and increment `skippedDeletions`. |
| Legacy `deletedDocumentIDs` entry for a canonical outcome ID. | Matching logical outcome documents exist. | Expand to all matching logical duplicates and delete them. |
| Legacy `deletedDocumentIDs` entry for an existing task document. | Existing document has `entityType == OCKTask`. | Delete that task document. |
| Legacy `deletedDocumentIDs` entry for a missing document. | No local document. | Count a skip without incrementing `skippedDeletions`. |
| Legacy `deletedDocumentIDs` entry for an existing non-task document that is not a recognized outcome deletion. | Existing document is not safe to delete. | Preserve it, count a skip, and increment `skippedDeletions`. |

Outcome deletion safety is based on logical identity, not only document ID.
The logical key is `<taskUUID>|<occurrenceIndex>`, and the canonical outcome
document ID is `<taskUUID>_<occurrenceIndex>`.

## Delivery

Incremental delivery uses `pushIncrementalPayloadWithDeliveryOutcome`.

| Condition | Outcome |
| --- | --- |
| Payload is empty. | Completes with `.delivered` without sending a message. |
| WatchConnectivity session is invalid. | Fails with a remote synchronization error. |
| Session is valid but not reachable. | Enqueues the message with `transferUserInfo` and completes with `.queued`. |
| `sendMessage` succeeds and the receiver reply is valid. | Completes with `.delivered`. |
| `sendMessage` fails with `deliveryFailed`, `notReachable`, or `transferTimedOut`. | Enqueues with `transferUserInfo` and completes with `.queued`. |
| `sendMessage` fails with another error. | Fails with that error. |
| Receiver replies with `OCKPeerRevisionErrorKey` or legacy `error`. | Fails with that receiver error. |
| Receiver reply contains malformed apply counters. | Fails with an invalid incremental sync reply error. |
| Receiver reply contains `skippedDeletions > 0`. | Fails with a skipped deletion error. |
| Receiver reply contains `skipped > 0` and `skippedDeletions == 0`. | Still completes with `.delivered`. |

The incremental receiver reply is stored under `revisionPushResult`:

| Counter | Meaning |
| --- | --- |
| `tasks` | Number of task revisions created or updated. |
| `outcomes` | Number of outcome revisions created or updated. |
| `deletions` | Number of documents deleted. |
| `skipped` | Number of non-applied revisions or deletion requests. |
| `skippedDeletions` | Number of deletion requests that could not be validated safely. Any nonzero value is a sender-side delivery failure. |

`.queued` means the message was handed to WatchConnectivity using
`transferUserInfo`. It is not confirmation that the receiver has applied the
payload.

`updatewatchOS()` sends `databaseSynced`, and `dataUpdateOnWatch()` sends
`watchAppUpdate`. These notification messages also fall back to
`transferUserInfo` when the session is valid but unreachable or a queueable
transport error occurs.

## Limitations

- Backend conflict hooks are not implemented in this library. `findNextConflict`,
  `changedQuery`, `findFirstConflict`, `resolveConflicts`, and
  `chooseConflictResolution` are empty or no-op methods.
- Active backend replication conflict handling belongs in the application layer.
- Legacy snapshots contain only tasks and outcomes, and the current receiver
  ignores the `fullSnapshot` marker for deletion decisions.
- Timestamp conflict resolution depends on `updatedDate` or `createdDate`.
  Equal timestamps are skipped to preserve the local document.
- Queued WatchConnectivity delivery is best-effort transport queuing, not a
  receiver apply acknowledgement.
- `OTFWatchAuthContext` only attaches session metadata to outbound watch
  messages.

## Verification

The synchronization contract above is covered by:

- `OTFCloudantStoreTests/SynchronizationAlgorithmTests.swift`
- `OTFCloudantStoreTests/WatchDeliveryOutcomeTests.swift`

For docs-only changes, run Markdown sanity checks for trailing whitespace and
unfinished marker text.

```sh
rg -n '[[:blank:]]$' docs/synchronization.md
```

When Swift synchronization behavior changes, run the relevant XCTest classes
instead of relying on documentation checks alone.
