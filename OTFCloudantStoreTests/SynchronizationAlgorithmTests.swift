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
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.
 */

import XCTest
@testable import OTFCloudantStore
import OTFCDTDatastore
import enum OTFCareKitStore.OCKEntity
import protocol OTFCareKitStore.OCKAnyOutcome
import protocol OTFCareKitStore.OCKAnyReadOnlyOutcomeStore
import protocol OTFCareKitStore.OCKAnyReadOnlyTaskStore
import protocol OTFCareKitStore.OCKAnyTask
import protocol OTFCareKitStore.OCKOutcomeStoreDelegate
import protocol OTFCareKitStore.OCKTaskStoreDelegate
import struct OTFCareKitStore.OCKOutcome
import struct OTFCareKitStore.OCKOutcomeQuery
import struct OTFCareKitStore.OCKOutcomeValue
import struct OTFCareKitStore.OCKPatient
import struct OTFCareKitStore.OCKSchedule
import enum OTFCareKitStore.OCKStoreError
import struct OTFCareKitStore.OCKTask
import typealias OTFCareKitStore.OCKResultClosure
import WatchConnectivity

final class SynchronizationRoutingTests: XCTestCase {

    private var temporaryDirectories = [URL]()

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testSynchronizeWithoutRemoteCompletesOnceForWatchMobileAndWatchAppUpdate() throws {
        for target in [Target.watchOS, .mobile, .watchAppUpdate] {
            let store = try makeStore(prefix: "no_remote")
            let completions = recordSynchronizeCompletions(from: store, target: target)

            XCTAssertEqual(completions.count, 1, "Expected one completion for \(target)")
            XCTAssertNotNil(firstCompletion(in: completions), "Expected missing remote error for \(target)")
        }
    }

    func testSynchronizeWatchOSRoutesToPullRevisions() throws {
        let remote = Phase2RemoteSpy(revisionBatches: [["tasks": [], "outcomes": []]])
        let store = try makeStore(prefix: "watch_route", remote: remote)
        let completions = recordSynchronizeCompletions(from: store, target: .watchOS)

        XCTAssertEqual(remote.pullCallCount, 1)
        XCTAssertEqual(remote.pushCallCount, 0)
        XCTAssertEqual(remote.updateWatchOSCallCount, 0)
        XCTAssertEqual(completions.count, 1)
        XCTAssertNil(firstCompletion(in: completions))
    }

    func testSynchronizeMobileRoutesToUpdateWatchOSOnly() throws {
        let remote = Phase2RemoteSpy()
        let store = try makeStore(prefix: "mobile_route", remote: remote)
        let completions = recordSynchronizeCompletions(from: store, target: .mobile)

        XCTAssertEqual(remote.pullCallCount, 0)
        XCTAssertEqual(remote.pushCallCount, 0)
        XCTAssertEqual(remote.updateWatchOSCallCount, 1)
        XCTAssertEqual(completions.count, 1)
        XCTAssertNil(firstCompletion(in: completions))
    }

    func testSynchronizeWatchAppUpdateRoutesThroughPushRevisionsAndQueuedNotification() throws {
        let remote = Phase2RemoteSpy(pushError: NSError(
            domain: WCErrorDomain,
            code: WCError.Code.notReachable.rawValue
        ))
        let store = try makeStore(prefix: "watch_update_route", remote: remote)
        let result = recordWatchAppUpdateResult(from: store)

        XCTAssertEqual(try result.get(), .queued)
        XCTAssertEqual(remote.pullCallCount, 0)
        XCTAssertEqual(remote.pushCallCount, 1)
        XCTAssertEqual(remote.updateWatchOSCallCount, 1)
    }

    func testDidRequestSynchronizationDoesNotPushWhenAutomaticSyncIsDisabled() throws {
        let remote = Phase2RemoteSpy(automaticallySynchronizes: false)
        let store = try makeStore(prefix: "autosync_disabled", remote: remote)

        store.didRequestSynchronization(remote)

        XCTAssertEqual(remote.updateWatchOSCallCount, 0)
        XCTAssertEqual(remote.pushCallCount, 0)
        XCTAssertEqual(remote.pullCallCount, 0)
    }

    func testDidRequestSynchronizationPushesWhenAutomaticSyncIsEnabled() throws {
        let remote = Phase2RemoteSpy(automaticallySynchronizes: true)
        let store = try makeStore(prefix: "autosync_enabled", remote: remote)

        store.didRequestSynchronization(remote)

        XCTAssertEqual(remote.updateWatchOSCallCount, 1)
        XCTAssertEqual(remote.pushCallCount, 0)
        XCTAssertEqual(remote.pullCallCount, 0)
    }

    func testPullCompletionIsCalledOnceForEmptySuccess() throws {
        let remote = Phase2RemoteSpy()
        let store = try makeStore(prefix: "empty_pull", remote: remote)
        let completions = recordSynchronizeCompletions(from: store, target: .watchOS)

        XCTAssertEqual(remote.pullCallCount, 1)
        XCTAssertEqual(completions.count, 1)
        XCTAssertNil(firstCompletion(in: completions))
    }

