import Foundation
import OTFCDTDatastore
import SwiftUI
import WatchConnectivity
import XCTest

@testable import OTFCloudantStore

final class NetworkStoreServiceResearchKitTests: XCTestCase {

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

    func testEndpointGetBuildsRequestWithBaseURLHeadersMethodAndEscapedQuery() throws {
        let session = Phase6URLSession(data: try encodedNetworkFixture(value: "decoded"))
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")

        let result: Result<Phase6NetworkFixture, Error> = waitForNetworkResult { completion in
            network.sendRequest(
                endpoint: "/v1/search",
                params: ["query": "heart rate", "limit": "10"],
                headers: ["Authorization": "Bearer token"],
                method: .get,
                completionBlOTF: completion
            )
        }

        XCTAssertEqual(try result.get(), Phase6NetworkFixture(value: "decoded"))
        XCTAssertEqual(session.tasks.first?.resumeCallCount, 1)
        let request = try XCTUnwrap(session.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.example.com")
        XCTAssertEqual(components.path, "/v1/search")
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(queryItems["query"], "heart rate")
        XCTAssertEqual(queryItems["limit"], "10")
    }

    func testEndpointRequestDoesNotAppendParamsForPost() throws {
        let session = Phase6URLSession(data: try encodedNetworkFixture(value: "decoded"))
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")

        let result: Result<Phase6NetworkFixture, Error> = waitForNetworkResult { completion in
            network.sendRequest(
                endpoint: "/items",
                params: ["ignored": "value"],
                headers: nil,
                method: .post,
                completionBlOTF: completion
            )
        }

        XCTAssertEqual(try result.get(), Phase6NetworkFixture(value: "decoded"))
        let request = try XCTUnwrap(session.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/items")
    }

    func testBaseURLMutationIsScopedToInjectedNetworkInstance() throws {
        let firstSession = Phase6URLSession(data: try encodedNetworkFixture(value: "first"))
        let secondSession = Phase6URLSession(data: try encodedNetworkFixture(value: "second"))
        let firstNetwork = OTFNetwork(session: firstSession, baseURL: "https://first.example.com")
        let secondNetwork = OTFNetwork(session: secondSession, baseURL: "https://second.example.com")

        firstNetwork.setBaseUrl(baseURL: "https://changed.example.com")

        let firstResult: Result<Phase6NetworkFixture, Error> = waitForNetworkResult { completion in
            firstNetwork.sendRequest(endpoint: "/status", params: nil, headers: nil, method: .get, completionBlOTF: completion)
        }
        let secondResult: Result<Phase6NetworkFixture, Error> = waitForNetworkResult { completion in
            secondNetwork.sendRequest(endpoint: "/status", params: nil, headers: nil, method: .get, completionBlOTF: completion)
        }

        XCTAssertEqual(try firstResult.get(), Phase6NetworkFixture(value: "first"))
        XCTAssertEqual(try secondResult.get(), Phase6NetworkFixture(value: "second"))
        XCTAssertEqual(firstSession.requests.first?.url?.host, "changed.example.com")
        XCTAssertEqual(secondSession.requests.first?.url?.host, "second.example.com")
    }

    func testTransportErrorTakesPrecedenceOverHTTPStatusAndData() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/status"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
        ))
        let expectedError = NSError(domain: "phase6.transport", code: 41)
        let session = Phase6URLSession(
            data: Data("server unavailable".utf8),
            response: response,
            error: expectedError
        )
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")
        let request = URLRequest(url: url)

        let result: Result<Data, Error> = waitForNetworkResult { completion in
            network.sendRequest(urlRequest: request, completionBlOTF: completion)
        }

