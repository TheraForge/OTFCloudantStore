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

import Foundation
import OTFCDTDatastore
import WatchConnectivity
import XCTest

@testable import OTFCloudantStore

#if CARE && HEALTH
import HealthKit
import OTFCareKitStore
#endif

final class InternalTestSeamTests: XCTestCase {

    private var temporaryDirectories = [URL]()
    private var storesToDelete = [(manager: CDTDatastoreManager, name: String)]()

    override func tearDownWithError() throws {
        CloudantStoreKey.resetDefaultValueProvider()

        for store in storesToDelete {
            try? store.manager.deleteDatastoreNamed(store.name)
        }
        storesToDelete.removeAll()

        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()

        try super.tearDownWithError()
    }

    func testStoreInternalInitializerUsesInjectedDatastoreAndSkipsIndexBootstrap() throws {
        let manager = try makeDatastoreManager()
        let storeName = uniqueStoreName(prefix: "bootstrap")
        let datastore = try manager.datastoreNamed(storeName)
        storesToDelete.append((manager, storeName))

        let indexCountBeforeInit = datastore.listIndexes().count
        let store = OTFCloudantStore(
            storeName: storeName,
            remote: nil,
            datastoreManager: manager,
            dataStore: datastore,
            indexBootstrap: .skip
        )

        XCTAssertEqual(store.storeName, storeName)
        XCTAssertTrue(store.datastoreManager === manager)
        XCTAssertTrue(store.dataStore === datastore)
        XCTAssertEqual(datastore.listIndexes().count, indexCountBeforeInit)
    }

    func testWatchConnectivityPeerPublicInitRemainsSubclassDesignatedInitializerCompatible() {
        let peer = SubclassDesignatedInitializerPeer(label: "subclass")

        XCTAssertEqual(peer.label, "subclass")
    }