    func testPullCompletionIsCalledOnceForMultipleRevisionBatches() throws {
        let remote = Phase2RemoteSpy(revisionBatches: [
            ["tasks": [], "outcomes": []],
            ["tasks": [], "outcomes": []]
        ])
        let store = try makeStore(prefix: "multi_pull", remote: remote)
        let completions = recordSynchronizeCompletions(from: store, target: .watchOS)

        XCTAssertEqual(remote.pullCallCount, 1)
        XCTAssertEqual(remote.mergedRevisionBatchCount, 2)
        XCTAssertEqual(completions.count, 1)
        XCTAssertNil(firstCompletion(in: completions))
    }

    func testPullCompletionIsCalledOnceAndReturnsErrorAfterMergeBatches() throws {
        let expectedError = NSError(domain: "phase2.pull", code: 7)
        let remote = Phase2RemoteSpy(
            revisionBatches: [["tasks": [], "outcomes": []]],
            pullError: expectedError
        )
        let store = try makeStore(prefix: "error_pull", remote: remote)
        let completions = recordSynchronizeCompletions(from: store, target: .watchOS)

        XCTAssertEqual(remote.pullCallCount, 1)
        XCTAssertEqual(remote.mergedRevisionBatchCount, 1)
        XCTAssertEqual(completions.count, 1)
        let error = try XCTUnwrap(firstCompletion(in: completions) as NSError?)
        XCTAssertEqual(error.domain, expectedError.domain)
        XCTAssertEqual(error.code, expectedError.code)
    }

    func testWatchDeliveryResultReportsDeliveredForSuccess() throws {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "tasks": 1,
                "outcomes": 1,
                "deletions": 1,
                "skipped": 0,
                "skippedDeletions": 0
            ]
        ])

        XCTAssertEqual(try result.get(), .delivered)
    }

    func testWatchDeliveryResultReportsDeliveredForPartialNonDeletionSuccess() throws {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "tasks": 1,
                "outcomes": 0,
                "deletions": 0,
                "skipped": 2,
                "skippedDeletions": 0
            ]
        ])

        XCTAssertEqual(try result.get(), .delivered)
    }

    func testWatchDeliveryResultReportsFailureForSkippedDeletion() {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "skippedDeletions": 1
            ]
        ])

        assertWatchDeliveryFailure(result, contains: "skipped deletion")
    }

    func testWatchDeliveryResultReportsFailureForMalformedReplyCount() {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "tasks": 1,
                "outcomes": 0,
                "deletions": 0,
                "skipped": 0,
                "skippedDeletions": "one"
            ]
        ])

        assertWatchDeliveryFailure(result, contains: "Invalid incremental sync reply")
    }

    func testWatchDeliveryResultReportsFailureForFractionalReplyCount() {
        let fractionalReplies: [[String: Any]] = [
            [
                "tasks": 1,
                "outcomes": 0,
                "deletions": 0,
                "skipped": 0,
                "skippedDeletions": 0.5
            ],
            [
                "tasks": 1,
                "outcomes": 0,
                "deletions": 0,
                "skipped": 0,
                "skippedDeletions": NSNumber(value: 0.5)
            ]
        ]

        for reply in fractionalReplies {
            let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
                OTFWatchConnectivityMessageKey.revisionPushResult: reply
            ])

            assertWatchDeliveryFailure(result, contains: "Invalid incremental sync reply")
        }
    }

    func testWatchDeliveryResultReportsFailureForNegativeReplyCount() {
        let result = OTFWatchConnectivityPeer.incrementalDeliveryResult(for: [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "tasks": 0,
                "outcomes": 0,
                "deletions": 0,
                "skipped": -1,
                "skippedDeletions": 0
            ]
        ])

        assertWatchDeliveryFailure(result, contains: "Invalid incremental sync reply")
    }

    func testWatchDeliveryReportsNonQueueableTransportError() {
        let session = Phase2WatchSession()
        let expectedError = NSError(domain: "phase2.watch", code: 13)
        session.sendMessageError = expectedError
        let peer = OTFWatchConnectivityPeer(session: session)
        let result = waitForIncrementalDelivery(
            peer: peer,
            payload: OTFWatchSyncPayload(deletions: [
                OTFWatchSyncDeletion(documentID: "task-id", entityType: .task)
            ])
        )

        switch result {
        case .success(let outcome):
            XCTFail("Expected failure, got \(outcome)")
        case .failure(let error as NSError):
            XCTAssertEqual(error.domain, expectedError.domain)
            XCTAssertEqual(error.code, expectedError.code)
        }
        XCTAssertTrue(session.transferredUserInfoMessages.isEmpty)
    }

    func testWatchDeliveryQueuesReachabilityTransportFallback() throws {
        let session = Phase2WatchSession()
        session.sendMessageError = NSError(
            domain: WCErrorDomain,
            code: WCError.Code.notReachable.rawValue
        )
        let peer = OTFWatchConnectivityPeer(session: session)
        let result = waitForIncrementalDelivery(
            peer: peer,
            payload: OTFWatchSyncPayload(deletions: [
                OTFWatchSyncDeletion(documentID: "task-id", entityType: .task)
            ])
        )

        XCTAssertEqual(try result.get(), .queued)
        XCTAssertEqual(session.sentMessages.count, 1)
        XCTAssertEqual(session.transferredUserInfoMessages.count, 1)
    }

    private func makeStore(prefix: String, remote: OCKRemoteSynchronizable? = nil) throws -> OTFCloudantStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        let manager = try CDTDatastoreManager(directory: directory.path)
        let storeName = prefix.replacingOccurrences(of: "-", with: "_")
        let dataStore = try manager.datastoreNamed(storeName)
        return OTFCloudantStore(
            storeName: storeName,
            remote: remote,
            datastoreManager: manager,
            dataStore: dataStore,
            indexBootstrap: .skip
        )
    }

    private func recordSynchronizeCompletions(
        from store: OTFCloudantStore,
        target: Target
    ) -> [Error?] {
        var completions = [Error?]()

        store.synchronize(target: target) { error in
            completions.append(error)
        }

        return completions
    }

    private func firstCompletion(in completions: [Error?]) -> Error? {
        completions.first.flatMap { $0 }
    }

    private func recordWatchAppUpdateResult(
        from store: OTFCloudantStore
    ) -> Result<OTFWatchDeliveryOutcome, Error> {
        let expectation = expectation(description: "wait for watch update")
        var receivedResult: Result<OTFWatchDeliveryOutcome, Error>?

        store.synchronizeWatchAppUpdate { result in
            receivedResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
        return receivedResult ?? .failure(NSError(domain: "phase2.watch", code: -1))
    }

    private func waitForIncrementalDelivery(
        peer: OTFWatchConnectivityPeer,
        payload: OTFWatchSyncPayload
    ) -> Result<OTFWatchDeliveryOutcome, Error> {
        let expectation = expectation(description: "wait for incremental delivery")
        var receivedResult: Result<OTFWatchDeliveryOutcome, Error>?

        peer.pushIncrementalPayloadWithDeliveryOutcome(payload) { result in
            receivedResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
        return receivedResult ?? .failure(NSError(domain: "phase2.watch", code: -2))
    }

    private func assertWatchDeliveryFailure(
        _ result: Result<OTFWatchDeliveryOutcome, Error>,
        contains expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case .success(let outcome):
            XCTFail("Expected failure, got \(outcome)", file: file, line: line)
        case .failure(let error):
            XCTAssertTrue(
                error.localizedDescription.contains(expectedMessage),
                "Unexpected error: \(error.localizedDescription)",
                file: file,
                line: line
            )
        }
    }
}

