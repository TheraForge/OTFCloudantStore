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
import Network
import OTFCloudantStore
import OTFCloudClientAPI
import OTFUtilities

class OTFCloudantSSETest: XCTestCase {

    private let eventTimeout: TimeInterval = 5
    private let apiKey = "test-api-key"
    private let auth = Auth(
        token: "test-access-token",
        refreshToken: "test-refresh-token",
        iat: Date().timeIntervalSince1970,
        exp: Date().addingTimeInterval(3600).timeIntervalSince1970
    )

    func testObserveChangeEventConnectsToChangesFeedAndDeliversMessage() throws {
        let server = try LocalSSEServer(event: Event(d: 1, message: "local-change", type: .dbUpdate))
        try server.start()
        defer { server.stop() }

        configureNetwork(port: server.port)

        let opened = expectation(description: "SSE changes feed opened")
        let received = expectation(description: "SSE changes feed delivered an event")
        let shared = TheraForgeNetwork.shared

        shared.eventSourceOnOpen = {
            opened.fulfill()
        }

        shared.onReceivedMessage = { event in
            XCTAssertEqual(event.d, 1)
            XCTAssertEqual(event.message, "local-change")
            XCTAssertEqual(event.type, .dbUpdate)
            received.fulfill()
        }

        shared.observeChangeEvent(auth: auth)

        wait(for: [opened, received], timeout: eventTimeout)
        let request = try XCTUnwrap(server.request)
        XCTAssertTrue(request.hasPrefix("GET /api/db/_changes HTTP/1.1"))
        XCTAssertTrue(request.contains("Authorization: Bearer \(auth.token)"))
        XCTAssertTrue(request.contains("Accept: text/event-stream"))
    }

    func testObserveOnServerSentEventsConnectsToSubscribeFeedAndDeliversMessage() throws {
        let server = try LocalSSEServer(event: Event(d: 2, message: "local-subscribe", type: .keepAlive))
        try server.start()
        defer { server.stop() }

        configureNetwork(port: server.port)

        let opened = expectation(description: "SSE subscribe feed opened")
        let received = expectation(description: "SSE subscribe feed delivered an event")
        let shared = TheraForgeNetwork.shared

        shared.eventSourceOnOpen = {
            opened.fulfill()
        }

        shared.onReceivedMessage = { event in
            XCTAssertEqual(event.d, 2)
            XCTAssertEqual(event.message, "local-subscribe")
            XCTAssertEqual(event.type, .keepAlive)
            received.fulfill()
        }

        shared.observeOnServerSentEvents(auth: auth)

        wait(for: [opened, received], timeout: eventTimeout)
        let request = try XCTUnwrap(server.request)
        XCTAssertTrue(request.hasPrefix("GET /api/v1/db/_subscribe HTTP/1.1"))
        XCTAssertTrue(request.contains("Authorization: Bearer \(auth.token)"))
        XCTAssertTrue(request.contains("API-KEY: \(apiKey)"))
    }

    private func configureNetwork(port: UInt16) {
        let url = URL(string: "http://127.0.0.1:\(port)/api")!
        let configurations = NetworkingLayer.Configurations(APIBaseURL: url, apiKey: apiKey, timeoutInterval: eventTimeout)
        TheraForgeNetwork.configureNetwork(configurations)
    }
}

private final class LocalSSEServer {
    private let event: Event
    private let queue = DispatchQueue(label: "OTFCloudantSSETest.LocalSSEServer")
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private let lock = NSLock()
    private(set) var request: String?

    var port: UInt16 {
        guard let port = listener.port else { return 0 }
        return port.rawValue
    }

    init(event: Event) throws {
        self.event = event
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start() throws {
        let ready = DispatchSemaphore(value: 0)
        var startupError: Error?

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                startupError = error
                ready.signal()
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 2) == .success else {
            throw LocalSSEServerError.timeout
        }

        if let startupError {
            throw startupError
        }
    }

    func stop() {
        listener.cancel()
        connections.forEach { $0.cancel() }
    }

    private func handle(_ connection: NWConnection) {
        connections.append(connection)
        connection.stateUpdateHandler = { _ in }
        connection.start(queue: queue)
        receiveRequest(on: connection)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self else { return }
            self.lock.lock()
            self.request = data.flatMap { String(data: $0, encoding: .utf8) }
            self.lock.unlock()
            self.sendEvent(on: connection)
        }
    }

    private func sendEvent(on connection: NWConnection) {
        let body = """
        data: {"d":\(event.d),"message":"\(event.message)","type":"\(event.type.rawValue)"}

        """
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/event-stream\r
        Cache-Control: no-cache\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private enum LocalSSEServerError: Error {
    case timeout
}
