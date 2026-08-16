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

import XCTest
@testable import OTFCloudantStore
import OTFCDTDatastore
import enum OTFCareKitStore.OCKEntity
import protocol OTFCareKitStore.OCKAnyReadOnlyTaskStore
import protocol OTFCareKitStore.OCKAnyTask
import protocol OTFCareKitStore.OCKTaskStoreDelegate
import struct OTFCareKitStore.OCKOutcome
import struct OTFCareKitStore.OCKOutcomeQuery
import struct OTFCareKitStore.OCKOutcomeValue
import struct OTFCareKitStore.OCKPatient
import struct OTFCareKitStore.OCKSchedule
import enum OTFCareKitStore.OCKStoreError
import struct OTFCareKitStore.OCKTask
import struct OTFCareKitStore.OCKTaskQuery
import typealias OTFCareKitStore.OCKResultClosure
import OTFUtilities
import WatchConnectivity

final class WatchDeliveryOutcomeTests: XCTestCase {

    func testSynchronizeWatchAppUpdateReportsDeliveredAfterImmediatePushSuccess() throws {
        let remote = WatchDeliveryRemote()
        let store = try OTFCloudantStore(storeName: uniqueStoreName(), remote: remote)
        let result = waitForWatchAppUpdateResult(from: store)

        XCTAssertEqual(try result.get(), OTFWatchDeliveryOutcome.delivered)
        XCTAssertEqual(remote.updateWatchOSCallCount, 1)
    }

    func testSynchronizeWatchAppUpdateReportsQueuedForReachabilityFallback() throws {
        let remote = WatchDeliveryRemote(pushError: NSError(
            domain: WCErrorDomain,
            code: WCError.Code.notReachable.rawValue
        ))
        let store = try OTFCloudantStore(storeName: uniqueStoreName(), remote: remote)
        let result = waitForWatchAppUpdateResult(from: store)

        XCTAssertEqual(try result.get(), OTFWatchDeliveryOutcome.queued)
        XCTAssertEqual(remote.updateWatchOSCallCount, 1)
    }

    func testSynchronizeWatchAppUpdateReportsFailureForNonQueueableErrors() throws {
        let expectedError = NSError(domain: "watch.delivery.test", code: 42)
        let remote = WatchDeliveryRemote(pushError: expectedError)
        let store = try OTFCloudantStore(storeName: uniqueStoreName(), remote: remote)
        let result = waitForWatchAppUpdateResult(from: store)

        switch result {
        case .success(let outcome):
            XCTFail("Expected failure, got \(outcome)")
        case .failure(let error as NSError):
            XCTAssertEqual(error.domain, expectedError.domain)
            XCTAssertEqual(error.code, expectedError.code)
        }
        XCTAssertEqual(remote.updateWatchOSCallCount, 0)
    }

    func testIncrementalDeliveryResultReportsFailureForStandardReceiverErrorReply() {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionError: "apply failed"
        ])

        switch result {
        case .success(let outcome):
            XCTFail("Expected failure, got \(outcome)")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("apply failed"))
        }
    }

    func testIncrementalDeliveryResultReportsFailureForLegacyReceiverErrorReply() {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            "error": "legacy apply failed"
        ])

        switch result {
        case .success(let outcome):
            XCTFail("Expected failure, got \(outcome)")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("legacy apply failed"))
        }
    }

    func testIncrementalDeliveryResultReportsDeliveredForSuccessfulReply() throws {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: ["received": true])

        XCTAssertEqual(try result.get(), OTFWatchDeliveryOutcome.delivered)
    }

    func testIncrementalDeliveryResultReportsFailureWhenReceiverSkippedDeletion() {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "tasks": 0,
                "outcomes": 0,
                "deletions": 0,
                "skipped": 1,
                "skippedDeletions": 1
            ]
        ])

        switch result {
        case .success(let outcome):
            XCTFail("Expected failure, got \(outcome)")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("skipped deletion"))
        }
    }

    func testIncrementalDeliveryResultReportsFailureWhenReceiverSkippedDeletionFromNSNumberReply() {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "skippedDeletions": NSNumber(value: 1)
            ]
        ])

        switch result {
        case .success(let outcome):
            XCTFail("Expected failure, got \(outcome)")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("skipped deletion"))
        }
    }

    func testIncrementalDeliveryResultReportsFailureWhenReceiverSkippedDeletionFromNSDictionaryReply() {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: NSDictionary(dictionary: [
                "skippedDeletions": NSNumber(value: 1)
            ])
        ])

        switch result {
        case .success(let outcome):
            XCTFail("Expected failure, got \(outcome)")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("skipped deletion"))
        }
    }

    func testIncrementalDeliveryResultIgnoresNonDeletionSkips() throws {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "tasks": 0,
                "outcomes": 0,
                "deletions": 0,
                "skipped": 1,
                "skippedDeletions": 0
            ]
        ])

        XCTAssertEqual(try result.get(), OTFWatchDeliveryOutcome.delivered)
    }

    private func waitForWatchAppUpdateResult(
        from store: OTFCloudantStore
    ) -> Result<OTFWatchDeliveryOutcome, Error> {
        let expectation = expectation(description: "wait for watch app update result")
        var receivedResult: Result<OTFWatchDeliveryOutcome, Error>?

        store.synchronizeWatchAppUpdate { result in
            receivedResult = result
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        return receivedResult ?? .failure(NSError(domain: "watch.delivery.test", code: -1))
    }

    private func uniqueStoreName() -> String {
        let suffix = UUID().uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return "watch_delivery_\(suffix)"
    }
}