private final class Phase2RemoteSpy: OCKRemoteSynchronizable {
    weak var delegate: OCKRemoteSynchronizationDelegate?
    let automaticallySynchronizes: Bool
    private let revisionBatches: [[String: [Data]]]
    private let pullError: Error?
    private let pushError: Error?
    private(set) var pullCallCount = 0
    private(set) var pushCallCount = 0
    private(set) var updateWatchOSCallCount = 0
    private(set) var mergedRevisionBatchCount = 0

    init(
        revisionBatches: [[String: [Data]]] = [],
        pullError: Error? = nil,
        pushError: Error? = nil,
        automaticallySynchronizes: Bool = true
    ) {
        self.revisionBatches = revisionBatches
        self.pullError = pullError
        self.pushError = pushError
        self.automaticallySynchronizes = automaticallySynchronizes
    }

    func pullRevisions(
        mergeRevision: @escaping ([String: [Data]]) -> Void,
        completion: @escaping (Error?) -> Void
    ) {
        pullCallCount += 1
        for batch in revisionBatches {
            mergedRevisionBatchCount += 1
            mergeRevision(batch)
        }
        completion(pullError)
    }

    func pushRevisions(completion: @escaping (Error?) -> Void) {
        pushCallCount += 1
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

private final class Phase2WatchSession: WatchSessioning {
    var activationState: WCSessionActivationState = .activated
    var isReachable = true
    var sentMessages = [[String: Any]]()
    var transferredUserInfoMessages = [[String: Any]]()
    var sendMessageReply: [String: Any] = [:]
    var sendMessageError: Error?

#if os(iOS)
    var isPaired = true
    var isWatchAppInstalled = true
#endif

#if os(watchOS)
    var isCompanionAppInstalled = true
    var iOSDeviceNeedsUnlockAfterRebootForReachability = false
#endif

    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        sentMessages.append(message)
        if let sendMessageError {
            errorHandler?(sendMessageError)
        } else {
            replyHandler?(sendMessageReply)
        }
    }

    func transferUserInfo(_ message: [String: Any]) {
        transferredUserInfoMessages.append(message)
    }
}

#if CARE && HEALTH
class Phase2CareHealthTestCase: XCTestCase {

    private var temporaryDirectories = [URL]()

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func makeStore(prefix: String) throws -> OTFCloudantStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        let manager = try CDTDatastoreManager(directory: directory.path)
        let storeName = prefix.replacingOccurrences(of: "-", with: "_")
        let dataStore = try manager.datastoreNamed(storeName)
        return OTFCloudantStore(
            storeName: storeName,
            datastoreManager: manager,
            dataStore: dataStore,
            indexBootstrap: .skip
        )
    }

    func makeTask(
        id: String,
        updatedDate: Date,
        title: String? = nil,
        end: Date? = nil
    ) -> OCKTask {
        let schedule = OCKSchedule.dailyAtTime(
            hour: 8,
            minutes: 0,
            start: Date(timeIntervalSince1970: 1_800_000_000),
            end: end,
            text: nil
        )
        var task = OCKTask(id: id, title: title ?? id, carePlanUUID: nil, schedule: schedule)
        task.createdDate = updatedDate.addingTimeInterval(-60)
        task.updatedDate = updatedDate
        return task
    }

