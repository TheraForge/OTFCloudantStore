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

import CoreData
import Foundation
import OTFCareKitStore
import OTFCDTDatastore
import OTFUtilities
import WatchConnectivity

public enum Target {
    case mobile, watchOS, watchAppUpdate
}

public struct OTFIncrementalSyncApplyResult: Equatable {
    public let tasks: Int
    public let outcomes: Int
    public let deletions: Int
    public let skipped: Int
    public let skippedDeletions: Int

    public init(
        tasks: Int = 0,
        outcomes: Int = 0,
        deletions: Int = 0,
        skipped: Int = 0,
        skippedDeletions: Int = 0
    ) {
        self.tasks = tasks
        self.outcomes = outcomes
        self.deletions = deletions
        self.skipped = skipped
        self.skippedDeletions = skippedDeletions
    }
}

extension OTFCloudantStore: OCKRemoteSynchronizationDelegate {

    private enum FileConstants {
        static let tasksKey = "tasks"
        static let outcomesKey = "outcomes"
        static let fullSnapshotKey = "fullSnapshot"
    }

    public func remote(_ remote: OCKRemoteSynchronizable, didUpdateProgress progress: Double) {

    }

    public func didRequestSynchronization(_ remote: OCKRemoteSynchronizable) {
        OTFLogger.logger().debug("Remote requested synchronization")
        autoSynchronizeIfRequired()
    }

