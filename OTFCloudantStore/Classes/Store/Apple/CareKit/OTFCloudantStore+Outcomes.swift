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
  import OTFCDTDatastore
  import OTFCareKitStore
  import OTFUtilities

  /// Extends OTFCloudantStore to perform actions on the result of an event.
  extension OTFCloudantStore {

    /**
      Fetches outcomes from the store.

     - Parameter query: a query that limits which outcomes the store returns, when you are fetching.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func fetchOutcomes(
      query: OCKOutcomeQuery = OCKOutcomeQuery(),
      callbackQueue: DispatchQueue = .main,
      completion: @escaping (Result<[OCKOutcome], OCKStoreError>) -> Void
    ) {
      let cloudantQuery = OTFCloudantOutcomeQuery(outcomeQuery: query)
      let postProcessesLocally = !query.sortDescriptors.isEmpty || query.limit != nil || query.offset > 0
      if postProcessesLocally {
        cloudantQuery.sortDescription = nil
        cloudantQuery.limit = nil
        cloudantQuery.offset = 0
      }
      let isTaskScopedQuery =
        !query.taskUUIDs.isEmpty || !query.taskIDs.isEmpty || !query.taskRemoteIDs.isEmpty
      let filter: (OCKOutcome) -> Bool = { outcome in
        self.shouldIncludeFetchedOutcome(outcome, for: query, isTaskScopedQuery: isTaskScopedQuery)
      }
      fetch(
        cloudantQuery: cloudantQuery, callbackQueue: callbackQueue, filter: filter,
        completion: { result in
          switch result {
          case .success(let outcomes):
            let normalizedOutcomes = self.normalizeFetchedOutcomes(outcomes)
            let sortedOutcomes = self.sortOutcomes(normalizedOutcomes, using: query.sortDescriptors)
            completion(.success(self.paginate(sortedOutcomes, offset: query.offset, limit: query.limit)))
          case .failure(let error):
            completion(.failure(error))
          }
        })
    }

    /**
     Adds the outcomes asynchronously to the store.

     - Parameter outcomes: the outcomes you add to the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func addOutcomes(
      _ outcomes: [OCKOutcome],
      callbackQueue: DispatchQueue = .main,
      completion: ((Result<[OCKOutcome], OCKStoreError>) -> Void)? = nil
    ) {
      add(
        outcomes, callbackQueue: callbackQueue,
        completion: { result in
          switch result {
          case .success(let outcomes):
            self.outcomeDelegate?.outcomeStore(
              self,
              didAddOutcomes: outcomes)
            completion?(.success(outcomes))
          case .failure:
            completion?(result.mapError { $0.toOCKStoreError() })
          }
        })
    }

    /**
     Updates the outcomes asynchronously in the store.

     - Parameter outcomes: the outcomes you update in the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func updateOutcomes(
      _ outcomes: [OCKOutcome],
      callbackQueue: DispatchQueue = .main,
      completion: ((Result<[OCKOutcome], OCKStoreError>) -> Void)? = nil
    ) {
      update(outcomes, callbackQueue: callbackQueue) { result in
        switch result {
        case .success(let outcomes):
          self.outcomeDelegate?.outcomeStore(
            self,
            didUpdateOutcomes: outcomes)
          completion?(.success(outcomes))
        case .failure:
          completion?(result.mapError { $0.toOCKStoreError() })
        }
      }
    }

    /**
     Deletes the outcomes asynchronously from the store.

     - Parameter outcomes: the outcomes you delete from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func deleteOutcomes(
      _ outcomes: [OCKOutcome],
      callbackQueue: DispatchQueue = .main,
      completion: ((Result<[OCKOutcome], OCKStoreError>) -> Void)? = nil
    ) {
      var deletedOutcomes = [OCKOutcome]()
      var failedOutcomes = [OCKOutcome]()
      var errors = [Error]()

      for outcome in outcomes {
        let logicalKey = logicalOutcomeKey(outcome)
        let documentIDs = outcomeDeletionDocumentIDs(for: outcome)
        var deletedDocumentCount = 0

        for documentID in documentIDs {
          do {
            if try deleteOutcomeDocument(
              withID: documentID, outcome: outcome, logicalKey: logicalKey) {
              deletedDocumentCount += 1
            }
          } catch {
            errors.append(error)
          }
        }

        if deletedDocumentCount > 0 {
          deletedOutcomes.append(outcome)
        } else {
          failedOutcomes.append(outcome)
        }
      }

      callbackQueue.async {
        if !deletedOutcomes.isEmpty {
          self.outcomeDelegate?.outcomeStore(self, didDeleteOutcomes: deletedOutcomes)
          completion?(.success(deletedOutcomes))
        }

        if !failedOutcomes.isEmpty {
          let reason = "[\(failedOutcomes)]. Errors: \(errors.map { $0.localizedDescription })"
          completion?(.failure(OTFCloudantError.deleteFailed(reason: reason).toOCKStoreError()))
        }
      }
    }

    public func outcomeDeletionDocumentIDs(for outcome: OCKOutcome) -> [String] {
      var documentIDs = Set(
        documentIDsForOutcomes(matchingLogicalKeys: [logicalOutcomeKey(outcome)]))
      if let canonicalDocumentID = CDTDocumentRevision.revision(fromEntity: outcome).docId {
        documentIDs.insert(canonicalDocumentID)
      }
      documentIDs.insert(outcome.id)
      return documentIDs.sorted()
    }

    private func deleteOutcomeDocument(
      withID documentID: String, outcome: OCKOutcome, logicalKey: String
    ) throws -> Bool {
      guard let currentRevision = try? dataStore.getDocumentWithId(documentID) else {
        return false
      }

      do {
        if let preferredRevision = preferredDeletionRevision(for: outcome, documentID: documentID) {
          try dataStore.deleteDocument(from: preferredRevision)
        } else {
          try dataStore.deleteDocument(from: currentRevision)
        }
        return true
      } catch {
        guard resolveOutcomeDocumentConflictIfNeeded(documentID) else {
          throw error
        }

        do {
          guard let refreshedRevision = try? dataStore.getDocumentWithId(documentID) else {
            return false
          }
          try dataStore.deleteDocument(from: refreshedRevision)
          return true
        } catch {
          guard !hasActiveOutcomeDocument(matchingLogicalKey: logicalKey) else {
            throw error
          }
          return false
        }
      }
    }

    private func preferredDeletionRevision(for outcome: OCKOutcome, documentID: String)
      -> CDTDocumentRevision? {
      let revision = CDTDocumentRevision.revision(fromEntity: outcome)
      guard revision.docId == documentID,
        revision.revId != nil
      else {
        return nil
      }
      return revision
    }

    private func resolveOutcomeDocumentConflictIfNeeded(_ documentID: String) -> Bool {
      do {
        try dataStore.resolveConflicts(
          forDocument: documentID,
          resolver: OTFCloudantOutcomeConflictResolver()
        )
        return true
      } catch {
        OTFLogger.logger().error(
          "OTFCloudantStore: failed to resolve outcome conflict before delete \(documentID, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        return false
      }
    }

    private func hasActiveOutcomeDocument(matchingLogicalKey logicalKey: String) -> Bool {
      (dataStore.getAllDocuments() ?? []).contains { revision in
        guard let body = revision.body as? [String: Any],
          body["entityType"] as? String == String(describing: OCKOutcome.self),
          let outcome = try? revision.data(as: OCKOutcome.self),
          logicalOutcomeKey(outcome) == logicalKey
        else {
          return false
        }

        return outcome.deletedDate == nil
      }
    }

    @discardableResult
    public func deleteOutcomeDocuments(matchingDeletedDocumentIDs deletedDocumentIDs: [String])
      -> [String] {
      let documentIDsToDelete = outcomeDeletionDocumentIDs(
        matchingDeletedDocumentIDs: deletedDocumentIDs)
      var deletedDocumentIDs = [String]()

      for documentID in documentIDsToDelete {
        do {
          guard (try? dataStore.getDocumentWithId(documentID)) != nil else {
            continue
          }
          try dataStore.deleteDocument(withId: documentID)
          deletedDocumentIDs.append(documentID)
        } catch {
          OTFLogger.logger().error(
            "OTFCloudantStore: failed to delete matching outcome doc \(documentID, privacy: .public)"
          )
        }
      }

      return deletedDocumentIDs
    }

    public func outcomeDeletionDocumentIDs(matchingDeletedDocumentIDs deletedDocumentIDs: [String])
      -> [String] {
      let logicalKeys = Set(
        deletedDocumentIDs.compactMap { logicalOutcomeKey(forCanonicalDocumentID: $0) })
      guard !logicalKeys.isEmpty else {
        return Array(Set(deletedDocumentIDs)).sorted()
      }

      var documentIDs = Set(deletedDocumentIDs)
      documentIDs.formUnion(documentIDsForOutcomes(matchingLogicalKeys: logicalKeys))
      return documentIDs.sorted()
    }

    func validatedOutcomeDeletionDocumentIDs(for deletion: OTFWatchSyncDeletion) -> [String] {
      let logicalKey: String?
      if let taskUUID = deletion.taskUUID,
        let occurrenceIndex = deletion.occurrenceIndex {
        logicalKey = "\(taskUUID.uuidString)|\(occurrenceIndex)"
      } else {
        logicalKey = logicalOutcomeKey(forCanonicalDocumentID: deletion.documentID)
      }

      guard let logicalKey else {
        return []
      }

      var documentIDs = Set(documentIDsForOutcomes(matchingLogicalKeys: [logicalKey]))
      documentIDs.insert(deletion.documentID)
      return documentIDs.filter { documentID in
        guard let revision = try? dataStore.getDocumentWithId(documentID),
          let body = revision.body as? [String: Any],
          body["entityType"] as? String == OTFWatchSyncDeletion.EntityType.outcome.rawValue,
          let outcome = try? revision.data(as: OCKOutcome.self)
        else {
          return false
        }
        return logicalOutcomeKey(outcome) == logicalKey
      }.sorted()
    }

    func validatedLegacyOutcomeDeletionDocumentIDs(_ deletedDocumentIDs: [String]) -> [String] {
      deletedDocumentIDs
        .compactMap { documentID -> OTFWatchSyncDeletion? in
          guard let key = outcomeDocumentKey(forCanonicalDocumentID: documentID) else {
            return nil
          }
          return OTFWatchSyncDeletion(
            documentID: documentID,
            entityType: .outcome,
            taskUUID: key.taskUUID,
            occurrenceIndex: key.occurrenceIndex
          )
        }
        .flatMap { validatedOutcomeDeletionDocumentIDs(for: $0) }
    }

    public func affectedDatesForDeletedOutcomeDocumentIDs(_ documentIDs: [String]) -> [Date] {
      let keys = Set(documentIDs.compactMap { outcomeDocumentKey(forCanonicalDocumentID: $0) })
      let affectedDates = keys.compactMap { key -> Date? in
        guard let task = task(withUUID: key.taskUUID),
          let event = task.schedule.event(forOccurrenceIndex: key.occurrenceIndex)
        else {
          return nil
        }

        return event.start
      }

      return Array(Set(affectedDates)).sorted()
    }

    /// Removes redundant local outcome documents and any soft-deleted winner for an event occurrence.
    ///
    /// Historical versions from earlier sync bugs can leave multiple current documents for the same
    /// logical event. Keeping only the newest non-deleted version prevents stale completions from
    /// resurfacing after a reload or replication round-trip.
    @discardableResult
    public func pruneStaleOutcomeDocuments() -> Int {
      let currentDocuments = dataStore.getAllDocuments() ?? []
      let collectedDocuments = collectOutcomeDocuments(currentDocuments)
      let cleanup = cleanupPlan(
        documentsByLogicalKey: collectedDocuments.documentsByLogicalKey,
        tombstoneDocumentIDs: collectedDocuments.tombstoneDocumentIDs
      )
      return deleteOutcomeDocuments(withIDs: cleanup.documentIDsToDelete) + cleanup.migratedCount
    }

    private func collectOutcomeDocuments(
      _ currentDocuments: [CDTDocumentRevision]
    ) -> (
      documentsByLogicalKey: [String: [OutcomeDocumentEntry]],
      tombstoneDocumentIDs: Set<String>
    ) {
      var documentsByLogicalKey = [String: [OutcomeDocumentEntry]]()
      var tombstoneDocumentIDs = Set<String>()

      for revision in currentDocuments {
        guard let body = revision.body as? [String: Any] else {
          if revision.deleted, let docId = revision.docId {
            tombstoneDocumentIDs.insert(docId)
          }
          continue
        }

        guard body["entityType"] as? String == String(describing: OCKOutcome.self),
          let outcome = try? revision.data(as: OCKOutcome.self)
        else {
          continue
        }

        let entry = OutcomeDocumentEntry(revision: revision, outcome: outcome)
        documentsByLogicalKey[logicalOutcomeKey(outcome), default: []].append(entry)
      }

      return (documentsByLogicalKey, tombstoneDocumentIDs)
    }

    private func cleanupPlan(
      documentsByLogicalKey: [String: [OutcomeDocumentEntry]],
      tombstoneDocumentIDs: Set<String>
    ) -> (documentIDsToDelete: Set<String>, migratedCount: Int) {
      var documentIDsToDelete = tombstoneDocumentIDs
      var migratedCount = 0

      for entries in documentsByLogicalKey.values {
        guard var winner = entries.first else { continue }

        for candidate in entries.dropFirst()
        where shouldPreferOutcome(candidate.outcome, over: winner.outcome) {
          winner = candidate
        }

        if winner.outcome.deletedDate != nil {
          for entry in entries {
            if let docId = entry.revision.docId {
              documentIDsToDelete.insert(docId)
            }
          }
          continue
        }

        let canonicalDocumentID = canonicalOutcomeDocumentID(for: winner.outcome)
        if migrateOutcomeDocumentIfNeeded(winner, to: canonicalDocumentID) {
          migratedCount += 1
        }

        for entry in entries where entry.revision.docId != canonicalDocumentID {
          if let docId = entry.revision.docId {
            documentIDsToDelete.insert(docId)
          }
        }
      }

      return (documentIDsToDelete, migratedCount)
    }

    private func deleteOutcomeDocuments(withIDs documentIDsToDelete: Set<String>) -> Int {
      var deletedCount = 0
      for docId in documentIDsToDelete {
        do {
          try dataStore.deleteDocument(withId: docId)
          deletedCount += 1
        } catch {
          OTFLogger.logger().error(
            "OTFCloudantStore: failed to prune stale outcome doc \(docId, privacy: .public)")
        }
      }

      return deletedCount
    }

    private func normalizeFetchedOutcomes(_ outcomes: [OCKOutcome]) -> [OCKOutcome] {
      guard !outcomes.isEmpty else {
        return []
      }

      var latestByLogicalKey = [String: OCKOutcome]()
      for outcome in outcomes {
        let key = logicalOutcomeKey(outcome)
        if let existing = latestByLogicalKey[key] {
          if shouldPreferOutcome(outcome, over: existing) {
            latestByLogicalKey[key] = outcome
          }
        } else {
          latestByLogicalKey[key] = outcome
        }
      }

      var emittedKeys = Set<String>()
      var normalized = [OCKOutcome]()

      for outcome in outcomes {
        let key = logicalOutcomeKey(outcome)
        guard emittedKeys.insert(key).inserted,
          let latest = latestByLogicalKey[key],
          latest.deletedDate == nil
        else {
          continue
        }

        normalized.append(latest)
      }

      return normalized
    }

    private func sortOutcomes(
      _ outcomes: [OCKOutcome],
      using sortDescriptors: [OCKOutcomeQuery.SortDescriptor]
    ) -> [OCKOutcome] {
      guard !sortDescriptors.isEmpty else {
        return outcomes
      }

      return outcomes.enumerated().sorted { lhs, rhs in
        for sortDescriptor in sortDescriptors {
          switch sortDescriptor {
          case .date(let ascending):
            let lhsValue = lhs.element.createdDate ?? .distantPast
            let rhsValue = rhs.element.createdDate ?? .distantPast
            if lhsValue != rhsValue {
              return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
            }
          }
        }
        return lhs.offset < rhs.offset
      }.map { $0.element }
    }

    private func paginate<Entity>(_ items: [Entity], offset: Int, limit: Int?) -> [Entity] {
      let startIndex = min(max(offset, 0), items.count)
      let remainingItems = items.dropFirst(startIndex)
      guard let limit = limit else {
        return Array(remainingItems)
      }
      return Array(remainingItems.prefix(max(limit, 0)))
    }

    func logicalOutcomeKey(_ outcome: OCKOutcome) -> String {
      "\(outcome.taskUUID.uuidString)|\(outcome.taskOccurrenceIndex)"
    }

    func logicalOutcomeKey(forCanonicalDocumentID documentID: String) -> String? {
      outcomeDocumentKey(forCanonicalDocumentID: documentID).map {
        "\($0.taskUUID.uuidString)|\($0.occurrenceIndex)"
      }
    }

    func documentIDsForOutcomes(matchingLogicalKeys logicalKeys: Set<String>) -> [String] {
      guard !logicalKeys.isEmpty else {
        return []
      }

      return (dataStore.getAllDocuments() ?? []).compactMap { revision in
        guard let docId = revision.docId,
          let body = revision.body as? [String: Any],
          body["entityType"] as? String == String(describing: OCKOutcome.self),
          let outcome = try? revision.data(as: OCKOutcome.self),
          logicalKeys.contains(logicalOutcomeKey(outcome))
        else {
          return nil
        }

        return docId
      }
    }

    private func canonicalOutcomeDocumentID(for outcome: OCKOutcome) -> String {
      "\(outcome.taskUUID.uuidString)_\(outcome.taskOccurrenceIndex)"
    }

    private func outcomeDocumentKey(forCanonicalDocumentID documentID: String)
      -> OutcomeDocumentKey? {
      guard let separatorRange = documentID.range(of: "_", options: .backwards) else {
        return nil
      }

      let uuidString = String(documentID[..<separatorRange.lowerBound])
      let occurrenceIndexString = String(documentID[separatorRange.upperBound...])
      guard let taskUUID = UUID(uuidString: uuidString),
        let occurrenceIndex = Int(occurrenceIndexString)
      else {
        return nil
      }

      return OutcomeDocumentKey(taskUUID: taskUUID, occurrenceIndex: occurrenceIndex)
    }

    private func task(withUUID uuid: UUID) -> OCKTask? {
      (dataStore.getAllDocuments() ?? []).compactMap { revision in
        guard let body = revision.body as? [String: Any],
          body["entityType"] as? String == String(describing: OCKTask.self),
          let task = try? revision.data(as: OCKTask.self),
          task.uuid == uuid
        else {
          return nil
        }

        return task
      }.first
    }

    private func shouldIncludeFetchedOutcome(
      _ outcome: OCKOutcome,
      for query: OCKOutcomeQuery,
      isTaskScopedQuery: Bool
    ) -> Bool {
      guard let interval = query.dateInterval else {
        return true
      }

      // CareKit fetches events by task UUID and the schedule's date interval.
      // An outcome may be created on a later day than the event it belongs to,
      // so filtering task-scoped queries by createdDate hides valid past completions.
      guard !isTaskScopedQuery else {
        return true
      }

      guard let createdAt = outcome.createdDate else {
        return true
      }

      return interval.contains(createdAt)
    }

    private func shouldPreferOutcome(_ candidate: OCKOutcome, over existing: OCKOutcome) -> Bool {
      let candidateDate = outcomeVersionDate(candidate)
      let existingDate = outcomeVersionDate(existing)

      if candidateDate != existingDate {
        return candidateDate > existingDate
      }

      if (candidate.deletedDate != nil) != (existing.deletedDate != nil) {
        return candidate.deletedDate != nil
      }

      if candidate.updatedDate != existing.updatedDate {
        return (candidate.updatedDate ?? .distantPast) > (existing.updatedDate ?? .distantPast)
      }

      if candidate.createdDate != existing.createdDate {
        return (candidate.createdDate ?? .distantPast) > (existing.createdDate ?? .distantPast)
      }

      let candidateIsCanonical = candidate.id == canonicalOutcomeDocumentID(for: candidate)
      let existingIsCanonical = existing.id == canonicalOutcomeDocumentID(for: existing)
      if candidateIsCanonical != existingIsCanonical {
        return candidateIsCanonical
      }

      return candidate.uuid.uuidString > existing.uuid.uuidString
    }

    private func outcomeVersionDate(_ outcome: OCKOutcome) -> Date {
      outcome.deletedDate ?? outcome.updatedDate ?? outcome.createdDate ?? outcome.effectiveDate
    }

    private func migrateOutcomeDocumentIfNeeded(
      _ entry: OutcomeDocumentEntry, to documentID: String
    ) -> Bool {
      guard entry.revision.docId != documentID,
        var body = entry.revision.body as? [String: Any]
      else {
        return false
      }

      body["id"] = documentID

      do {
        if let existingRevision = try? dataStore.getDocumentWithId(documentID),
          let revId = existingRevision.revId {
          let updatedRevision = CDTDocumentRevision(docId: documentID, revId: revId)
          updatedRevision.body = NSMutableDictionary(dictionary: body)
          try dataStore.updateDocument(from: updatedRevision)
        } else {
          let newRevision = CDTDocumentRevision(docId: documentID)
          newRevision.body = NSMutableDictionary(dictionary: body)
          try dataStore.createDocument(from: newRevision)
        }
        return true
      } catch {
        OTFLogger.logger().error(
          "OTFCloudantStore: failed to migrate outcome doc \(entry.revision.docId ?? "-", privacy: .public) to \(documentID, privacy: .public)"
        )
        return false
      }
    }

  }

  private struct OutcomeDocumentEntry {
    let revision: CDTDocumentRevision
    let outcome: OCKOutcome
  }

  private struct OutcomeDocumentKey: Hashable {
    let taskUUID: UUID
    let occurrenceIndex: Int
  }

  private final class OTFCloudantOutcomeConflictResolver: NSObject, CDTConflictResolver {
    func resolve(_ docId: String, conflicts: [CDTDocumentRevision]) -> CDTDocumentRevision? {
      conflicts.max { lhs, rhs in
        isPreferred(rhs, over: lhs)
      }
    }

    private func isPreferred(_ candidate: CDTDocumentRevision, over existing: CDTDocumentRevision)
      -> Bool {
      let candidateDate = outcomeVersionDate(candidate)
      let existingDate = outcomeVersionDate(existing)

      if let candidateDate, let existingDate, candidateDate != existingDate {
        return candidateDate > existingDate
      }

      if candidate.deleted != existing.deleted {
        return candidate.deleted
      }

      let candidateGeneration = revisionGeneration(candidate.revId)
      let existingGeneration = revisionGeneration(existing.revId)
      if candidateGeneration != existingGeneration {
        return candidateGeneration > existingGeneration
      }

      return (candidate.revId ?? "") > (existing.revId ?? "")
    }

    private func outcomeVersionDate(_ revision: CDTDocumentRevision) -> Date? {
      if let outcome = try? revision.data(as: OCKOutcome.self) {
        return outcome.deletedDate ?? outcome.updatedDate ?? outcome.createdDate
          ?? outcome.effectiveDate
      }

      guard let body = revision.body as? [String: Any] else {
        return nil
      }

      for key in ["deletedDate", "updatedDate", "createdDate", "effectiveDate"] {
        if let date = body[key] as? Date {
          return date
        }
        if let dateString = body[key] as? String,
          let date = theraForgeISO8601Formatter.date(from: dateString) {
          return date
        }
      }

      return nil
    }

    private func revisionGeneration(_ revId: String?) -> Int {
      guard let generation = revId?.split(separator: "-").first else {
        return 0
      }

      return Int(generation) ?? 0
    }
  }
#endif