    func makeOutcome(
        taskUUID: UUID,
        updatedDate: Date,
        value: Int,
        occurrenceIndex: Int = 0,
        deletedDate: Date? = nil
    ) -> OCKOutcome {
        var outcome = OCKOutcome(
            taskUUID: taskUUID,
            taskOccurrenceIndex: occurrenceIndex,
            values: [OCKOutcomeValue(value)]
        )
        outcome.createdDate = updatedDate.addingTimeInterval(-60)
        outcome.updatedDate = updatedDate
        outcome.effectiveDate = updatedDate
        outcome.deletedDate = deletedDate
        return outcome
    }

    func insertTask(_ task: OCKTask, into store: OTFCloudantStore) throws {
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: task))
    }

    func insertOutcome(_ outcome: OCKOutcome, into store: OTFCloudantStore) throws -> String {
        let revision = CDTDocumentRevision.revision(fromEntity: outcome)
        let documentID = try XCTUnwrap(revision.docId)
        try store.dataStore.createDocument(from: revision)
        return documentID
    }

    func outcomeRevision(_ outcome: OCKOutcome, documentID: String) -> CDTDocumentRevision {
        var body = CDTDocumentRevision.encodedDictionary(fromEntity: outcome)
        body["id"] = documentID
        return body.toDocumentRevision(revId: nil)
    }

    func canonicalOutcomeDocumentID(for outcome: OCKOutcome) throws -> String {
        try XCTUnwrap(CDTDocumentRevision.revision(fromEntity: outcome).docId)
    }

    func decodedTask(_ id: String, in store: OTFCloudantStore) throws -> OCKTask {
        try XCTUnwrap(try store.dataStore.getDocumentWithId(id).data(as: OCKTask.self))
    }

    func decodedOutcome(_ id: String, in store: OTFCloudantStore) throws -> OCKOutcome {
        try XCTUnwrap(try store.dataStore.getDocumentWithId(id).data(as: OCKOutcome.self))
    }

    func insertMalformedOutcomeDocument(documentID: String, into store: OTFCloudantStore) throws {
        let revision = CDTDocumentRevision(docId: documentID)
        revision.body = NSMutableDictionary(dictionary: [
            "id": documentID,
            "entityType": String(describing: OCKOutcome.self),
            "taskUUID": "not-a-uuid",
            "taskOccurrenceIndex": 0
        ])
        try store.dataStore.createDocument(from: revision)
    }

    func insertBackendStyleTask(
        _ task: OCKTask,
        documentID: String,
        into store: OTFCloudantStore,
        removingFields fields: Set<String>
    ) throws {
        var body = CDTDocumentRevision.encodedDictionary(fromEntity: task)
        for field in fields {
            body.removeValue(forKey: field)
        }
        let revision = CDTDocumentRevision(docId: documentID)
        revision.body = NSMutableDictionary(dictionary: body)
        try store.dataStore.createDocument(from: revision)
    }
}

final class SynchronizationAlgorithmTests: Phase2CareHealthTestCase {

    func testLegacyMergeAppliesNewerTaskRevision() throws {
        let store = try makeStore(prefix: "legacy_newer_task")
        let localDate = Date(timeIntervalSince1970: 1_800_000_100)
        let incomingDate = Date(timeIntervalSince1970: 1_800_000_200)
        try insertTask(makeTask(id: "task", updatedDate: localDate, title: "Local"), into: store)

        let incomingTask = makeTask(id: "task", updatedDate: incomingDate, title: "Incoming")
        store.mergeRevision(["tasks": [try JSONEncoder().encode(incomingTask)], "outcomes": []])

        XCTAssertEqual(try decodedTask("task", in: store).title, "Incoming")
    }

    func testLegacyMergeSkipsOlderTaskRevision() throws {
        let store = try makeStore(prefix: "legacy_older_task")
        let localDate = Date(timeIntervalSince1970: 1_800_000_200)
        let incomingDate = Date(timeIntervalSince1970: 1_800_000_100)
        try insertTask(makeTask(id: "task", updatedDate: localDate, title: "Local"), into: store)

        let incomingTask = makeTask(id: "task", updatedDate: incomingDate, title: "Incoming")
        store.mergeRevision(["tasks": [try JSONEncoder().encode(incomingTask)], "outcomes": []])

        XCTAssertEqual(try decodedTask("task", in: store).title, "Local")
    }

    func testLegacyMergeSkipsEqualDatedTaskRevision() throws {
        let store = try makeStore(prefix: "legacy_equal_task")
        let date = Date(timeIntervalSince1970: 1_800_000_200)
        try insertTask(makeTask(id: "task", updatedDate: date, title: "Local"), into: store)

        let incomingTask = makeTask(id: "task", updatedDate: date, title: "Incoming")
        store.mergeRevision(["tasks": [try JSONEncoder().encode(incomingTask)], "outcomes": []])

        XCTAssertEqual(try decodedTask("task", in: store).title, "Local")
    }

