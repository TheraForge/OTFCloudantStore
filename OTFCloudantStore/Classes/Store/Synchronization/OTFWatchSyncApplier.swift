/*
Copyright (c) 2024, Hippocrates Technologies Sagl. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of the copyright holder(s) nor the names of any contributor(s) may
be used to endorse or promote products derived from this software without specific
prior written permission. No license is granted to the trademarks of the copyright
holders even if such marks are included in this software.

4. Commercial redistribution in any form requires an explicit license agreement with the
copyright holder(s). Please contact support@hippocratestech.com for further information
regarding licensing.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.
 */

#if CARE && HEALTH

import Foundation
import OTFCareKitStore
import OTFCDTDatastore
import OTFUtilities

struct OTFWatchSyncApplier {
    private let store: OTFCloudantStore

    init(store: OTFCloudantStore) {
        self.store = store
    }

    func apply(payload: OTFWatchSyncPayload) throws -> OTFIncrementalSyncApplyResult {
        let taskResult: EntityApplyResult<OCKTask> = try applyIncrementalEntities(payload.tasks, entityType: OCKTask.self)
        let outcomeResult: EntityApplyResult<OCKOutcome> = try applyIncrementalEntities(
            payload.outcomes,
            entityType: OCKOutcome.self
        )
        let deletionResult = try applyIncrementalDeletions(payload.deletions)
        let legacyDeletionResult = try applyLegacyDeletions(payload.legacyDeletedDocumentIDs)

        notifyDelegates(
            taskResult: taskResult,
            outcomeResult: outcomeResult,
            deletionResults: [deletionResult, legacyDeletionResult]
        )

        return OTFIncrementalSyncApplyResult(
            tasks: taskResult.applied,
            outcomes: outcomeResult.applied,
            deletions: deletionResult.applied + legacyDeletionResult.applied,
            skipped: taskResult.skipped + outcomeResult.skipped + deletionResult.skipped + legacyDeletionResult.skipped,
            skippedDeletions: deletionResult.skippedDeletions + legacyDeletionResult.skippedDeletions
        )
    }