extension WatchDeliveryOutcomeTests {

    func testWatchAuthContextParsesValidMessageFields() throws {
        let context = try XCTUnwrap(OTFWatchAuthContext(message: [
            OTFWatchConnectivityMessageKey.authSessionID: "session-a",
            OTFWatchConnectivityMessageKey.authCommandGeneration: 7
        ]))

        XCTAssertEqual(context.sessionID, "session-a")
        XCTAssertEqual(context.generation, 7)
    }

    func testWatchAuthContextRejectsMissingSession() {
        XCTAssertNil(OTFWatchAuthContext(message: [
            OTFWatchConnectivityMessageKey.authCommandGeneration: 7
        ]))
    }

    func testWatchAuthContextAddsFieldsToMessage() {
        let context = OTFWatchAuthContext(sessionID: "session-a", generation: 7)
        let message = context.addingFields(to: ["payload": true])

        XCTAssertEqual(message["payload"] as? Bool, true)
        XCTAssertEqual(message[OTFWatchConnectivityMessageKey.authSessionID] as? String, "session-a")
        XCTAssertEqual(message[OTFWatchConnectivityMessageKey.authCommandGeneration] as? Int, 7)
    }

    func testPeerAddsOutboundAuthContextWhenProviderIsSet() {
        let peer = OTFWatchConnectivityPeer()
        peer.outboundMessageContextProvider = {
            OTFWatchAuthContext(sessionID: "session-a", generation: 7)
        }

        let message = peer.messageWithOutboundContextForTesting([
            OTFWatchConnectivityMessageKey.databaseSynced: "Success"
        ])

        XCTAssertEqual(message[OTFWatchConnectivityMessageKey.databaseSynced] as? String, "Success")
        XCTAssertEqual(message[OTFWatchConnectivityMessageKey.authSessionID] as? String, "session-a")
        XCTAssertEqual(message[OTFWatchConnectivityMessageKey.authCommandGeneration] as? Int, 7)
    }
}

private final class WatchDeliveryRemote: OCKRemoteSynchronizable {

    weak var delegate: OCKRemoteSynchronizationDelegate?
    let automaticallySynchronizes = true
    private let pushError: Error?
    private(set) var updateWatchOSCallCount = 0

    init(pushError: Error? = nil) {
        self.pushError = pushError
    }

    func pullRevisions(
        mergeRevision: @escaping ([String: [Data]]) -> Void,
        completion: @escaping (Error?) -> Void
    ) {
        completion(nil)
    }

    func pushRevisions(completion: @escaping (Error?) -> Void) {
        completion(pushError)
    }

    func chooseConflictResolution(
        conflicts: [OCKEntity],
        completion: @escaping OCKResultClosure<OCKEntity>
    ) {
    }

    func updatewatchOS() {
        updateWatchOSCallCount += 1
    }
}

#if HEALTH && CARE
class OTFWatchMergeSafetyTestCase: XCTestCase {

    private var storesToDelete = [(manager: CDTDatastoreManager, name: String)]()