    func testLegacyMergeAppliesNewerOutcomeRevision() throws {
        let store = try makeStore(prefix: "legacy_newer_outcome")
        let taskUUID = UUID()
        let localOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 1
        )
        let documentID = try insertOutcome(localOutcome, into: store)

        let incomingOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_200),
            value: 2
        )
        store.mergeRevision(["tasks": [], "outcomes": [try JSONEncoder().encode(incomingOutcome)]])

        XCTAssertEqual(try decodedOutcome(documentID, in: store).values.first?.integerValue, 2)
    }

    func testLegacyMergeSkipsOlderOutcomeRevision() throws {
        let store = try makeStore(prefix: "legacy_older_outcome")
        let taskUUID = UUID()
        let localOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_200),
            value: 2
        )
        let documentID = try insertOutcome(localOutcome, into: store)

        let incomingOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 1
        )
        store.mergeRevision(["tasks": [], "outcomes": [try JSONEncoder().encode(incomingOutcome)]])

        XCTAssertEqual(try decodedOutcome(documentID, in: store).values.first?.integerValue, 2)
    }

    func testLegacyMergeSkipsEqualDatedOutcomeRevision() throws {
        let store = try makeStore(prefix: "legacy_equal_outcome")
        let taskUUID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_200)
        let localOutcome = makeOutcome(taskUUID: taskUUID, updatedDate: date, value: 1)
        let documentID = try insertOutcome(localOutcome, into: store)

        let incomingOutcome = makeOutcome(taskUUID: taskUUID, updatedDate: date, value: 2)
        store.mergeRevision(["tasks": [], "outcomes": [try JSONEncoder().encode(incomingOutcome)]])

        XCTAssertEqual(try decodedOutcome(documentID, in: store).values.first?.integerValue, 1)
    }

    func testLegacyMergeSkipsMalformedDataAndStillAppliesValidRevisions() throws {
        let store = try makeStore(prefix: "legacy_malformed")
        let task = makeTask(
            id: "valid-task",
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            title: "Valid"
        )
        let outcome = makeOutcome(
            taskUUID: UUID(),
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 4
        )
        let outcomeID = try canonicalOutcomeDocumentID(for: outcome)

        store.mergeRevision([
            "tasks": [Data("not-json".utf8), try JSONEncoder().encode(task)],
            "outcomes": [Data("also-not-json".utf8), try JSONEncoder().encode(outcome)]
        ])

        XCTAssertEqual(try decodedTask("valid-task", in: store).title, "Valid")
        XCTAssertEqual(try decodedOutcome(outcomeID, in: store).values.first?.integerValue, 4)
    }

    func testMakeIncrementalSyncPayloadEncodesTasksOutcomesTypedAndLegacyDeletions() throws {
        let store = try makeStore(prefix: "payload_build")
        let task = makeTask(id: "payload-task", updatedDate: Date(timeIntervalSince1970: 1_800_000_100))
        let outcome = makeOutcome(
            taskUUID: task.uuid,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_120),
            value: 3
        )
        let deletion = OTFWatchSyncDeletion(documentID: "payload-task", entityType: .task)

        let payload = try store.makeIncrementalSyncPayload(
            tasks: [task],
            outcomes: [outcome],
            deletions: [deletion],
            deletedDocumentIDs: ["legacy-id"]
        )

        XCTAssertEqual(payload.tasks.count, 1)
        let decodedPayloadTask = try JSONDecoder().decode(OCKTask.self, from: payload.tasks[0])
        XCTAssertEqual(decodedPayloadTask.title, "payload-task")
        XCTAssertEqual(decodedPayloadTask.updatedDate, task.updatedDate)

        XCTAssertEqual(payload.outcomes.count, 1)
        XCTAssertEqual(try JSONDecoder().decode(OCKOutcome.self, from: payload.outcomes[0]).values.first?.integerValue, 3)
        XCTAssertEqual(payload.deletions, [deletion])
        XCTAssertEqual(payload.legacyDeletedDocumentIDs, ["legacy-id"])
        XCTAssertEqual(payload.deletedDocumentIDs, ["payload-task", "legacy-id"])
    }

    func testApplyIncrementalSyncReportsAppliedAndSkippedCountsAcrossTasksOutcomesAndDeletions() throws {
        let store = try makeStore(prefix: "payload_counts")
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        try insertTask(makeTask(id: "updated-task", updatedDate: baseDate, title: "Local"), into: store)
        try insertTask(makeTask(id: "skipped-task", updatedDate: baseDate.addingTimeInterval(300), title: "Local"), into: store)
        try insertTask(makeTask(id: "deleted-task", updatedDate: baseDate, title: "Deleted"), into: store)
        let newOutcome = makeOutcome(taskUUID: UUID(), updatedDate: baseDate, value: 7)

        let payload = try store.makeIncrementalSyncPayload(
            tasks: [
                makeTask(id: "updated-task", updatedDate: baseDate.addingTimeInterval(100), title: "Incoming"),
                makeTask(id: "skipped-task", updatedDate: baseDate.addingTimeInterval(100), title: "Incoming")
            ],
            outcomes: [newOutcome],
            deletions: [OTFWatchSyncDeletion(documentID: "deleted-task", entityType: .task)],
            deletedDocumentIDs: ["unknown-legacy-id"]
        )
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.tasks, 1)
        XCTAssertEqual(result.outcomes, 1)
        XCTAssertEqual(result.deletions, 1)
        XCTAssertEqual(result.skipped, 2)
        XCTAssertEqual(result.skippedDeletions, 0)
        XCTAssertEqual(try decodedTask("updated-task", in: store).title, "Incoming")
        XCTAssertEqual(try decodedTask("skipped-task", in: store).title, "Local")
        XCTAssertNil(try? store.dataStore.getDocumentWithId("deleted-task"))
    }

    func testIncrementalTaskConflictMatrixCountsNewerOlderAndEqual() throws {
        let store = try makeStore(prefix: "task_matrix")
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        try insertTask(makeTask(id: "newer", updatedDate: baseDate, title: "Local"), into: store)
        try insertTask(makeTask(id: "older", updatedDate: baseDate.addingTimeInterval(200), title: "Local"), into: store)
        try insertTask(makeTask(id: "equal", updatedDate: baseDate.addingTimeInterval(300), title: "Local"), into: store)

        let payload = try store.makeIncrementalSyncPayload(tasks: [
            makeTask(id: "newer", updatedDate: baseDate.addingTimeInterval(100), title: "Incoming"),
            makeTask(id: "older", updatedDate: baseDate.addingTimeInterval(100), title: "Incoming"),
            makeTask(id: "equal", updatedDate: baseDate.addingTimeInterval(300), title: "Incoming")
        ])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.tasks, 1)
        XCTAssertEqual(result.skipped, 2)
        XCTAssertEqual(try decodedTask("newer", in: store).title, "Incoming")
        XCTAssertEqual(try decodedTask("older", in: store).title, "Local")
        XCTAssertEqual(try decodedTask("equal", in: store).title, "Local")
    }

    func testIncrementalOutcomeConflictMatrixCountsNewerOlderAndEqual() throws {
        let store = try makeStore(prefix: "outcome_matrix")
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let newerTaskUUID = UUID()
        let olderTaskUUID = UUID()
        let equalTaskUUID = UUID()
        let newerLocalID = try insertOutcome(
            makeOutcome(taskUUID: newerTaskUUID, updatedDate: baseDate, value: 1),
            into: store
        )
        let olderLocalID = try insertOutcome(
            makeOutcome(taskUUID: olderTaskUUID, updatedDate: baseDate.addingTimeInterval(200), value: 2),
            into: store
        )
        let equalLocalID = try insertOutcome(
            makeOutcome(taskUUID: equalTaskUUID, updatedDate: baseDate.addingTimeInterval(300), value: 3),
            into: store
        )

        let payload = try store.makeIncrementalSyncPayload(outcomes: [
            makeOutcome(taskUUID: newerTaskUUID, updatedDate: baseDate.addingTimeInterval(100), value: 10),
            makeOutcome(taskUUID: olderTaskUUID, updatedDate: baseDate.addingTimeInterval(100), value: 20),
            makeOutcome(taskUUID: equalTaskUUID, updatedDate: baseDate.addingTimeInterval(300), value: 30)
        ])
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.outcomes, 1)
        XCTAssertEqual(result.skipped, 2)
        XCTAssertEqual(try decodedOutcome(newerLocalID, in: store).values.first?.integerValue, 10)
        XCTAssertEqual(try decodedOutcome(olderLocalID, in: store).values.first?.integerValue, 2)
        XCTAssertEqual(try decodedOutcome(equalLocalID, in: store).values.first?.integerValue, 3)
    }

    func testTypedTaskDeletionSkipsExistingNonTaskDocumentAndCountsSkippedDeletion() throws {
        let store = try makeStore(prefix: "task_delete_safety")
        let patient = OCKPatient(id: "not-a-task", givenName: "Jane", familyName: "Doe")
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: patient))

        let result = try store.applyIncrementalSync(payload: OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(documentID: "not-a-task", entityType: .task)
        ]))

        XCTAssertEqual(result.deletions, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.skippedDeletions, 1)
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("not-a-task"))
    }

    func testTypedOutcomeDeletionSkipsMismatchedLogicalIdentityAndCountsSkippedDeletion() throws {
        let store = try makeStore(prefix: "outcome_delete_safety")
        let keptTaskUUID = UUID()
        let outcome = makeOutcome(
            taskUUID: keptTaskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_000),
            value: 1
        )
        let documentID = try insertOutcome(outcome, into: store)

        let result = try store.applyIncrementalSync(payload: OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(
                documentID: documentID,
                entityType: .outcome,
                taskUUID: UUID(),
                occurrenceIndex: 0
            )
        ]))

        XCTAssertEqual(result.deletions, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.skippedDeletions, 1)
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId(documentID))
    }

    func testLegacyOutcomeDeletionIDDeletesCanonicalAndLegacyDuplicates() throws {
        let store = try makeStore(prefix: "legacy_outcome_delete")
        let patient = OCKPatient(id: "must-stay", givenName: "Jane", familyName: "Doe")
        let outcome = makeOutcome(
            taskUUID: UUID(),
            updatedDate: Date(timeIntervalSince1970: 1_800_000_000),
            value: 1
        )
        let canonicalID = try insertOutcome(outcome, into: store)
        try store.dataStore.createDocument(from: outcomeRevision(outcome, documentID: "legacy-outcome"))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: patient))

        let result = try store.applyIncrementalSync(payload: OTFWatchSyncPayload(
            deletedDocumentIDs: [canonicalID]
        ))

        XCTAssertEqual(result.deletions, 2)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertNil(try? store.dataStore.getDocumentWithId(canonicalID))
        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-outcome"))
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("must-stay"))
    }

    func testMalformedOutcomeDeletionRequestIsSkippedAndCounted() throws {
        let store = try makeStore(prefix: "malformed_outcome_delete")
        let documentID = "11111111-1111-1111-1111-111111111111_0"
        try insertMalformedOutcomeDocument(documentID: documentID, into: store)

        let result = try store.applyIncrementalSync(payload: OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(documentID: documentID, entityType: .outcome)
        ]))

        XCTAssertEqual(result.deletions, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.skippedDeletions, 1)
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId(documentID))
    }

    func testPruneStaleOutcomeDocumentsMigratesLegacyWinnerToCanonicalDocumentID() throws {
        let store = try makeStore(prefix: "prune_migrate")
        let outcome = makeOutcome(
            taskUUID: UUID(),
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 5
        )
        let canonicalID = try canonicalOutcomeDocumentID(for: outcome)
        try store.dataStore.createDocument(from: outcomeRevision(outcome, documentID: "legacy-winner"))

        XCTAssertEqual(store.pruneStaleOutcomeDocuments(), 2)

        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-winner"))
        XCTAssertEqual(try decodedOutcome(canonicalID, in: store).id, canonicalID)
    }

    func testPruneStaleOutcomeDocumentsDeletesOlderDuplicateAndKeepsCanonicalWinner() throws {
        let store = try makeStore(prefix: "prune_duplicate")
        let taskUUID = UUID()
        let olderOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_000),
            value: 1
        )
        let newerOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 2
        )
        let canonicalID = try insertOutcome(newerOutcome, into: store)
        try store.dataStore.createDocument(from: outcomeRevision(olderOutcome, documentID: "legacy-older"))

        XCTAssertEqual(store.pruneStaleOutcomeDocuments(), 1)

        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-older"))
        XCTAssertEqual(try decodedOutcome(canonicalID, in: store).values.first?.integerValue, 2)
    }

    func testPruneStaleOutcomeDocumentsDeletesSoftDeletedWinnerAndDuplicates() throws {
        let store = try makeStore(prefix: "prune_deleted")
        let taskUUID = UUID()
        let activeOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_000),
            value: 1
        )
        let deletedOutcome = makeOutcome(
            taskUUID: taskUUID,
            updatedDate: Date(timeIntervalSince1970: 1_800_000_100),
            value: 2,
            deletedDate: Date(timeIntervalSince1970: 1_800_000_200)
        )
        let canonicalID = try insertOutcome(deletedOutcome, into: store)
        try store.dataStore.createDocument(from: outcomeRevision(activeOutcome, documentID: "legacy-active"))

        XCTAssertEqual(store.pruneStaleOutcomeDocuments(), 2)

        XCTAssertNil(try? store.dataStore.getDocumentWithId(canonicalID))
        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-active"))
    }

    func testBackfillTaskDateMetadataSkipsAlreadyBackfilledTasks() throws {
        let store = try makeStore(prefix: "backfill_skip")
        let task = makeTask(
            id: "already-backfilled",
            updatedDate: Date(timeIntervalSince1970: 1_800_000_000),
            end: Date(timeIntervalSince1970: 1_800_086_400)
        )
        try insertTask(task, into: store)

        XCTAssertEqual(store.backfillTaskDateMetadataIfNeeded(), 0)
    }

    func testBackfillTaskDateMetadataBackfillsOnlyMissingFields() throws {
        let store = try makeStore(prefix: "backfill_partial")
        let task = makeTask(
            id: "missing-start",
            updatedDate: Date(timeIntervalSince1970: 1_800_000_000),
            end: Date(timeIntervalSince1970: 1_800_086_400)
        )
        try insertBackendStyleTask(
            task,
            documentID: "missing-start",
            into: store,
            removingFields: [PropertyKey.startDate]
        )
        let beforeBody = try XCTUnwrap(try store.dataStore.getDocumentWithId("missing-start").body as? [String: Any])
        let originalEndDate = beforeBody[PropertyKey.endDate] as? String

        XCTAssertEqual(store.backfillTaskDateMetadataIfNeeded(), 1)

        let afterBody = try XCTUnwrap(try store.dataStore.getDocumentWithId("missing-start").body as? [String: Any])
        XCTAssertNotNil(afterBody[PropertyKey.startDate])
        XCTAssertEqual(afterBody[PropertyKey.endDate] as? String, originalEndDate)
    }
}