    func testWatchSessionSeamSendsReachableIncrementalPayload() throws {
        let session = FakeWatchSession()
        session.isReachable = true
        session.sendMessageReply = [
            OTFWatchConnectivityMessageKey.revisionPushResult: [
                "skippedDeletions": 0
            ]
        ]
        let peer = OTFWatchConnectivityPeer(session: session)
        let payload = OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(documentID: "task-id", entityType: .task)
        ])

        let result = waitForIncrementalDelivery(peer: peer, payload: payload)

        XCTAssertEqual(try result.get(), .delivered)
        XCTAssertEqual(session.sentMessages.count, 1)
        XCTAssertEqual(session.transferredUserInfoMessages.count, 0)
        XCTAssertNotNil(session.sentMessages[0][OTFWatchConnectivityMessageKey.incrementalRevisionPush])
    }

    func testWatchSessionSeamQueuesUnreachableIncrementalPayload() throws {
        let session = FakeWatchSession()
        session.isReachable = false
        let peer = OTFWatchConnectivityPeer(session: session)
        let payload = OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(documentID: "task-id", entityType: .task)
        ])

        let result = waitForIncrementalDelivery(peer: peer, payload: payload)

        XCTAssertEqual(try result.get(), .queued)
        XCTAssertEqual(session.sentMessages.count, 0)
        XCTAssertEqual(session.transferredUserInfoMessages.count, 1)
        XCTAssertNotNil(session.transferredUserInfoMessages[0][OTFWatchConnectivityMessageKey.incrementalRevisionPush])
    }

    func testWatchSessionSeamReportsActivationValidationFailure() {
        let session = FakeWatchSession()
        session.activationState = .notActivated
        let peer = OTFWatchConnectivityPeer(session: session)
        let payload = OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(documentID: "task-id", entityType: .task)
        ])

        let result = waitForIncrementalDelivery(peer: peer, payload: payload)

        switch result {
        case .success(let outcome):
            XCTFail("Expected activation failure, got \(outcome)")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("has not been activated"))
        }
        XCTAssertEqual(session.sentMessages.count, 0)
        XCTAssertEqual(session.transferredUserInfoMessages.count, 0)
    }

    func testWatchSessionSeamFallsBackToQueuedDeliveryWhenSendReportsNotReachable() throws {
        let session = FakeWatchSession()
        session.isReachable = true
        session.sendMessageError = NSError(
            domain: WCErrorDomain,
            code: WCError.Code.notReachable.rawValue
        )
        let peer = OTFWatchConnectivityPeer(session: session)
        let payload = OTFWatchSyncPayload(deletions: [
            OTFWatchSyncDeletion(documentID: "task-id", entityType: .task)
        ])

        let result = waitForIncrementalDelivery(peer: peer, payload: payload)

        XCTAssertEqual(try result.get(), .queued)
        XCTAssertEqual(session.sentMessages.count, 1)
        XCTAssertEqual(session.transferredUserInfoMessages.count, 1)
        XCTAssertNotNil(session.transferredUserInfoMessages[0][OTFWatchConnectivityMessageKey.incrementalRevisionPush])
    }

    func testWatchPeerPullRevisionsSendsLegacyRevisionRequestAndMergesReply() {
        let session = FakeWatchSession()
        session.sendMessageReply = [
            "OCKPeerRevisionReply": [
                "tasks": [Data("{}".utf8)],
                "outcomes": []
            ]
        ]
        let peer = OTFWatchConnectivityPeer(session: session)
        let expectation = expectation(description: "pull revisions")
        var mergedRevision: [String: [Data]]?
        var receivedError: Error?

        peer.pullRevisions { revision in
            mergedRevision = revision
        } completion: { error in
            receivedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        XCTAssertNil(receivedError)
        XCTAssertEqual(session.sentMessages.count, 1)
        XCTAssertEqual(session.sentMessages[0]["OCKPeerRevisionRequest"] as? String, "Sending pull request from watch App")
        XCTAssertEqual(mergedRevision?["tasks"]?.count, 1)
    }

    func testWatchPeerPullRevisionsFailsWhenReplyDoesNotContainRevision() {
        let session = FakeWatchSession()
        session.sendMessageReply = [:]
        let peer = OTFWatchConnectivityPeer(session: session)
        let expectation = expectation(description: "pull revisions")
        var mergeCallCount = 0
        var receivedError: Error?

        peer.pullRevisions { _ in
            mergeCallCount += 1
        } completion: { error in
            receivedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        XCTAssertEqual(mergeCallCount, 0)
        XCTAssertNotNil(receivedError)
        XCTAssertTrue(receivedError?.localizedDescription.contains("No Tasks for today") == true)
    }

    func testWatchPeerPushRevisionsFailsWhenReplyContainsRevisionError() {
        let session = FakeWatchSession()
        session.sendMessageReply = [
            OTFWatchConnectivityMessageKey.revisionError: "legacy push rejected"
        ]
        let peer = OTFWatchConnectivityPeer(session: session)
        let expectation = expectation(description: "push revisions")
        var receivedError: Error?

        peer.pushRevisions { error in
            receivedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        XCTAssertEqual(session.sentMessages.count, 1)
        XCTAssertEqual(session.sentMessages[0]["OCKPeerRevisionPush"] as? String, "Sending push request from mobile app")
        XCTAssertTrue(receivedError?.localizedDescription.contains("legacy push rejected") == true)
    }

    func testNetworkSessionSeamResumesTaskAndReturnsData() throws {
        let expectedData = Data("ok".utf8)
        let session = FakeURLSession(data: expectedData)
        let network = OTFNetwork(session: session, baseURL: "https://example.com")
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/status")))

        let result: Result<Data, Error> = waitForNetworkResult { completion in
            network.sendRequest(urlRequest: request, completionBlOTF: completion)
        }

        XCTAssertEqual(session.requests, [request])
        XCTAssertEqual(session.tasks.first?.resumeCallCount, 1)
        XCTAssertEqual(try result.get(), expectedData)
    }

    func testNetworkSessionSeamPropagatesError() throws {
        let expectedError = NSError(domain: "network.seam", code: 42)
        let session = FakeURLSession(error: expectedError)
        let network = OTFNetwork(session: session, baseURL: "https://example.com")
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/status")))

        let result: Result<Data, Error> = waitForNetworkResult { completion in
            network.sendRequest(urlRequest: request, completionBlOTF: completion)
        }

        XCTAssertEqual(session.tasks.first?.resumeCallCount, 1)
        switch result {
        case .success(let data):
            XCTFail("Expected error, got \(data)")
        case .failure(let error as NSError):
            XCTAssertEqual(error.domain, expectedError.domain)
            XCTAssertEqual(error.code, expectedError.code)
        }
    }

    func testNetworkSessionSeamDecodesJsonResultThroughFakeSession() throws {
        let expectedData = try JSONEncoder().encode(NetworkFixture(value: "decoded"))
        let session = FakeURLSession(data: expectedData)
        let network = OTFNetwork(session: session, baseURL: "https://example.com")
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/status")))

        let result: Result<NetworkFixture, Error> = waitForNetworkResult { completion in
            network.sendJsonResultRequest(urlRequest: request, result: completion)
        }

        XCTAssertEqual(session.tasks.first?.resumeCallCount, 1)
        XCTAssertEqual(try result.get(), NetworkFixture(value: "decoded"))
    }

    func testStoreServiceUsesInjectedFactoryWithLocalDBNameAndPeer() throws {
        let peer = OTFWatchConnectivityPeer(session: FakeWatchSession())
        var receivedStoreName: String?
        var receivedPeer: OTFWatchConnectivityPeer?
        let service = StoreService { storeName, factoryPeer in
            receivedStoreName = storeName
            receivedPeer = factoryPeer
            return try self.makeStoreBackedByTempDatastore(prefix: "store_service")
        }

        let store = try service.currentStore(peer: peer)

        XCTAssertEqual(receivedStoreName, "local_db")
        XCTAssertTrue(receivedPeer === peer)
        XCTAssertTrue(storesToDelete.contains { $0.name == store.storeName })
    }

    func testCloudantStoreKeyDefaultValueUsesInjectedProviderAndCachesResult() throws {
        let expectedStore = try makeStoreBackedByTempDatastore(prefix: "environment_default")
        var providerCallCount = 0
        CloudantStoreKey.defaultValueProvider = {
            providerCallCount += 1
            return expectedStore
        }

        let firstDefaultStore = CloudantStoreKey.defaultValue
        let secondDefaultStore = CloudantStoreKey.defaultValue

        XCTAssertTrue(firstDefaultStore === expectedStore)
        XCTAssertTrue(secondDefaultStore === expectedStore)
        XCTAssertEqual(providerCallCount, 1)
    }

    func testCloudantStoreKeyDefaultValueProviderInjectionClearsCachedResult() throws {
        let firstStore = try makeStoreBackedByTempDatastore(prefix: "environment_first")
        let secondStore = try makeStoreBackedByTempDatastore(prefix: "environment_second")
        CloudantStoreKey.defaultValueProvider = { firstStore }

        XCTAssertTrue(CloudantStoreKey.defaultValue === firstStore)

        CloudantStoreKey.defaultValueProvider = { secondStore }

        XCTAssertTrue(CloudantStoreKey.defaultValue === secondStore)
    }

    private func makeDatastoreManager() throws -> CDTDatastoreManager {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("otfcloudant_phase1_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return try CDTDatastoreManager(directory: directory.path)
    }

    private func makeStoreBackedByTempDatastore(prefix: String) throws -> OTFCloudantStore {
        let manager = try makeDatastoreManager()
        let storeName = uniqueStoreName(prefix: prefix)
        let datastore = try manager.datastoreNamed(storeName)
        storesToDelete.append((manager, storeName))
        return OTFCloudantStore(
            storeName: storeName,
            remote: nil,
            datastoreManager: manager,
            dataStore: datastore,
            indexBootstrap: .skip
        )
    }

    private func uniqueStoreName(prefix: String) -> String {
        let suffix = UUID().uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return "\(prefix)_\(suffix)"
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

        waitForExpectations(timeout: 1)
        return receivedResult ?? .failure(NSError(domain: "internal.test.seams", code: -1))
    }

    private func waitForNetworkResult<T>(
        _ work: (@escaping (Result<T, Error>) -> Void) -> Void
    ) -> Result<T, Error> {
        let expectation = expectation(description: "wait for network result")
        var receivedResult: Result<T, Error>?

        work { result in
            receivedResult = result
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        return receivedResult ?? .failure(NSError(domain: "internal.test.seams", code: -2))
    }
}

private struct NetworkFixture: Codable, Equatable {
    let value: String
}

private final class SubclassDesignatedInitializerPeer: OTFWatchConnectivityPeer {
    let label: String

    init(label: String) {
        self.label = label
        super.init()
    }
}

private final class FakeWatchSession: WatchSessioning {
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

private final class FakeURLSessionTask: URLSessionDataTasking {
    private let onResume: () -> Void
    private(set) var resumeCallCount = 0

    init(onResume: @escaping () -> Void) {
        self.onResume = onResume
    }

    func resume() {
        resumeCallCount += 1
        onResume()
    }
}

private final class FakeURLSession: URLSessioning {
    private let data: Data?
    private let response: URLResponse?
    private let error: Error?
    private(set) var requests = [URLRequest]()
    private(set) var tasks = [FakeURLSessionTask]()

    init(data: Data? = nil, response: URLResponse? = nil, error: Error? = nil) {
        self.data = data
        self.response = response
        self.error = error
    }

    func makeDataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTasking {
        requests.append(request)
        let task = FakeURLSessionTask { [data, response, error] in
            completionHandler(data, response, error)
        }
        tasks.append(task)
        return task
    }
}

#if HEALTH
extension InternalTestSeamTests {

    func testCloudantQuerySnapshotExposesSelectorSortLimitSkipAndFieldsWithoutExecutingFind() throws {
        let store = try makeStoreBackedByTempDatastore(prefix: "query_snapshot")
        let query = OTFCloudantQuery(
            store: store,
            careKitClassName: "OCKTask",
            fields: ["id", "title"]
        )
        .where("id", isEqualTo: "task-id")
        .where(field: "tags", in: ["a", "b"])
        .sort(ascendingBy: "createdDate")
        .sort(descendingBy: "updatedDate")
        .limit(limit: 5)
        .skip(skip: 2)

        let snapshot = query.snapshot

        XCTAssertEqual(snapshot.selector["entityType"] as? String, "OCKTask")
        XCTAssertEqual(snapshot.selector["id"] as? String, "task-id")
        let tagSelector = snapshot.selector["tags"] as? [String: [String]]
        XCTAssertEqual(tagSelector?["$in"], ["a", "b"])
        XCTAssertEqual(snapshot.sortDescriptors, [["createdDate": "asc"], ["updatedDate": "desc"]])
        XCTAssertEqual(snapshot.limit, 5)
        XCTAssertEqual(snapshot.skip, 2)
        XCTAssertEqual(snapshot.fields, ["id", "title"])
    }

    func testCloudantQuerySnapshotCapturesCompoundSelectorShape() throws {
        let store = try makeStoreBackedByTempDatastore(prefix: "query_compound_shape")
        let query = OTFCloudantQuery(
            store: store,
            careKitClassName: "QuerySortEntity",
            fields: ["first", "second"]
        )
            .where(firstCondition: ["first": "a"], and: ["second": ["$gt": "1"]])
            .ordered(by: "first", ascending: true)
            .limit(limit: 3)
            .skip(skip: 2)

        let snapshot = query.snapshot

        XCTAssertEqual(snapshot.limit, 3)
        XCTAssertEqual(snapshot.skip, 2)
        XCTAssertEqual(snapshot.fields, ["first", "second"])
        XCTAssertEqual(snapshot.sortDescriptors, [["first": "asc"]])
        let conditions = snapshot.selector["$and"] as? [[String: Any]]
        XCTAssertEqual(conditions?.count, 2)
        XCTAssertEqual(conditions?.first?["first"] as? String, "a")
        XCTAssertEqual((conditions?.last?["second"] as? [String: String])?["$gt"], "1")
    }

    func testCloudantQueryChainedOperatorsUseExpectedSelectorSyntax() throws {
        let store = try makeStoreBackedByTempDatastore(prefix: "query_operators")
        let query = try OTFCloudantQuery(store: store, careKitClassName: "QueryEntity")
            .where("id", isEqualTo: "entity-1")
            .where("priority", isLessThan: "5")
            .where("score", isLessThanOrEquaTo: "10")
            .where("rank", isGreeterThan: "1")
            .where("updated", isGreeterThanOrEqualTo: "2024-01-01T00:00:00Z")
            .where("owner", notEqualTo: "archived")
            .where(field: "tags", in: ["daily", "watch"])
            .where(field: "excludedTags", notIn: ["deleted"])
            .where(field: "deletedDate", exists: false)
            .where(field: "shard", mode: 2, equal: 0)
            .where(field: "values", hasSize: 3)

        let selector = query.snapshot.selector

        XCTAssertEqual(selector["entityType"] as? String, "QueryEntity")
        XCTAssertEqual(selector["id"] as? String, "entity-1")
        XCTAssertEqual((selector["priority"] as? [String: String])?["$lt"], "5")
        XCTAssertEqual((selector["score"] as? [String: String])?["$lte"], "10")
        XCTAssertEqual((selector["rank"] as? [String: String])?["$gt"], "1")
        XCTAssertEqual((selector["updated"] as? [String: String])?["$gte"], "2024-01-01T00:00:00Z")
        XCTAssertEqual((selector["owner"] as? [String: String])?["$ne"], "archived")
        XCTAssertNil((selector["owner"] as? [String: String])?["$neq"])
        XCTAssertEqual((selector["tags"] as? [String: [String]])?["$in"], ["daily", "watch"])
        XCTAssertEqual((selector["excludedTags"] as? [String: [String]])?["$nin"], ["deleted"])
        XCTAssertEqual((selector["deletedDate"] as? [String: Bool])?["$exists"], false)
        XCTAssertEqual((selector["shard"] as? [String: [Int]])?["$mod"], [2, 0])
        XCTAssertEqual((selector["values"] as? [String: Int])?["$size"], 3)
    }

    func testCloudantQueryMergesComponentSelectorsWithExistingSelectors() throws {
        let store = try makeStoreBackedByTempDatastore(prefix: "query_components")
        let status = OTFCloudantQueryComponent.simpleComponent("status", .equal, "open")
        let owner = OTFCloudantQueryComponent.simpleComponent("owner", .notEqualTo, "archived")
        let combined = OTFCloudantCombinationQueryComponent.combinedQueryComponent(status, .and, owner)

        let query = OTFCloudantQuery(store: store, careKitClassName: "QueryEntity")
            .where("id", isEqualTo: "entity-1")
            .where(query: combined)

        let selector = query.snapshot.selector
        XCTAssertEqual(selector["entityType"] as? String, "QueryEntity")
        XCTAssertEqual(selector["id"] as? String, "entity-1")
        let combinedSelector = selector["$and"] as? [[String: Any]]
        XCTAssertEqual(combinedSelector?.count, 2)
        XCTAssertEqual(
            NSDictionary(dictionary: combinedSelector?[0] ?? [:]),
            NSDictionary(dictionary: ["status": ["$eq": "open"]])
        )
        XCTAssertEqual(
            NSDictionary(dictionary: combinedSelector?[1] ?? [:]),
            NSDictionary(dictionary: ["owner": ["$ne": "archived"]])
        )
    }

    func testCloudantQueryAllowsSameDirectionIndexedSorts() throws {
        let store = try makeStoreBackedByTempDatastore(prefix: "query_same_sort")
        _ = store.dataStore.ensureIndexed(["first", "second"], withName: "query_same_sort_index")

        let query = OTFCloudantQuery(store: store, careKitClassName: "QuerySortEntity")
            .sort(ascendingBy: "first")
            .sort(ascendingBy: "second")

        let result: Result<[QuerySortEntity], OTFCloudantError> = waitForCloudantQueryResult("same direction sort") { completion in
            query.get(callbackQueue: DispatchQueue(label: "phase4.same.sort"), completion: completion)
        }

        switch result {
        case .success(let entities):
            XCTAssertEqual(entities, [])
        case .failure(let error):
            XCTFail("Expected same-direction indexed sorts to be allowed, got \(error)")
        }
    }

    func testCloudantQueryRejectsMixedDirectionSortsWithValidationError() throws {
        let store = try makeStoreBackedByTempDatastore(prefix: "query_mixed_sort")
        _ = store.dataStore.ensureIndexed(["first", "second"], withName: "query_mixed_sort_index")

        let query = OTFCloudantQuery(store: store, careKitClassName: "QuerySortEntity")
            .sort(ascendingBy: "first")
            .sort(descendingBy: "second")

        let result: Result<[QuerySortEntity], OTFCloudantError> = waitForCloudantQueryResult("mixed direction sort") { completion in
            query.get(callbackQueue: DispatchQueue(label: "phase4.mixed.sort"), completion: completion)
        }

        guard case .failure(.fetchFailed(let reason)) = result else {
            return XCTFail("Expected mixed sort validation failure, got \(result)")
        }
        XCTAssertTrue(reason.contains("same order"))
    }

    func testCloudantQueryRejectsZeroModDivisor() throws {
        let store = try makeStoreBackedByTempDatastore(prefix: "query_mod")

        XCTAssertThrowsError(try OTFCloudantQuery(store: store, careKitClassName: "QueryEntity")
            .where(field: "shard", mode: 0, equal: 0)) { error in
            guard case OTFCloudantError.invalidValue(let reason) = error else {
                return XCTFail("Expected invalidValue, got \(error)")
            }
            XCTAssertEqual(reason, "Divisor cannot be zero")
        }
    }

    private func waitForCloudantQueryResult<T>(
        _ description: String,
        work: (@escaping (Result<T, OTFCloudantError>) -> Void) -> Void
    ) -> Result<T, OTFCloudantError> {
        let expectation = expectation(description: description)
        var receivedResult: Result<T, OTFCloudantError>?

        work { result in
            receivedResult = result
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        return receivedResult ?? .failure(.timedOut(reason: "No callback for \(description)"))
    }
}

private struct QuerySortEntity: Codable, Identifiable, OTFCloudantRevision, Equatable {
    let id: String
    var revId: String?
    let entityType: String
    let first: String
    let second: String
}
#endif

#if CARE && HEALTH
extension InternalTestSeamTests {

    func testWatchSyncApplierCountsAppliedAndSkippedDocuments() throws {
        let store = try makeCareHealthStore(prefix: "sync_applier")
        var localTask = makeTask(id: "existing", updatedDate: Date(timeIntervalSince1970: 1_800_000_200))
        localTask.title = "Local"
        var olderIncomingTask = makeTask(id: "existing", updatedDate: Date(timeIntervalSince1970: 1_800_000_100))
        olderIncomingTask.title = "Older Incoming"
        let newTask = makeTask(id: "new", updatedDate: Date(timeIntervalSince1970: 1_800_000_300))

        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: localTask))
        let payload = OTFWatchSyncPayload(tasks: [
            try JSONEncoder().encode(olderIncomingTask),
            try JSONEncoder().encode(newTask)
        ])

        let result = try OTFWatchSyncApplier(store: store).apply(payload: payload)

        XCTAssertEqual(result.tasks, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertNoThrow(try store.dataStore.getDocumentWithId("new"))
        let storedExisting = try XCTUnwrap(store.dataStore.getDocumentWithId("existing").data(as: OCKTask.self))
        XCTAssertEqual(storedExisting.title, "Local")
    }

    func testStoreApplyIncrementalSyncDelegatesToInternalApplier() throws {
        let store = try makeCareHealthStore(prefix: "sync_wrapper")
        let deletedTask = makeTask(id: "deleted", updatedDate: Date(timeIntervalSince1970: 1_800_000_100))
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: deletedTask))

        let payload = OTFWatchSyncPayload(
            deletions: [OTFWatchSyncDeletion(documentID: "deleted", entityType: .task)]
        )
        let result = try store.applyIncrementalSync(payload: payload)

        XCTAssertEqual(result.deletions, 1)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertNil(try? store.dataStore.getDocumentWithId("deleted"))
    }

    func testHealthKitSynchronizerAddsHealthKitSamplesToCloudantThroughSeams() throws {
        let sampleType = try XCTUnwrap(HKObjectType.quantityType(forIdentifier: .stepCount))
        let sample = makeQuantitySample(type: sampleType, value: 12)
        let healthKitClient = FakeHealthKitClient(samples: [sample])
        let cloudantStore = FakeCloudantSampleStore(samples: [])
        let synchronizer = OTFHealthKitSynchronizer(
            healthKitClient: healthKitClient,
            cloudantSampleStore: cloudantStore,
            sampleTypes: [sampleType]
        )

        waitForHealthKitSync(synchronizer, direction: .fromHKToCloudant, type: sampleType)

        XCTAssertEqual(healthKitClient.fetchedTypes, [sampleType])
        XCTAssertEqual(cloudantStore.addedSamples.count, 1)
        XCTAssertEqual(cloudantStore.addedSamples[0].uuid, sample.uuid)
        XCTAssertEqual(cloudantStore.addedSamples[0].typeIdentifier, sampleType.identifier)
        XCTAssertEqual(healthKitClient.savedSamples.count, 0)
    }

    func testHealthKitSynchronizerSavesCloudantSamplesToHealthKitThroughSeams() throws {
        let sampleType = try XCTUnwrap(HKObjectType.quantityType(forIdentifier: .stepCount))
        let sample = makeQuantitySample(type: sampleType, value: 22)
        let cloudantSample = OTFCloudantSample(sample: sample, patientId: "")
        let healthKitClient = FakeHealthKitClient(samples: [])
        let cloudantStore = FakeCloudantSampleStore(samples: [cloudantSample])
        let synchronizer = OTFHealthKitSynchronizer(
            healthKitClient: healthKitClient,
            cloudantSampleStore: cloudantStore,
            sampleTypes: [sampleType]
        )

        waitForHealthKitSync(synchronizer, direction: .fromCloudantToHK, type: sampleType)

        XCTAssertEqual(healthKitClient.fetchedTypes, [sampleType])
        XCTAssertEqual(healthKitClient.savedSamples.count, 1)
        XCTAssertEqual(cloudantStore.addedSamples.count, 0)
    }

    private func makeCareHealthStore(prefix: String) throws -> OTFCloudantStore {
        let manager = try makeDatastoreManager()
        let storeName = uniqueStoreName(prefix: prefix)
        let datastore = try manager.datastoreNamed(storeName)
        storesToDelete.append((manager, storeName))
        return OTFCloudantStore(
            storeName: storeName,
            remote: nil,
            datastoreManager: manager,
            dataStore: datastore,
            indexBootstrap: .skip
        )
    }

    private func makeTask(id: String, updatedDate: Date) -> OCKTask {
        let schedule = OCKSchedule.dailyAtTime(
            hour: 8,
            minutes: 0,
            start: Date(timeIntervalSince1970: 1_800_000_000),
            end: nil,
            text: nil
        )
        var task = OCKTask(id: id, title: id, carePlanUUID: nil, schedule: schedule)
        task.createdDate = updatedDate.addingTimeInterval(-60)
        task.updatedDate = updatedDate
        return task
    }

    private func makeQuantitySample(type: HKQuantityType, value: Double) -> HKQuantitySample {
        HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .count(), doubleValue: value),
            start: Date(timeIntervalSince1970: 1_800_001_000),
            end: Date(timeIntervalSince1970: 1_800_001_060)
        )
    }

    private func waitForHealthKitSync(
        _ synchronizer: OTFHealthKitSynchronizer,
        direction: OTFSyncDirection,
        type: HKSampleType
    ) {
        let expectation = expectation(description: "wait for HealthKit sync")

        synchronizer.syncWithHealthKit(direction: direction, type: type) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}

private final class FakeHealthKitClient: HealthKitClient {
    var isHealthDataAvailable = true
    private let samples: [HKSample]
    private(set) var fetchedTypes = [HKSampleType]()
    private(set) var savedSamples = [HKSample]()

    init(samples: [HKSample]) {
        self.samples = samples
    }

    func fetchSamples(of type: HKSampleType, completion: @escaping ([HKSample]?, Error?) -> Void) {
        fetchedTypes.append(type)
        completion(samples, nil)
    }

    func save(_ sample: HKSample, completion: @escaping (Bool, Error?) -> Void) {
        savedSamples.append(sample)
        completion(true, nil)
    }

    func observeSamples(
        of type: HKSampleType,
        initialHandler: @escaping ([HKSample]?, [HealthKitDeletedSample]?) -> Void,
        updateHandler: @escaping ([HKSample]?, [HealthKitDeletedSample]?) -> Void
    ) {
    }
}

private final class FakeCloudantSampleStore: CloudantSampleStore {
    private let samples: [OTFCloudantSample]
    private(set) var addedSamples = [OTFCloudantSample]()
    private(set) var updatedSamples = [OTFCloudantSample]()
    private(set) var deletedSamples = [OTFCloudantSample]()

    init(samples: [OTFCloudantSample]) {
        self.samples = samples
    }

    func fetchSamples(completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void) {
        completion(.success(samples))
    }

    func addSamples(_ samples: [OTFCloudantSample]) {
        addedSamples.append(contentsOf: samples)
    }

    func updateSamples(_ samples: [OTFCloudantSample]) {
        updatedSamples.append(contentsOf: samples)
    }

    func deleteSamples(_ samples: [OTFCloudantSample]) {
        deletedSamples.append(contentsOf: samples)
    }

    func fetchSamples(
        healthKitSampleType: OTFHealthSampleType,
        uuid: String,
        completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void
    ) {
        completion(.success([]))
    }
}
#endif