    /// Synchronizes the on device store with one on a remote server.
    ///
    /// Depending on the mode, it possible to overwrite the entire contents of the device or
    /// the remote with the data from the other.
    ///
    /// - Parameters:
    ///   - policy: The synchronization policy. Defaults to `.mergeDeviceRecordsWithRemote`
    ///   - completion: A completion closure that will be called when syncing completes.
    /// - SeeAlso: OCKRemoteSynchronizable
    public func synchronize(target: Target = Target.watchOS, completion: @escaping (Error?) -> Void) {
        switch target {
        case .watchOS:
            pull(completion: completion)
        case .mobile:
            push(completion: completion)
        case .watchAppUpdate:
            watchAppUpdate { result in
                switch result {
                case .success:
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }

    public func synchronizeWatchAppUpdate(
        completion: @escaping (Result<OTFWatchDeliveryOutcome, Error>) -> Void
    ) {
        watchAppUpdate(completion: completion)
    }

    /// Calls synchronize if the remote is set and requests to notified after each database modification.
    func autoSynchronizeIfRequired() {
        if remote?.automaticallySynchronizes == true {
            push { error in
                if let error = error {
                    OTFLogger.logger().error("Failed to automatically synchronize. \(error.localizedDescription, privacy: .private)")
                }
            }
        }
    }

    private func pull(completion: @escaping (Error?) -> Void) {
        // 1. Make sure a remote is setup
        guard let remote = self.remote else {
            completion(OCKStoreError.remoteSynchronizationFailed(
                reason: "No remote set on OTFCloudantStore!"))
            return
        }

        // 2. Pull revisions
        remote.pullRevisions { revision in
            self.mergeRevision(revision)
        } completion: { error in
            completion(error)
        }
    }

    private func push(completion: @escaping (Error?) -> Void) {
        guard let remote = self.remote else {
            completion(OCKStoreError.remoteSynchronizationFailed(
                reason: "No remote set on OTFCloudantStore!"))
            return
        }
        remote.updatewatchOS()
        completion(nil)
    }

    private func watchAppUpdate(completion: @escaping (Result<OTFWatchDeliveryOutcome, Error>) -> Void) {
        guard let remote = self.remote else {
            completion(.failure(OCKStoreError.remoteSynchronizationFailed(
                reason: "No remote set on OTFCloudantStore!")))
            return
        }
        remote.pushRevisions { error in
            if let error = error {
                if self.isQueuedWatchRefreshCandidate(error) {
                    remote.updatewatchOS()
                    completion(.success(.queued))
                } else {
                    completion(.failure(error))
                }
            } else {
                remote.updatewatchOS()
                completion(.success(.delivered))
            }
        }
    }

    /// Builds the full watch snapshot used by the legacy pull-revisions request.
    func computeRevision(store: OTFCloudantStore, completion: @escaping (([String: [Data]]?) -> Void)) {
#if CARE && HEALTH

        store.fetchTasks { result in
            switch result {
            case .success(let todayTasks):
                if !todayTasks.isEmpty {
                    store.fetchOutcomes { result in
                        switch result {
                        case .success(let todayOutcome):
                            do {
                                var tasks: [Data] = [Data]()
                                for task in todayTasks {
                                    let dic = try JSONEncoder().encode(task)
                                    tasks.append(dic)
                                }
                                var outcomes: [Data] = [Data]()
                                for outcome in todayOutcome {
                                    let dic = try JSONEncoder().encode(outcome)
                                    outcomes.append(dic)
                                }
                                var data: [String: [Data]] = [String: [Data]]()
                                data[FileConstants.tasksKey] = tasks
                                data[FileConstants.outcomesKey] = outcomes
                                data[FileConstants.fullSnapshotKey] = [Data("true".utf8)]
                                completion(data)
                            } catch {
                                completion(nil)
                            }
                        case .failure:
                            completion(nil)
                        }
                    }
                } else {
                    completion(nil)
                }
            case .failure:
                completion(nil)
            }
        }
#endif
    }

    public func backfillTaskDateMetadataIfNeeded() -> Int {
#if CARE && HEALTH
        guard let revisions = dataStore.getAllDocuments(), !revisions.isEmpty else {
            return 0
        }

        var updatedCount = 0

        for revision in revisions {
            guard
                let body = revision.body as? [String: Any],
                body["entityType"] as? String == String(describing: OCKTask.self),
                let task = try? revision.data(as: OCKTask.self)
            else {
                continue
            }

            let hasStartDate = body["startDate"] != nil
            let hasEndDate = body["endDate"] != nil
            guard !hasStartDate || !hasEndDate else {
                continue
            }

            var updatedBody = body
            if !hasStartDate {
                updatedBody["startDate"] = theraForgeISO8601Formatter.string(from: task.schedule.startDate())
            }
            if !hasEndDate, let endDate = task.schedule.endDate() {
                updatedBody["endDate"] = theraForgeISO8601Formatter.string(from: endDate)
            }

            guard
                let docId = revision.docId,
                let revId = revision.revId
            else {
                continue
            }

            let updatedRevision = CDTDocumentRevision(docId: docId, revId: revId)
            updatedRevision.body = NSMutableDictionary(dictionary: updatedBody)

            do {
                try dataStore.updateDocument(from: updatedRevision)
                updatedCount += 1
            } catch {
                let documentID = revision.docId ?? "-"
                OTFLogger.logger().error(
                    "Failed to backfill task metadata for \(documentID, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return updatedCount
#else
        return 0
#endif
    }

    public func makeIncrementalSyncPayload(
        tasks: [OCKTask] = [],
        outcomes: [OCKOutcome] = [],
        deletions: [OTFWatchSyncDeletion] = [],
        deletedDocumentIDs: [String] = []
    ) throws -> OTFWatchSyncPayload {
#if CARE && HEALTH
        let encodedTasks = try tasks.map { task in
            try JSONEncoder().encode(task)
        }
        let encodedOutcomes = try outcomes.map { outcome in
            try JSONEncoder().encode(outcome)
        }
        return OTFWatchSyncPayload(
            tasks: encodedTasks,
            outcomes: encodedOutcomes,
            deletions: deletions,
            deletedDocumentIDs: deletedDocumentIDs
        )
#else
        return OTFWatchSyncPayload(deletions: deletions, deletedDocumentIDs: deletedDocumentIDs)
#endif
    }

    @available(*, deprecated, message: "Use applyIncrementalSync(payload:) instead.")
    @discardableResult
    public func applyIncrementalSyncPayload(_ payload: OTFWatchSyncPayload) throws -> (tasks: Int, outcomes: Int, deletions: Int) {
        let result = try applyIncrementalSync(payload: payload)

        return (tasks: result.tasks, outcomes: result.outcomes, deletions: result.deletions)
    }

    @discardableResult
    public func applyIncrementalSync(payload: OTFWatchSyncPayload) throws -> OTFIncrementalSyncApplyResult {
#if CARE && HEALTH
        return try OTFWatchSyncApplier(store: self).apply(payload: payload)
#else
        return OTFIncrementalSyncApplyResult()
#endif
    }

    func mergeRevision(_ revision: [String: [Data]]) {
        let tasks = revision[FileConstants.tasksKey]
        let outcomes = revision[FileConstants.outcomesKey]
#if CARE && HEALTH
        guard let tasks = tasks, let outcomes = outcomes else {
            OTFLogger.logger().error("Something went wrong on sync data")
            return
        }

        _ = mergeTaskRevisions(tasks)
        _ = mergeOutcomeRevisions(outcomes)
#endif
    }

#if CARE && HEALTH
    private func mergeTaskRevisions(_ taskData: [Data]) -> [String] {
        OTFWatchSyncApplier(store: self).mergeTaskRevisions(taskData)
    }

    private func mergeOutcomeRevisions(_ outcomeData: [Data]) -> [String] {
        OTFWatchSyncApplier(store: self).mergeOutcomeRevisions(outcomeData)
    }

#endif
    
    public func deleteRecords(completion: @escaping (String?) -> Void) {
        let ids = self.dataStore.getAllDocuments()
        if let ids = ids, !ids.isEmpty {
            do {
                for item in ids {
                    try self.dataStore.deleteDocument(withId: item.docId!)
                }
                completion(nil)
            } catch {
                completion(error.localizedDescription)
            }
        } else {
            completion(nil)
        }
        
    }

    private func isQueuedWatchRefreshCandidate(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == WCErrorDomain,
           let code = WCError.Code(rawValue: nsError.code) {
            switch code {
            case .deliveryFailed, .notReachable, .transferTimedOut:
                return true
            default:
                return false
            }
        }

        return error.localizedDescription.lowercased().contains("reachable")
    }
    
    /// - Note: Thread Safe
    private func findNextConflict() {
    }
    
    /// - Warning: This method must be called on the `context`'s queue.
    ///
    /// Fetches objects that have been created or modified since the given date. These are the objects that need
    /// to be pushed to the server as part of a sync operation.
    private func changedQuery(entity: NSEntityDescription,
                              since vector: OCKRevisionRecord.KnowledgeVector) {
    }
    
    private func findFirstConflict(entity: NSEntityDescription) {
    }
    
    func resolveConflicts(completion: @escaping (Error?) -> Void) {
    }
}