final class SynchronizationDelegateNotificationTests: Phase2CareHealthTestCase {

    func testApplyIncrementalSyncNotifiesTaskDelegateForAddedUpdatedAndDeletedTasksOnce() throws {
        let store = try makeStore(prefix: "task_delegate")
        let delegate = Phase2TaskDelegateSpy()
        store.taskDelegate = delegate
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        try insertTask(makeTask(id: "updated", updatedDate: baseDate, title: "Local"), into: store)
        try insertTask(makeTask(id: "deleted", updatedDate: baseDate, title: "Deleted"), into: store)

        let payload = try store.makeIncrementalSyncPayload(
            tasks: [
                makeTask(id: "added", updatedDate: baseDate, title: "Added"),
                makeTask(id: "updated", updatedDate: baseDate.addingTimeInterval(100), title: "Updated")
            ],
            deletions: [OTFWatchSyncDeletion(documentID: "deleted", entityType: .task)]
        )
        _ = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(delegate.addedTaskIDs, ["added"])
        XCTAssertEqual(delegate.updatedTaskIDs, ["updated"])
        XCTAssertEqual(delegate.deletedTaskIDs, ["deleted"])
    }

    func testApplyIncrementalSyncNotifiesOutcomeDelegateForAddedUpdatedAndDeletedOutcomesOnce() throws {
        let store = try makeStore(prefix: "outcome_delegate")
        let delegate = Phase2OutcomeDelegateSpy()
        store.outcomeDelegate = delegate
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let updatedTaskUUID = UUID()
        let deletedTaskUUID = UUID()
        let addedOutcome = makeOutcome(taskUUID: UUID(), updatedDate: baseDate, value: 1)
        let updatedOutcome = makeOutcome(
            taskUUID: updatedTaskUUID,
            updatedDate: baseDate.addingTimeInterval(100),
            value: 3
        )
        let deletedOutcome = makeOutcome(taskUUID: deletedTaskUUID, updatedDate: baseDate, value: 4)
        let updatedDocumentID = try insertOutcome(
            makeOutcome(taskUUID: updatedTaskUUID, updatedDate: baseDate, value: 2),
            into: store
        )
        let deletedDocumentID = try insertOutcome(deletedOutcome, into: store)
        let addedDocumentID = try canonicalOutcomeDocumentID(for: addedOutcome)

        let payload = try store.makeIncrementalSyncPayload(
            outcomes: [addedOutcome, updatedOutcome],
            deletions: [OTFWatchSyncDeletion(documentID: deletedDocumentID, entityType: .outcome)]
        )
        _ = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(delegate.addedOutcomeIDs, [addedDocumentID])
        XCTAssertEqual(delegate.updatedOutcomeIDs, [updatedDocumentID])
        XCTAssertEqual(delegate.deletedOutcomeIDs, [deletedDocumentID])
    }