        switch result {
        case .success(let data):
            XCTFail("Expected transport error, got data: \(data)")
        case .failure(let error as NSError):
            XCTAssertEqual(error.domain, expectedError.domain)
            XCTAssertEqual(error.code, expectedError.code)
        }
    }

    func testSendRequestFailsForNonSuccessHTTPStatus() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/status"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
        ))
        let session = Phase6URLSession(data: Data("server unavailable".utf8), response: response)
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")

        let result: Result<Data, Error> = waitForNetworkResult { completion in
            network.sendRequest(urlRequest: URLRequest(url: url), completionBlOTF: completion)
        }

        switch result {
        case .success(let data):
            XCTFail("Expected HTTP status failure, got data: \(data)")
        case .failure(let error):
            XCTAssertEqual(error as? OTFNetworkError, .httpStatus(503))
        }
    }

    func testSendRequestSucceedsForSuccessHTTPStatusWithEmptyBody() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/no-content"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        ))
        let expectedData = Data()
        let session = Phase6URLSession(data: expectedData, response: response)
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")

        let result: Result<Data, Error> = waitForNetworkResult { completion in
            network.sendRequest(urlRequest: URLRequest(url: url), completionBlOTF: completion)
        }

        XCTAssertEqual(try result.get(), expectedData)
    }

    func testHTTPStatusFailureTakesPrecedenceOverEmptyData() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/missing"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        ))
        let session = Phase6URLSession(response: response)
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")

        let result: Result<Data, Error> = waitForNetworkResult { completion in
            network.sendRequest(urlRequest: URLRequest(url: url), completionBlOTF: completion)
        }

        switch result {
        case .success(let data):
            XCTFail("Expected HTTP status failure, got data: \(data)")
        case .failure(let error):
            XCTAssertEqual(error as? OTFNetworkError, .httpStatus(404))
        }
    }

    func testSendRequestFailsWhenSessionReturnsNoDataAndNoError() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/empty"))
        let session = Phase6URLSession()
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")
        let request = URLRequest(url: url)

        let result: Result<Data, Error> = waitForNetworkResult { completion in
            network.sendRequest(urlRequest: request, completionBlOTF: completion)
        }

        switch result {
        case .success(let data):
            XCTFail("Expected empty-data failure, got data: \(data)")
        case .failure(let error):
            XCTAssertEqual(error as? OTFNetworkError, .emptyData)
        }
    }

    func testSendJsonResultRequestPropagatesHTTPStatusFailureBeforeDecoding() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/status"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        ))
        let session = Phase6URLSession(
            data: try encodedNetworkFixture(value: "decoded"),
            response: response
        )
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")

        let result: Result<Phase6NetworkFixture, Error> = waitForNetworkResult { completion in
            network.sendJsonResultRequest(urlRequest: URLRequest(url: url), result: completion)
        }

        switch result {
        case .success(let fixture):
            XCTFail("Expected HTTP status failure, got fixture: \(fixture)")
        case .failure(let error):
            XCTAssertEqual(error as? OTFNetworkError, .httpStatus(500))
        }
    }

    func testSendJsonResultRequestPropagatesDecodeError() throws {
        let session = Phase6URLSession(data: Data(#"{"unexpected":"shape"}"#.utf8))
        let network = OTFNetwork(session: session, baseURL: "https://api.example.com")
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://api.example.com/decode")))

        let result: Result<Phase6NetworkFixture, Error> = waitForNetworkResult { completion in
            network.sendJsonResultRequest(urlRequest: request, result: completion)
        }

        switch result {
        case .success(let fixture):
            XCTFail("Expected decode error, got fixture: \(fixture)")
        case .failure(let error):
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected keyNotFound decode error, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "value")
        }
    }

    func testStoreServicePropagatesFactoryErrorsWithoutFallbackStore() throws {
        let peer = OTFWatchConnectivityPeer(session: Phase6WatchSession())
        var receivedStoreName: String?
        var receivedPeer: OTFWatchConnectivityPeer?
        let service = StoreService { storeName, factoryPeer in
            receivedStoreName = storeName
            receivedPeer = factoryPeer
            throw Phase6StoreFactoryError.expected
        }

        XCTAssertThrowsError(try service.currentStore(peer: peer)) { error in
            XCTAssertEqual(error as? Phase6StoreFactoryError, .expected)
        }
        XCTAssertEqual(receivedStoreName, "local_db")
        XCTAssertTrue(receivedPeer === peer)
    }

    func testStoreServiceCallsFactoryForEachCurrentStoreRequest() throws {
        let peer = OTFWatchConnectivityPeer(session: Phase6WatchSession())
        var receivedStoreNames = [String]()
        let service = StoreService { storeName, _ in
            receivedStoreNames.append(storeName)
            return try self.makeStoreBackedByTempDatastore(prefix: "store_service_phase6")
        }

        let firstStore = try service.currentStore(peer: peer)
        let secondStore = try service.currentStore(peer: peer)

        XCTAssertEqual(receivedStoreNames, ["local_db", "local_db"])
        XCTAssertFalse(firstStore === secondStore)
    }

    func testCloudantStoreKeyCachesNilDefaultUntilProviderChanges() throws {
        var nilProviderCallCount = 0
        CloudantStoreKey.defaultValueProvider = {
            nilProviderCallCount += 1
            return nil
        }

        XCTAssertNil(CloudantStoreKey.defaultValue)
        XCTAssertNil(CloudantStoreKey.defaultValue)
        XCTAssertEqual(nilProviderCallCount, 1)

        let expectedStore = try makeStoreBackedByTempDatastore(prefix: "environment_nil_reset")
        var storeProviderCallCount = 0
        CloudantStoreKey.defaultValueProvider = {
            storeProviderCallCount += 1
            return expectedStore
        }

        XCTAssertTrue(CloudantStoreKey.defaultValue === expectedStore)
        XCTAssertEqual(storeProviderCallCount, 1)
    }

    func testEnvironmentValuesStoreRoundTripsExplicitOverride() throws {
        let store = try makeStoreBackedByTempDatastore(prefix: "environment_override")
        var values = EnvironmentValues()

        values.store = store
        XCTAssertTrue(values.store === store)

        values.store = nil
        XCTAssertNil(values.store)
    }

    func testORKResultRoundTripsCommonFieldsAndJSONUserInfo() throws {
        var result = try makeEmptyORKResult()
        let startDate = Date(timeIntervalSince1970: 1_750_000_000)
        let endDate = Date(timeIntervalSince1970: 1_750_000_360)
        result.id = "result-1"
        result.revId = "2-revision"
        result.startDate = startDate
        result.endDate = endDate
        result.userInfo = [
            "label": "amsler",
            "count": 3,
            "completed": true,
            "nested": ["side": "left"]
        ]

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(OTFCloudantORKResult.self, from: data)

        XCTAssertEqual(decoded.id, "result-1")
        XCTAssertEqual(decoded.revId, "2-revision")
        XCTAssertEqual(decoded.startDate, startDate)
        XCTAssertEqual(decoded.endDate, endDate)
        let userInfo = try XCTUnwrap(decoded.userInfo)
        XCTAssertEqual(userInfo["label"] as? String, "amsler")
        XCTAssertEqual((userInfo["count"] as? NSNumber)?.intValue, 3)
        XCTAssertEqual((userInfo["completed"] as? NSNumber)?.boolValue, true)
        let nested = try XCTUnwrap(userInfo["nested"] as? [String: Any])
        XCTAssertEqual(nested["side"] as? String, "left")
    }

    func testORKResultDecodesMissingOptionalValuesAsNil() throws {
        let result = try JSONDecoder().decode(OTFCloudantORKResult.self, from: Data("{}".utf8))

        XCTAssertNil(result.id)
        XCTAssertNil(result.revId)
        XCTAssertNil(result.startDate)
        XCTAssertNil(result.endDate)
        XCTAssertNil(result.userInfo)
    }

    func testORKResultRejectsNonJSONSerializableUserInfoOnEncode() throws {
        var result = try makeEmptyORKResult()
        result.userInfo = ["invalid": Date(timeIntervalSince1970: 1_750_000_000)]

        XCTAssertThrowsError(try JSONEncoder().encode(result))
    }

    func testORKResultRejectsInvalidJSONUserInfoDataOnDecode() throws {
        let payload = try JSONEncoder().encode(Phase6ORKUserInfoPayload(userInfo: Data("not-json".utf8)))

        XCTAssertThrowsError(try JSONDecoder().decode(OTFCloudantORKResult.self, from: payload))
    }
}