    override func tearDownWithError() throws {
        for store in storesToDelete {
            try? store.manager.deleteDatastoreNamed(store.name)
        }
        storesToDelete.removeAll()
        try super.tearDownWithError()
    }

    func makeStore() throws -> OTFCloudantStore {
        let name = "test_\(UUID().uuidString)"
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        let store = try OTFCloudantStore(storeName: name)
        storesToDelete.append((store.datastoreManager, name))
        return store
    }

    func makeTask(id: String, end: Date? = nil) -> OCKTask {
        let schedule = OCKSchedule.dailyAtTime(
            hour: 8,
            minutes: 0,
            start: Date(timeIntervalSince1970: 1_800_000_000),
            end: end,
            text: nil
        )
        var task = OCKTask(id: id, title: id, carePlanUUID: nil, schedule: schedule)
        task.createdDate = Date(timeIntervalSince1970: 1_800_000_000)
        task.updatedDate = task.createdDate
        return task
    }

    func makeOutcome(taskUUID: UUID, updatedDate: Date, value: Int) -> OCKOutcome {
        var outcome = OCKOutcome(
            taskUUID: taskUUID,
            taskOccurrenceIndex: 0,
            values: [OCKOutcomeValue(value)]
        )
        outcome.createdDate = updatedDate.addingTimeInterval(-60)
        outcome.updatedDate = updatedDate
        outcome.effectiveDate = updatedDate
        return outcome
    }

    func outcomeRevision(_ outcome: OCKOutcome, documentID: String) -> CDTDocumentRevision {
        var body = CDTDocumentRevision.encodedDictionary(fromEntity: outcome)
        body["id"] = documentID
        return body.toDocumentRevision(revId: nil)
    }

    func insertBackendStyleTask(
        _ task: OCKTask,
        documentID: String,
        into store: OTFCloudantStore
    ) throws {
        var body = CDTDocumentRevision.encodedDictionary(fromEntity: task)
        body.removeValue(forKey: PropertyKey.startDate)
        body.removeValue(forKey: PropertyKey.endDate)
        let revision = CDTDocumentRevision(docId: documentID)
        revision.body = NSMutableDictionary(dictionary: body)
        try store.dataStore.createDocument(from: revision)
    }

    func fetchTaskTitles(
        in store: OTFCloudantStore,
        on date: Date,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String] {
        let fetchExpectation = expectation(description: "fetch tasks")
        var fetchResult: Result<[OCKTask], OCKStoreError>?
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = try XCTUnwrap(
            Calendar.current.date(byAdding: .day, value: 1, to: startOfDay),
            file: file,
            line: line
        ).addingTimeInterval(-1)
        var query = OCKTaskQuery(dateInterval: DateInterval(start: startOfDay, end: endOfDay))
        query.excludesTasksWithNoEvents = true

        store.fetchTasks(query: query, callbackQueue: .main) { result in
            fetchResult = result
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation], timeout: 5)

        switch fetchResult {
        case .success(let tasks):
            return tasks.map { $0.title ?? "" }
        case .failure(let error):
            throw error
        case .none:
            XCTFail("Expected task fetch to complete", file: file, line: line)
            return []
        }
    }
}

final class OTFWatchMergeSafetySnapshotTests: OTFWatchMergeSafetyTestCase {