    func testApplyIncrementalSyncDoesNotNotifyDelegatesForSkippedOlderOrMalformedDocuments() throws {
        let store = try makeStore(prefix: "delegate_skips")
        let taskDelegate = Phase2TaskDelegateSpy()
        let outcomeDelegate = Phase2OutcomeDelegateSpy()
        store.taskDelegate = taskDelegate
        store.outcomeDelegate = outcomeDelegate
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        try insertTask(makeTask(id: "skipped-task", updatedDate: baseDate.addingTimeInterval(100), title: "Local"), into: store)
        try insertMalformedOutcomeDocument(
            documentID: "11111111-1111-1111-1111-111111111111_0",
            into: store
        )

        let payload = try store.makeIncrementalSyncPayload(
            tasks: [makeTask(id: "skipped-task", updatedDate: baseDate, title: "Incoming")],
            deletions: [
                OTFWatchSyncDeletion(
                    documentID: "11111111-1111-1111-1111-111111111111_0",
                    entityType: .outcome
                )
            ]
        )
        _ = try store.applyIncrementalSync(payload: payload)

        XCTAssertTrue(taskDelegate.addedTaskIDs.isEmpty)
        XCTAssertTrue(taskDelegate.updatedTaskIDs.isEmpty)
        XCTAssertTrue(taskDelegate.deletedTaskIDs.isEmpty)
        XCTAssertTrue(outcomeDelegate.addedOutcomeIDs.isEmpty)
        XCTAssertTrue(outcomeDelegate.updatedOutcomeIDs.isEmpty)
        XCTAssertTrue(outcomeDelegate.deletedOutcomeIDs.isEmpty)
    }
}

private final class Phase2TaskDelegateSpy: OCKTaskStoreDelegate {
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

private final class Phase2OutcomeDelegateSpy: OCKOutcomeStoreDelegate {
    var addedOutcomeIDs = [String]()
    var updatedOutcomeIDs = [String]()
    var deletedOutcomeIDs = [String]()
    var unknownChanges = [String]()

    func outcomeStore(_ store: OCKAnyReadOnlyOutcomeStore, didAddOutcomes outcomes: [OCKAnyOutcome]) {
        addedOutcomeIDs.append(contentsOf: outcomes.map(\.id))
    }

    func outcomeStore(_ store: OCKAnyReadOnlyOutcomeStore, didUpdateOutcomes outcomes: [OCKAnyOutcome]) {
        updatedOutcomeIDs.append(contentsOf: outcomes.map(\.id))
    }

    func outcomeStore(_ store: OCKAnyReadOnlyOutcomeStore, didDeleteOutcomes outcomes: [OCKAnyOutcome]) {
        deletedOutcomeIDs.append(contentsOf: outcomes.map(\.id))
    }

    func outcomeStore(_ store: OCKAnyReadOnlyOutcomeStore, didEncounterUnknownChange change: String) {
        unknownChanges.append(change)
    }
}
#endif