private extension NetworkStoreServiceResearchKitTests {

    func waitForNetworkResult<T>(
        _ work: (@escaping (Result<T, Error>) -> Void) -> Void
    ) -> Result<T, Error> {
        let expectation = expectation(description: "wait for phase 6 network result")
        var receivedResult: Result<T, Error>?

        work { result in
            receivedResult = result
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        return receivedResult ?? .failure(NSError(domain: "phase6.network.timeout", code: -1))
    }

    func encodedNetworkFixture(value: String = "ok") throws -> Data {
        try JSONEncoder().encode(Phase6NetworkFixture(value: value))
    }

    func makeDatastoreManager() throws -> CDTDatastoreManager {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("otfcloudant_phase6_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return try CDTDatastoreManager(directory: directory.path)
    }

    func makeStoreBackedByTempDatastore(prefix: String) throws -> OTFCloudantStore {
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

    func uniqueStoreName(prefix: String) -> String {
        let suffix = UUID().uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return "\(prefix)_\(suffix)"
    }

    func makeEmptyORKResult() throws -> OTFCloudantORKResult {
        try JSONDecoder().decode(OTFCloudantORKResult.self, from: Data("{}".utf8))
    }
}

private struct Phase6NetworkFixture: Codable, Equatable {
    let value: String
}

private struct Phase6ORKUserInfoPayload: Encodable {
    let userInfo: Data
}

private enum Phase6StoreFactoryError: Error, Equatable {
    case expected
}

private final class Phase6URLSessionTask: URLSessionDataTasking {
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

private final class Phase6URLSession: URLSessioning {
    private let data: Data?
    private let response: URLResponse?
    private let error: Error?
    private(set) var requests = [URLRequest]()
    private(set) var tasks = [Phase6URLSessionTask]()

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
        let task = Phase6URLSessionTask { [data, response, error] in
            completionHandler(data, response, error)
        }
        tasks.append(task)
        return task
    }
}

private final class Phase6WatchSession: WatchSessioning {
    var activationState: WCSessionActivationState = .activated
    var isReachable = true
    var sentMessages = [[String: Any]]()
    var transferredUserInfoMessages = [[String: Any]]()

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
        replyHandler?([:])
    }

    func transferUserInfo(_ message: [String: Any]) {
        transferredUserInfoMessages.append(message)
    }
}