    func mergeTaskRevisions(_ taskData: [Data]) -> [String] {
        taskData.compactMap { item in
            do {
                let task = try JSONDecoder().decode(OCKTask.self, from: item)
                let revision = CDTDocumentRevision.revision(fromEntity: task)
                guard let docId = revision.docId else { return nil }
                return try resolveConflictAndStore(
                    docId: docId,
                    revision: revision,
                    entityType: OCKTask.self
                ).applied ? docId : nil
            } catch let error {
                OTFLogger.logger().error("Failed to merge task revision: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }

    func mergeOutcomeRevisions(_ outcomeData: [Data]) -> [String] {
        outcomeData.compactMap { item in
            do {
                let outcome = try JSONDecoder().decode(OCKOutcome.self, from: item)
                let revision = CDTDocumentRevision.revision(fromEntity: outcome)
                guard let docId = revision.docId else { return nil }
                return try resolveConflictAndStore(
                    docId: docId,
                    revision: revision,
                    entityType: OCKOutcome.self
                ).applied ? docId : nil
            } catch let error {
                OTFLogger.logger().error("Failed to merge outcome revision: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }

    private struct LegacyDeletionValidation {
        let documentIDsToDelete: Set<String>
        let recognizedRequestIDs: Set<String>
        let unresolvedRequestIDs: Set<String>
    }

    private enum RevisionStoreResult {
        case created
        case updated
        case skipped

        var applied: Bool {
            switch self {
            case .created, .updated:
                return true
            case .skipped:
                return false
            }
        }
    }

    private struct EntityApplyResult<T> {
        let applied: Int
        let skipped: Int
        let added: [T]
        let updated: [T]
    }

    private struct DeletionAggregateResult {
        let applied: Int
        let skipped: Int
        let skippedDeletions: Int
        let deletedTasks: [OCKTask]
        let deletedOutcomes: [OCKOutcome]
    }

    private struct DeletionApplyResult {
        let deletedCount: Int
        let unresolvedRequestCount: Int
        let deletedTasks: [OCKTask]
        let deletedOutcomes: [OCKOutcome]

        init(
            deletedCount: Int,
            unresolvedRequestCount: Int,
            deletedTasks: [OCKTask] = [],
            deletedOutcomes: [OCKOutcome] = []
        ) {
            self.deletedCount = deletedCount
            self.unresolvedRequestCount = unresolvedRequestCount
            self.deletedTasks = deletedTasks
            self.deletedOutcomes = deletedOutcomes
        }
    }

    private func applyIncrementalEntities<T>(
        _ entityData: [Data],
        entityType: T.Type
    ) throws -> EntityApplyResult<T> where T: Codable & Identifiable & OTFCloudantRevision, T.ID == String {
        var applied = 0
        var skipped = 0
        var added = [T]()
        var updated = [T]()

        for data in entityData {
            let entity = try JSONDecoder().decode(entityType, from: data)
            let revision = CDTDocumentRevision.revision(fromEntity: entity)
            guard let docId = revision.docId else {
                skipped += 1
                continue
            }
            switch try resolveConflictAndStore(docId: docId, revision: revision, entityType: entityType) {
            case .created:
                applied += 1
                added.append(entity)
            case .updated:
                applied += 1
                updated.append(entity)
            case .skipped:
                skipped += 1
            }
        }

        return EntityApplyResult(applied: applied, skipped: skipped, added: added, updated: updated)
    }

    private func applyIncrementalDeletions(
        _ deletions: [OTFWatchSyncDeletion]
    ) throws -> DeletionAggregateResult {
        var applied = 0
        var skipped = 0
        var skippedDeletions = 0
        var deletedTasks = [OCKTask]()
        var deletedOutcomes = [OCKOutcome]()

        for deletion in deletions {
            let deleteResult = try deleteValidatedDocuments(for: deletion)
            applied += deleteResult.deletedCount
            deletedTasks.append(contentsOf: deleteResult.deletedTasks)
            deletedOutcomes.append(contentsOf: deleteResult.deletedOutcomes)
            if deleteResult.deletedCount == 0 || deleteResult.unresolvedRequestCount > 0 {
                skipped += 1
            }
            skippedDeletions += deleteResult.unresolvedRequestCount
        }

        return DeletionAggregateResult(
            applied: applied,
            skipped: skipped,
            skippedDeletions: skippedDeletions,
            deletedTasks: deletedTasks,
            deletedOutcomes: deletedOutcomes
        )
    }

    private func applyLegacyDeletions(
        _ documentIDs: [String]
    ) throws -> DeletionAggregateResult {
        let validation = validatedLegacyDeletions(documentIDs)
        let unrecognizedCount = documentIDs
            .filter { !validation.recognizedRequestIDs.contains($0) }
            .count

        var applied = 0
        var skipped = unrecognizedCount
        var deletedTasks = [OCKTask]()
        var deletedOutcomes = [OCKOutcome]()
        for documentID in validation.documentIDsToDelete.sorted() {
            let snapshot = deletionSnapshot(for: documentID)
            let deletedCount = try deleteDocumentIfPresent(documentID)
            if deletedCount > 0 {
                applied += deletedCount
                if let task = snapshot.task {
                    deletedTasks.append(task)
                }
                if let outcome = snapshot.outcome {
                    deletedOutcomes.append(outcome)
                }
            } else {
                skipped += 1
            }
        }

        return DeletionAggregateResult(
            applied: applied,
            skipped: skipped,
            skippedDeletions: validation.unresolvedRequestIDs.count,
            deletedTasks: deletedTasks,
            deletedOutcomes: deletedOutcomes
        )
    }

    private func resolveConflictAndStore<T: Codable>(
        docId: String,
        revision: CDTDocumentRevision,
        entityType: T.Type
    ) throws -> RevisionStoreResult {
        guard let existingRevision = try? store.dataStore.getDocumentWithId(docId) else {
            try store.dataStore.createDocument(from: revision)
            return .created
        }

        guard shouldApplyIncomingRevision(
            existingRevision: existingRevision,
            incomingRevision: revision,
            entityType: entityType
        ) else {
            return .skipped
        }

        let updatedRevision: CDTDocumentRevision
        if let revId = existingRevision.revId {
            updatedRevision = CDTDocumentRevision(docId: docId, revId: revId)
        } else {
            updatedRevision = CDTDocumentRevision(docId: docId)
        }
        updatedRevision.body = revision.body
        _ = try store.dataStore.updateDocument(from: updatedRevision)
        return .updated
    }

    private func shouldApplyIncomingRevision<T: Codable>(
        existingRevision: CDTDocumentRevision,
        incomingRevision: CDTDocumentRevision,
        entityType: T.Type
    ) -> Bool {
        guard let body = existingRevision.body as? [String: Any],
              body["entityType"] as? String == String(describing: entityType) else {
            return false
        }

        guard (try? existingRevision.data(as: entityType)) != nil else {
            return false
        }

        guard let existingDate = comparableSyncDate(from: existingRevision.body),
              let incomingDate = comparableSyncDate(from: incomingRevision.body) else {
            return false
        }

        return incomingDate > existingDate
    }

    private func comparableSyncDate(from body: Any?) -> Date? {
        guard let dictionary = body as? [String: Any] else {
            return nil
        }

        return dateValue(from: dictionary["updatedDate"]) ?? dateValue(from: dictionary["createdDate"])
    }

    private func dateValue(from value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }

        if let dateString = value as? String {
            return theraForgeISO8601Formatter.date(from: dateString)
        }

        if let dateString = value as? NSString {
            return theraForgeISO8601Formatter.date(from: dateString as String)
        }

        return nil
    }

    private func deleteValidatedDocuments(for deletion: OTFWatchSyncDeletion) throws -> DeletionApplyResult {
        switch deletion.entityType {
        case .task:
            return try deleteValidatedTaskDocument(deletion.documentID)
        case .outcome:
            return try deleteValidatedOutcomeDocuments(for: deletion)
        }
    }

    private func deleteValidatedTaskDocument(_ documentID: String) throws -> DeletionApplyResult {
        guard let revision = try? store.dataStore.getDocumentWithId(documentID) else {
            return DeletionApplyResult(deletedCount: 0, unresolvedRequestCount: 0)
        }

        guard let body = revision.body as? [String: Any],
              body["entityType"] as? String == OTFWatchSyncDeletion.EntityType.task.rawValue else {
            return DeletionApplyResult(deletedCount: 0, unresolvedRequestCount: 1)
        }

        guard let task = try? revision.data(as: OCKTask.self) else {
            return DeletionApplyResult(deletedCount: 0, unresolvedRequestCount: 1)
        }

        let deletedCount = try deleteDocumentIfPresent(documentID)
        return DeletionApplyResult(
            deletedCount: deletedCount,
            unresolvedRequestCount: 0,
            deletedTasks: deletedCount > 0 ? [task] : []
        )
    }

    private func deleteValidatedOutcomeDocuments(for deletion: OTFWatchSyncDeletion) throws -> DeletionApplyResult {
        var deletedCount = 0
        var deletedOutcomes = [OCKOutcome]()
        let documentIDs = store.validatedOutcomeDeletionDocumentIDs(for: deletion)
        for documentID in documentIDs {
            let snapshot = deletionSnapshot(for: documentID)
            let count = try deleteDocumentIfPresent(documentID)
            deletedCount += count
            if count > 0, let outcome = snapshot.outcome {
                deletedOutcomes.append(outcome)
            }
        }
        let unresolvedRequestCount: Int
        if localDocumentExists(deletion.documentID),
           !documentIDs.contains(deletion.documentID) {
            unresolvedRequestCount = 1
        } else {
            unresolvedRequestCount = 0
        }
        return DeletionApplyResult(
            deletedCount: deletedCount,
            unresolvedRequestCount: unresolvedRequestCount,
            deletedOutcomes: deletedOutcomes
        )
    }

    private func deletionSnapshot(for documentID: String) -> (task: OCKTask?, outcome: OCKOutcome?) {
        guard let revision = try? store.dataStore.getDocumentWithId(documentID),
              let body = revision.body as? [String: Any],
              let entityType = body["entityType"] as? String else {
            return (nil, nil)
        }

        switch entityType {
        case OTFWatchSyncDeletion.EntityType.task.rawValue:
            return (try? revision.data(as: OCKTask.self), nil)
        case OTFWatchSyncDeletion.EntityType.outcome.rawValue:
            return (nil, try? revision.data(as: OCKOutcome.self))
        default:
            return (nil, nil)
        }
    }

    private func notifyDelegates(
        taskResult: EntityApplyResult<OCKTask>,
        outcomeResult: EntityApplyResult<OCKOutcome>,
        deletionResults: [DeletionAggregateResult]
    ) {
        let addedTasks = uniqueTasks(taskResult.added)
        let updatedTasks = uniqueTasks(taskResult.updated)
        let deletedTasks = uniqueTasks(deletionResults.flatMap(\.deletedTasks))

        if !addedTasks.isEmpty {
            store.taskDelegate?.taskStore(store, didAddTasks: addedTasks)
        }
        if !updatedTasks.isEmpty {
            store.taskDelegate?.taskStore(store, didUpdateTasks: updatedTasks)
        }
        if !deletedTasks.isEmpty {
            store.taskDelegate?.taskStore(store, didDeleteTasks: deletedTasks)
        }

        let addedOutcomes = uniqueOutcomes(outcomeResult.added)
        let updatedOutcomes = uniqueOutcomes(outcomeResult.updated)
        let deletedOutcomes = uniqueOutcomes(deletionResults.flatMap(\.deletedOutcomes))

        if !addedOutcomes.isEmpty {
            store.outcomeDelegate?.outcomeStore(store, didAddOutcomes: addedOutcomes)
        }
        if !updatedOutcomes.isEmpty {
            store.outcomeDelegate?.outcomeStore(store, didUpdateOutcomes: updatedOutcomes)
        }
        if !deletedOutcomes.isEmpty {
            store.outcomeDelegate?.outcomeStore(store, didDeleteOutcomes: deletedOutcomes)
        }
    }

    private func uniqueTasks(_ tasks: [OCKTask]) -> [OCKTask] {
        var seenIDs = Set<String>()
        return tasks.filter { task in
            seenIDs.insert(task.id).inserted
        }
    }

    private func uniqueOutcomes(_ outcomes: [OCKOutcome]) -> [OCKOutcome] {
        var seenKeys = Set<String>()
        return outcomes.filter { outcome in
            seenKeys.insert(store.logicalOutcomeKey(outcome)).inserted
        }
    }

    private func deleteDocumentIfPresent(_ documentID: String) throws -> Int {
        guard (try? store.dataStore.getDocumentWithId(documentID)) != nil else {
            return 0
        }

        do {
            try store.dataStore.deleteDocument(withId: documentID)
            return 1
        } catch {
            OTFLogger.logger().error(
                "Failed to delete incremental sync document \(documentID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private func validatedLegacyDeletions(
        _ requestedDocumentIDs: [String]
    ) -> LegacyDeletionValidation {
        let logicalKeysByRequestID = Dictionary(
            uniqueKeysWithValues: Set(requestedDocumentIDs).compactMap { documentID -> (String, String)? in
                guard let logicalKey = store.logicalOutcomeKey(forCanonicalDocumentID: documentID) else {
                    return nil
                }
                return (documentID, logicalKey)
            }
        )
        let requestedLogicalKeys = Set(logicalKeysByRequestID.values)

        var documentIDsToDelete = Set<String>()
        var recognizedLogicalKeys = Set<String>()

        if !requestedLogicalKeys.isEmpty {
            for revision in store.dataStore.getAllDocuments() ?? [] {
                guard let documentID = revision.docId,
                      let body = revision.body as? [String: Any],
                      body["entityType"] as? String == OTFWatchSyncDeletion.EntityType.outcome.rawValue,
                      let outcome = try? revision.data(as: OCKOutcome.self) else {
                    continue
                }

                let logicalKey = store.logicalOutcomeKey(outcome)
                guard requestedLogicalKeys.contains(logicalKey) else {
                    continue
                }

                documentIDsToDelete.insert(documentID)
                recognizedLogicalKeys.insert(logicalKey)
            }
        }

        var recognizedRequestIDs = Set(logicalKeysByRequestID.compactMap { entry in
            recognizedLogicalKeys.contains(entry.value) ? entry.key : nil
        })
        var unresolvedRequestIDs = Set<String>()

        for documentID in Set(requestedDocumentIDs) where !recognizedRequestIDs.contains(documentID) {
            guard localDocumentExists(documentID) else {
                continue
            }

            guard isExistingTaskDocument(documentID) else {
                unresolvedRequestIDs.insert(documentID)
                continue
            }
            documentIDsToDelete.insert(documentID)
            recognizedRequestIDs.insert(documentID)
        }

        return LegacyDeletionValidation(
            documentIDsToDelete: documentIDsToDelete,
            recognizedRequestIDs: recognizedRequestIDs,
            unresolvedRequestIDs: unresolvedRequestIDs
        )
    }

    private func localDocumentExists(_ documentID: String) -> Bool {
        (try? store.dataStore.getDocumentWithId(documentID)) != nil
    }

    private func isExistingTaskDocument(_ documentID: String) -> Bool {
        guard let revision = try? store.dataStore.getDocumentWithId(documentID),
              let body = revision.body as? [String: Any],
              body["entityType"] as? String == OTFWatchSyncDeletion.EntityType.task.rawValue else {
            return false
        }
        return true
    }
}

#endif