    func testPartialWatchRevisionDoesNotDeleteUnmentionedDocuments() throws {
        let store = try makeStore()
        let untouchedTask = makeTask(id: "untouched")
        var updatedTask = makeTask(id: "updated")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: untouchedTask))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: updatedTask))

        updatedTask.title = "Updated"
        updatedTask.updatedDate = updatedTask.updatedDate?.addingTimeInterval(60)
        let revision: [String: [Data]] = [
            "tasks": [try JSONEncoder().encode(updatedTask)],
            "outcomes": []
        ]

        store.mergeRevision(revision)

        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("untouched"))
        let updatedRevision = try store.dataStore.getDocumentWithId("updated")
        let decodedTask = try XCTUnwrap(updatedRevision.data(as: OCKTask.self))
        XCTAssertEqual(decodedTask.title, "Updated")
    }

    func testFullWatchRevisionDoesNotDeleteUnmentionedWatchDocuments() throws {
        let store = try makeStore()
        let staleTask = makeTask(id: "stale")
        let staleOutcome = makeOutcome(taskUUID: UUID(), updatedDate: Date(timeIntervalSince1970: 1_800_000_000), value: 1)
        let staleOutcomeDocumentID = try XCTUnwrap(CDTDocumentRevision.revision(fromEntity: staleOutcome).docId)
        let keptTask = makeTask(id: "kept")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: staleTask))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: staleOutcome))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: keptTask))

        let revision: [String: [Data]] = [
            "tasks": [try JSONEncoder().encode(keptTask)],
            "outcomes": [],
            "fullSnapshot": [Data("true".utf8)]
        ]

        store.mergeRevision(revision)

        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("stale"))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId(staleOutcomeDocumentID))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("kept"))
    }

    func testFullWatchRevisionPreservesUnrepresentedEntityDocuments() throws {
        let store = try makeStore()
        let keptTask = makeTask(id: "kept")
        let patient = OCKPatient(id: "patient", givenName: "Jane", familyName: "Doe")
        let unknownRevision = [
            "id": "unknown",
            "entityType": "UnrepresentedEntity"
        ].toDocumentRevision(revId: nil)

        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: keptTask))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: patient))
        try store.dataStore.createDocument(from: unknownRevision)

        let revision: [String: [Data]] = [
            "tasks": [try JSONEncoder().encode(keptTask)],
            "outcomes": [],
            "fullSnapshot": [Data("true".utf8)]
        ]

        store.mergeRevision(revision)

        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("kept"))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("patient"))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("unknown"))
    }

    func testAddTasksNotifiesDelegateWithAddEvent() throws {
        let store = try makeStore()
        let delegate = TaskStoreDelegateSpy()
        store.taskDelegate = delegate

        let expectation = expectation(description: "add task")
        store.addTasks([makeTask(id: "new-task")], callbackQueue: .main) { result in
            if case let .failure(error) = result {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        XCTAssertEqual(delegate.addedTaskIDs, ["new-task"])
        XCTAssertTrue(delegate.updatedTaskIDs.isEmpty)
        XCTAssertTrue(delegate.deletedTaskIDs.isEmpty)
    }
}

final class OTFWatchIncrementalPayloadTests: OTFWatchMergeSafetyTestCase {

    func testIncrementalPayloadAppliesOnlyIncludedDocumentsAndExplicitDeletions() throws {
        let store = try makeStore()
        var updatedTask = makeTask(id: "updated")
        let untouchedTask = makeTask(id: "untouched")
        let deletedTask = makeTask(id: "deleted")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: updatedTask))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: untouchedTask))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: deletedTask))

        updatedTask.title = "Updated"
        updatedTask.updatedDate = updatedTask.updatedDate?.addingTimeInterval(60)
        let payload = try store.makeIncrementalSyncPayload(
            tasks: [updatedTask],
            deletions: [OTFWatchSyncDeletion(documentID: "deleted", entityType: .task)]
        )

        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.tasks, 1)
        XCTAssertEqual(result.deletions, 1)
        XCTAssertNil(try? store.dataStore.getDocumentWithId("deleted"))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("untouched"))
        let updatedRevision = try store.dataStore.getDocumentWithId("updated")
        let decodedTask = try XCTUnwrap(updatedRevision.data(as: OCKTask.self))
        XCTAssertEqual(decodedTask.title, "Updated")
    }

    func testIncrementalPayloadSkipsLocalDocumentWithWrongEntityType() throws {
        let store = try makeStore()
        var localTask = makeTask(id: "wrong-type")
        localTask.title = "Local"
        var incomingTask = localTask
        incomingTask.title = "Incoming"
        incomingTask.updatedDate = localTask.updatedDate?.addingTimeInterval(60)

        var body = CDTDocumentRevision.encodedDictionary(fromEntity: localTask)
        body["entityType"] = "UnrepresentedEntity"
        try store.dataStore.createDocument(from: body.toDocumentRevision(revId: nil))

        let payload = try store.makeIncrementalSyncPayload(tasks: [incomingTask])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.tasks, 0)
        XCTAssertEqual(result.skipped, 1)
        let storedRevision = try store.dataStore.getDocumentWithId("wrong-type")
        let storedBody = try XCTUnwrap(storedRevision.body as? [String: Any])
        XCTAssertEqual(storedBody["entityType"] as? String, "UnrepresentedEntity")
    }

    func testIncrementalPayloadSkipsOlderOutcomeOverNewerLocalOutcome() throws {
        let store = try makeStore()
        let taskUUID = UUID()
        let localDate = Date(timeIntervalSince1970: 1_800_000_300)
        let incomingDate = Date(timeIntervalSince1970: 1_800_000_100)
        let localOutcome = makeOutcome(taskUUID: taskUUID, updatedDate: localDate, value: 2)
        let incomingOutcome = makeOutcome(taskUUID: taskUUID, updatedDate: incomingDate, value: 1)
        let documentID = try XCTUnwrap(CDTDocumentRevision.revision(fromEntity: localOutcome).docId)
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: localOutcome))

        let payload = try store.makeIncrementalSyncPayload(outcomes: [incomingOutcome])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.outcomes, 0)
        XCTAssertEqual(result.skipped, 1)
        let stored = try XCTUnwrap(store.dataStore.getDocumentWithId(documentID).data(as: OCKOutcome.self))
        XCTAssertEqual(stored.values.first?.integerValue, 2)
    }

    func testIncrementalPayloadAppliesNewerOutcomeOverOlderLocalOutcome() throws {
        let store = try makeStore()
        let taskUUID = UUID()
        let localDate = Date(timeIntervalSince1970: 1_800_000_100)
        let incomingDate = Date(timeIntervalSince1970: 1_800_000_300)
        let localOutcome = makeOutcome(taskUUID: taskUUID, updatedDate: localDate, value: 1)
        let incomingOutcome = makeOutcome(taskUUID: taskUUID, updatedDate: incomingDate, value: 2)
        let documentID = try XCTUnwrap(CDTDocumentRevision.revision(fromEntity: localOutcome).docId)
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: localOutcome))

        let payload = try store.makeIncrementalSyncPayload(outcomes: [incomingOutcome])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.outcomes, 1)
        XCTAssertEqual(result.skipped, 0)
        let stored = try XCTUnwrap(store.dataStore.getDocumentWithId(documentID).data(as: OCKOutcome.self))
        XCTAssertEqual(stored.values.first?.integerValue, 2)
    }

    func testIncrementalPayloadAppliesLegacyTaskDeletionOnlyWhenDocumentIsTask() throws {
        let store = try makeStore()
        let task = makeTask(id: "legacy-task")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: task))

        let payload = OTFWatchSyncPayload(deletedDocumentIDs: ["legacy-task"])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.deletions, 1)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-task"))
    }

    func testIncrementalPayloadIgnoresLegacyUnknownDeletedDocumentID() throws {
        let store = try makeStore()

        let payload = OTFWatchSyncPayload(deletedDocumentIDs: ["must-not-delete"])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.deletions, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.skippedDeletions, 0)
    }

    func testIncrementalPayloadHandlesDuplicateLegacyOutcomeDeletionIDsDeterministically() throws {
        let store = try makeStore()
        let patient = OCKPatient(id: "must-not-delete", givenName: "Jane", familyName: "Doe")
        let taskUUID = UUID()
        let outcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 1
        )
        let canonicalOutcomeID = try XCTUnwrap(CDTDocumentRevision.revision(fromEntity: outcome).docId)
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: patient))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: outcome))
        try store.dataStore.createDocument(from: outcomeRevision(outcome, documentID: "legacy-duplicate"))

        let payload = OTFWatchSyncPayload(deletedDocumentIDs: [
            canonicalOutcomeID,
            canonicalOutcomeID,
            "must-not-delete"
        ])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.deletions, 2)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.skippedDeletions, 1)
        XCTAssertNil(try? store.dataStore.getDocumentWithId(canonicalOutcomeID))
        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-duplicate"))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("must-not-delete"))
    }

    func testTypedTaskDeletionDeletesOnlyTaskDocument() throws {
        let store = try makeStore()
        let deletedTask = makeTask(id: "deleted-task")
        let keptTask = makeTask(id: "kept-task")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: deletedTask))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: keptTask))

        let payload = OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(documentID: "deleted-task", entityType: .task)
        ])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.deletions, 1)
        XCTAssertNil(try? store.dataStore.getDocumentWithId("deleted-task"))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("kept-task"))
    }

    func testTypedOutcomeDeletionDeletesMatchingLogicalOutcomeDocumentsOnly() throws {
        let store = try makeStore()
        let taskUUID = UUID()
        let deletedOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 1
        )
        let keptOutcome = makeOutcome(
            taskUUID: UUID(),
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 2
        )
        let canonicalDeletedID = try XCTUnwrap(CDTDocumentRevision.revision(fromEntity: deletedOutcome).docId)
        let canonicalKeptID = try XCTUnwrap(CDTDocumentRevision.revision(fromEntity: keptOutcome).docId)
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: deletedOutcome))
        try store.dataStore.createDocument(from: outcomeRevision(deletedOutcome, documentID: "legacy-duplicate"))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: keptOutcome))

        let payload = OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(
                documentID: canonicalDeletedID,
                entityType: .outcome,
                taskUUID: taskUUID,
                occurrenceIndex: 0
            )
        ])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.deletions, 2)
        XCTAssertNil(try? store.dataStore.getDocumentWithId(canonicalDeletedID))
        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-duplicate"))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId(canonicalKeptID))
    }

    func testTypedOutcomeDeletionCountsExistingNonOutcomeDocumentAsSkippedDeletion() throws {
        let store = try makeStore()
        let documentID = "11111111-1111-1111-1111-111111111111_0"
        let patient = OCKPatient(id: documentID, givenName: "Jane", familyName: "Doe")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: patient))

        let payload = OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(documentID: documentID, entityType: .outcome)
        ])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.deletions, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.skippedDeletions, 1)
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId(documentID))
    }
}

final class OTFWatchSyncPayloadTests: OTFWatchMergeSafetyTestCase {

    func testTypedDeletionPayloadRoundTripsThroughWatchMessage() throws {
        let deletion = OTFWatchSyncDeletion(
            documentID: "task-1",
            entityType: .task
        )
        let payload = OTFWatchSyncPayload(deletions: [deletion])

        let decoded = try XCTUnwrap(OTFWatchSyncPayload(message: payload.message))

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.deletions, [deletion])
        XCTAssertTrue(decoded.legacyDeletedDocumentIDs.isEmpty)
        XCTAssertEqual(decoded.deletedDocumentIDs, ["task-1"])
    }

    func testTypedOutcomeDeletionPayloadRoundTripsLogicalIdentity() throws {
        let taskUUID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let deletion = OTFWatchSyncDeletion(
            documentID: "\(taskUUID.uuidString)_2",
            entityType: .outcome,
            taskUUID: taskUUID,
            occurrenceIndex: 2
        )
        let payload = OTFWatchSyncPayload(deletions: [deletion])

        let decoded = try XCTUnwrap(OTFWatchSyncPayload(message: payload.message))

        XCTAssertEqual(decoded.deletions, [deletion])
        XCTAssertEqual(decoded.deletedDocumentIDs, ["\(taskUUID.uuidString)_2"])
    }

    func testTypedOutcomeDeletionPayloadAcceptsCanonicalDocumentIDWithoutLogicalIdentity() throws {
        let taskUUID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let message: [String: Any] = [
            "schemaVersion": 2,
            "deletions": [[
                "documentID": "\(taskUUID.uuidString)_2",
                "entityType": "OCKOutcome"
            ]]
        ]

        let decoded = try XCTUnwrap(OTFWatchSyncPayload(message: message))

        XCTAssertEqual(decoded.deletions, [
            OTFWatchSyncDeletion(documentID: "\(taskUUID.uuidString)_2", entityType: .outcome)
        ])
    }

    func testLegacyDeletedDocumentIDsRoundTripAsLegacyPayload() throws {
        let payload = OTFWatchSyncPayload(deletedDocumentIDs: ["legacy-id"])

        let decoded = try XCTUnwrap(OTFWatchSyncPayload(message: payload.message))

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertTrue(decoded.deletions.isEmpty)
        XCTAssertEqual(decoded.legacyDeletedDocumentIDs, ["legacy-id"])
        XCTAssertEqual(decoded.deletedDocumentIDs, ["legacy-id"])
    }

    func testMixedTypedAndLegacyDeletedDocumentIDsAreBothReported() throws {
        let payload = OTFWatchSyncPayload(
            deletions: [OTFWatchSyncDeletion(documentID: "typed-id", entityType: .task)],
            deletedDocumentIDs: ["legacy-id", "typed-id"]
        )

        let decoded = try XCTUnwrap(OTFWatchSyncPayload(message: payload.message))

        XCTAssertEqual(decoded.deletedDocumentIDs, ["typed-id", "legacy-id"])
    }

    func testMalformedTypedDeletionMessageIsRejected() {
        let message: [String: Any] = [
            "schemaVersion": 2,
            "deletions": [["documentID": "missing-entity-type"]]
        ]

        XCTAssertNil(OTFWatchSyncPayload(message: message))
    }

    func testMalformedTypedOutcomeDeletionIdentityIsRejected() {
        let message: [String: Any] = [
            "schemaVersion": 2,
            "deletions": [[
                "documentID": "outcome-id",
                "entityType": "OCKOutcome",
                "taskUUID": "not-a-uuid",
                "occurrenceIndex": 0
            ]]
        ]

        XCTAssertNil(OTFWatchSyncPayload(message: message))
    }

    func testTypedOutcomeDeletionWithoutLogicalIdentityOrCanonicalDocumentIDIsRejected() {
        let message: [String: Any] = [
            "schemaVersion": 2,
            "deletions": [[
                "documentID": "not-a-canonical-outcome-id",
                "entityType": "OCKOutcome"
            ]]
        ]

        XCTAssertNil(OTFWatchSyncPayload(message: message))
    }

    func testLegacyRevisionRequestReplyIncludesFullSnapshot() throws {
        let store = try makeStore()
        let task = makeTask(id: "legacy-reply-task")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: task))
        let peer = OTFWatchConnectivityPeer()
        let expectation = expectation(description: "legacy revision reply")
        var reply: [String: Any]?

        peer.reply(
            to: ["OCKPeerRevisionRequest": "request"],
            store: store
        ) { message in
            reply = message
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        let revision = try XCTUnwrap(reply?["OCKPeerRevisionReply"] as? [String: [Data]])
        XCTAssertEqual(revision["fullSnapshot"]?.first.flatMap { String(data: $0, encoding: .utf8) }, "true")
        XCTAssertEqual(revision["tasks"]?.count, 1)
        XCTAssertNotNil(revision["outcomes"])
    }

    func testLegacyRevisionRequestReplyReturnsRevisionErrorWhenNoTasksExist() throws {
        let store = try makeStore()
        let peer = OTFWatchConnectivityPeer()
        let expectation = expectation(description: "empty legacy revision reply")
        var reply: [String: Any]?

        peer.reply(
            to: ["OCKPeerRevisionRequest": "request"],
            store: store
        ) { message in
            reply = message
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        XCTAssertEqual(reply?[OTFWatchConnectivityMessageKey.revisionError] as? String, "Revision Error")
    }

    func testUnknownWatchMessageDoesNotSendReply() throws {
        let store = try makeStore()
        let peer = OTFWatchConnectivityPeer()
        var replyCount = 0

        peer.reply(to: ["unknown": "message"], store: store) { _ in
            replyCount += 1
        }

        XCTAssertEqual(replyCount, 0)
    }

    func testMalformedIncrementalPayloadReplyReturnsRevisionError() throws {
        let store = try makeStore()
        let peer = OTFWatchConnectivityPeer()
        let malformedMessage: [String: Any] = [
            OTFWatchConnectivityMessageKey.incrementalRevisionPush: [
                "schemaVersion": 2,
                "deletions": [["documentID": "missing-entity-type"]]
            ]
        ]
        var reply: [String: Any]?

        peer.reply(to: malformedMessage, store: store) { message in
            reply = message
        }

        XCTAssertNotNil(reply?[OTFWatchConnectivityMessageKey.revisionError])
    }

    func testIncrementalPayloadReplyIncludesSkippedCount() throws {
        let store = try makeStore()
        let peer = OTFWatchConnectivityPeer()
        let payload = OTFWatchSyncPayload(deletedDocumentIDs: ["must-not-delete"])
        var reply: [String: Any]?

        peer.reply(
            to: [OTFWatchConnectivityMessageKey.incrementalRevisionPush: payload.message],
            store: store
        ) { message in
            reply = message
        }

        let result = try XCTUnwrap(reply?[OTFWatchConnectivityMessageKey.revisionPushResult] as? [String: Int])
        XCTAssertEqual(result["deletions"], 0)
        XCTAssertEqual(result["skipped"], 1)
        XCTAssertEqual(result["skippedDeletions"], 0)
    }
}

final class OTFWatchMergeQueryTests: OTFWatchMergeSafetyTestCase {

    func testDeletedOutcomeDocumentIDResolvesAffectedDateFromTaskSchedule() throws {
        let store = try makeStore()
        let task = makeTask(id: "task")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: task))
        let expectedDate = try XCTUnwrap(task.schedule.event(forOccurrenceIndex: 0)?.start)
        let deletedOutcomeDocumentID = "\(task.uuid.uuidString)_0"

        let affectedDates = store.affectedDatesForDeletedOutcomeDocumentIDs([deletedOutcomeDocumentID])

        XCTAssertEqual(affectedDates, [expectedDate])
    }

    func testOutcomeFetchNormalizesDuplicateLogicalOccurrencesToNewestWinner() throws {
        let store = try makeStore()
        let taskUUID = UUID()
        let olderDate = Date(timeIntervalSince1970: 1_800_000_000)
        let newerDate = olderDate.addingTimeInterval(60)

        let olderOutcome = makeOutcome(taskUUID: taskUUID, updatedDate: olderDate, value: 1)
        let newerOutcome = makeOutcome(taskUUID: taskUUID, updatedDate: newerDate, value: 2)
        try store.dataStore.createDocument(from: outcomeRevision(olderOutcome, documentID: "legacy-outcome"))
        try store.dataStore.createDocument(from: outcomeRevision(newerOutcome, documentID: newerOutcome.id))

        let expectation = expectation(description: "fetch outcomes")
        store.fetchOutcomes(callbackQueue: .main) { result in
            switch result {
            case .success(let outcomes):
                XCTAssertEqual(outcomes.count, 1)
                XCTAssertEqual(outcomes.first?.values.first?.integerValue, 2)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testTaskDateQueryUsesScheduleBounds() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval((24 * 60 * 60) - 1)
        let query = OCKTaskQuery(dateInterval: DateInterval(start: start, end: end))
        let cloudantQuery = OTFCloudantTaskQuery(taskQuery: query)

        let andConditions = try XCTUnwrap(
            cloudantQuery.parameters[OTFCloudantCombinationSelector.and.rawValue] as? [[String: Any]]
        )
        let startWindow = try XCTUnwrap(andConditions.first)
        let startDate = try XCTUnwrap(startWindow[PropertyKey.startDate] as? [String: String])
        let expectedEnd = theraForgeISO8601Formatter.string(from: end)

        XCTAssertEqual(startDate[OTFCloudantConditionSelector.lessThanOrEqual.rawValue], expectedEnd)
    }

    func testBackfillTaskDateMetadataMakesBackendTaskDateQueryable() throws {
        let store = try makeStore()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let taskID = "backend-task"
        let task = makeTask(id: taskID, end: start.addingTimeInterval(TimeInterval(7 * 24 * 60 * 60)))
        try insertBackendStyleTask(task, documentID: taskID, into: store)

        XCTAssertEqual(try fetchTaskTitles(in: store, on: start), [])

        XCTAssertEqual(store.backfillTaskDateMetadataIfNeeded(), 1)

        let updatedRevision = try store.dataStore.getDocumentWithId(taskID)
        let updatedBody = try XCTUnwrap(updatedRevision.body as? [String: Any])
        XCTAssertNotNil(updatedBody[PropertyKey.startDate])
        XCTAssertNotNil(updatedBody[PropertyKey.endDate])
        XCTAssertEqual(try fetchTaskTitles(in: store, on: start), [taskID])
    }
}

private final class TaskStoreDelegateSpy: OCKTaskStoreDelegate {
    var addedTaskIDs = [String]()
    var updatedTaskIDs = [String]()
    var deletedTaskIDs = [String]()

    func taskStore(_ store: OCKAnyReadOnlyTaskStore, didAddTasks tasks: [OCKAnyTask]) {
        addedTaskIDs.append(contentsOf: tasks.map(\.id))
    }

    func taskStore(_ store: OCKAnyReadOnlyTaskStore, didUpdateTasks tasks: [OCKAnyTask]) {
        updatedTaskIDs.append(contentsOf: tasks.map(\.id))
    }

    func taskStore(_ store: OCKAnyReadOnlyTaskStore, didDeleteTasks tasks: [OCKAnyTask]) {
        deletedTaskIDs.append(contentsOf: tasks.map(\.id))
    }
}
#endif
