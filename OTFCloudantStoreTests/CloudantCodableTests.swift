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
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import XCTest
import OTFCDTDatastore

@testable import OTFCloudantStore

final class CloudantCodableTests: XCTestCase {
    func testEncoderAndDecoderRoundTripNestedPayloadWithCloudantTypes() throws {
        let payload = CloudantPayload.fixture
        let encoder = CloudantEncoder()
        encoder.dataEncodingStrategy = .base64

        let encoded = try encoder.encode(payload)

        XCTAssertEqual(encoded["id"] as? String, payload.id)
        XCTAssertEqual(encoded["blob"] as? String, payload.blob.base64EncodedString())
        XCTAssertNil(encoded["note"])
        XCTAssertEqual(encoded["website"] as? String, payload.website.absoluteString)

        let decoder = CloudantDecoder()
        decoder.dataDecodingStrategy = .base64

        let decoded = try decoder.decode(CloudantPayload.self, from: encoded)
        XCTAssertEqual(decoded, payload)
    }

    func testDateEncodingStrategiesRoundTripStableValues() throws {
        let date = Date(timeIntervalSince1970: 1_717_171_717)

        try assertDateRoundTrip(date, encoding: .secondsSince1970, decoding: .secondsSince1970) { encoded in
            XCTAssertEqual(encoded as? Double, date.timeIntervalSince1970)
        }

        try assertDateRoundTrip(date, encoding: .millisecondsSince1970, decoding: .millisecondsSince1970) { encoded in
            XCTAssertEqual(encoded as? Double, date.timeIntervalSince1970 * 1000)
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        try assertDateRoundTrip(date, encoding: .formatted(formatter), decoding: .formatted(formatter)) { encoded in
            XCTAssertEqual(encoded as? String, "2024-05-31 16:08:37")
        }
    }

    func testDecoderReportsUsefulErrorsForInvalidCloudantValues() {
        XCTAssertThrowsError(try CloudantDecoder().decode(CountPayload.self, from: ["count": "five"])) { error in
            guard case DecodingError.typeMismatch = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
        }

        let decoder = CloudantDecoder()
        decoder.dataDecodingStrategy = .base64

        XCTAssertThrowsError(try decoder.decode(BinaryPayload.self, from: ["blob": "not base64"])) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Expected dataCorrupted, got \(error)")
            }
        }
    }

    func testDecoderRejectsNumericOverflowUnsignedNegativeAndBoolNumberMismatches() {
        XCTAssertThrowsError(try CloudantDecoder().decode(Int8Payload.self, from: ["value": 128])) { error in
            assertDataCorrupted(error, expectedPath: ["value"])
        }

        XCTAssertThrowsError(try CloudantDecoder().decode(UIntPayload.self, from: ["value": -1])) { error in
            assertDataCorrupted(error, expectedPath: ["value"])
        }

        XCTAssertThrowsError(try CloudantDecoder().decode(UInt8Payload.self, from: ["value": 256])) { error in
            assertDataCorrupted(error, expectedPath: ["value"])
        }

        XCTAssertThrowsError(try CloudantDecoder().decode(IntPayload.self, from: ["value": true])) { error in
            assertTypeMismatch(error, expectedPath: ["value"])
        }

        XCTAssertThrowsError(try CloudantDecoder().decode(BoolPayload.self, from: ["value": 1])) { error in
            assertTypeMismatch(error, expectedPath: ["value"])
        }
    }

    func testDecoderHandlesNestedKeyedUnkeyedContainersAndDecodeNil() throws {
        let decoded = try CloudantDecoder().decode(
            NestedContainerPayload.self,
            from: [
                "metadata": [
                    "id": "document-1",
                    "missing": NSNull()
                ],
                "values": [
                    7,
                    NSNull(),
                    [
                        "name": "leaf",
                        "note": NSNull()
                    ]
                ],
                "nullable": NSNull()
            ]
        )

        XCTAssertEqual(decoded.id, "document-1")
        XCTAssertTrue(decoded.keyedNil)
        XCTAssertNil(decoded.optionalString)
        XCTAssertEqual(decoded.firstValue, 7)
        XCTAssertTrue(decoded.unkeyedNil)
        XCTAssertEqual(decoded.childName, "leaf")
        XCTAssertTrue(decoded.childNoteWasNil)
        XCTAssertTrue(decoded.topLevelNil)
    }

    func testDecoderReportsCodingPathForMalformedArrayElement() {
        XCTAssertThrowsError(try CloudantDecoder().decode(IntArrayPayload.self, from: ["values": [1, "bad"]])) { error in
            assertTypeMismatch(error, expectedPath: ["values", "Index 1"])
        }
    }

    func testISO8601DateStrategyUsesTheraForgeFormatterAndRejectsMalformedStrings() throws {
        let date = Date(timeIntervalSince1970: 1_717_171_717)
        let encoder = CloudantEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let encoded = try encoder.encode(DatePayload(createdAt: date))
        XCTAssertEqual(encoded["createdAt"] as? String, theraForgeISO8601Formatter.string(from: date))

        let decoder = CloudantDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DatePayload.self, from: encoded)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)

        XCTAssertThrowsError(try decoder.decode(DatePayload.self, from: ["createdAt": "not-a-date"])) { error in
            assertDataCorrupted(error, expectedPath: ["createdAt"])
        }
    }

    func testCustomDateAndDataStrategiesPropagateErrors() {
        let dateEncoder = CloudantEncoder()
        dateEncoder.dateEncodingStrategy = .custom { _, _ in
            throw StrategyError.dateEncoding
        }
        XCTAssertThrowsError(try dateEncoder.encode(DatePayload(createdAt: Date(timeIntervalSince1970: 1)))) { error in
            XCTAssertEqual(error as? StrategyError, .dateEncoding)
        }

        let dateDecoder = CloudantDecoder()
        dateDecoder.dateDecodingStrategy = .custom { _ in
            throw StrategyError.dateDecoding
        }
        XCTAssertThrowsError(try dateDecoder.decode(DatePayload.self, from: ["createdAt": "2024-05-31T16:08:37Z"])) { error in
            XCTAssertEqual(error as? StrategyError, .dateDecoding)
        }

        let dataEncoder = CloudantEncoder()
        dataEncoder.dataEncodingStrategy = .custom { _, _ in
            throw StrategyError.dataEncoding
        }
        XCTAssertThrowsError(try dataEncoder.encode(BinaryPayload(blob: Data([1, 2, 3])))) { error in
            XCTAssertEqual(error as? StrategyError, .dataEncoding)
        }

        let dataDecoder = CloudantDecoder()
        dataDecoder.dataDecodingStrategy = .custom { _ in
            throw StrategyError.dataDecoding
        }
        XCTAssertThrowsError(try dataDecoder.decode(BinaryPayload.self, from: ["blob": "AQID"])) { error in
            XCTAssertEqual(error as? StrategyError, .dataDecoding)
        }
    }

    func testEncoderRejectsNonDictionaryTopLevelPayloads() {
        XCTAssertThrowsError(try CloudantEncoder().encode(["not", "a", "document"])) { error in
            guard case EncodingError.invalidValue = error else {
                return XCTFail("Expected invalidValue, got \(error)")
            }
        }
    }

    func testEncoderWritesExplicitNilAndNestedContainers() throws {
        let encoded = try CloudantEncoder().encode(ExplicitContainerPayload())

        XCTAssertTrue(encoded["explicitNil"] is NSNull)
        XCTAssertNSDictionaryEqual(encoded["metadata"] as? [String: Any] ?? [:], ["id": "document-1"])
        let values = try XCTUnwrap(encoded["values"] as? [Any])
        XCTAssertEqual((values[0] as? NSNumber)?.intValue, 1)
        XCTAssertTrue(values[1] is NSNull)
        XCTAssertNSDictionaryEqual(values[2] as? [String: Any] ?? [:], ["name": "leaf"])
    }

    func testQueryComponentsBuildCloudantSelectors() {
        let status = OTFCloudantQueryComponent.simpleComponent("status", .equal, "active")
        let priority = OTFCloudantQueryComponent.simpleComponent("priority", .greaterThanOrEqual, 3)
        let owner = OTFCloudantQueryComponent.simpleComponent("owner", .notEqualTo, "archived")
        let tag = OTFCloudantQueryComponent.simpleComponent("tags", .in, ["daily", "watch"])

        XCTAssertNSDictionaryEqual(status.toQuery(), ["status": ["$eq": "active"]])
        XCTAssertNSDictionaryEqual(priority.toQuery(), ["priority": ["$gte": 3]])

        let required = OTFCloudantCombinationQueryComponent.combinedQueryComponent(status, .and, priority)
        XCTAssertNSDictionaryEqual(required.toQuery(), [
            "$and": [
                ["status": ["$eq": "active"]],
                ["priority": ["$gte": 3]]
            ]
        ])

        let exclusions = OTFCloudantCombinationQueryComponent.combinedQueryComponent(owner, .or, tag)
        let complex = OTFCloudantComplexQueryComponent.complexQueryComponent(required, .and, exclusions)

        XCTAssertNSDictionaryEqual(complex.toQuery(), [
            "$and": [
                [
                    "$and": [
                        ["status": ["$eq": "active"]],
                        ["priority": ["$gte": 3]]
                    ]
                ],
                [
                    "$or": [
                        ["owner": ["$ne": "archived"]],
                        ["tags": ["$in": ["daily", "watch"]]]
                    ]
                ]
            ]
        ])
    }

    func testQueryComponentsCoverAllSelectorOperators() {
        let cases: [(OTFCloudantConditionSelector, Any, [String: Any])] = [
            (.lessThan, 1, ["field": ["$lt": 1]]),
            (.lessThanOrEqual, 2, ["field": ["$lte": 2]]),
            (.equal, "active", ["field": ["$eq": "active"]]),
            (.greaterThanOrEqual, 3, ["field": ["$gte": 3]]),
            (.greaterThan, 4, ["field": ["$gt": 4]]),
            (.notEqualTo, "archived", ["field": ["$ne": "archived"]]),
            (.regex, "^a", ["field": ["$regex": "^a"]]),
            (.exists, true, ["field": ["$exists": true]]),
            (.mod, [2, 0], ["field": ["$mod": [2, 0]]]),
            (.size, 3, ["field": ["$size": 3]]),
            (.in, ["a", "b"], ["field": ["$in": ["a", "b"]]]),
            (.notIn, ["x", "y"], ["field": ["$nin": ["x", "y"]]])
        ]

        for (selector, value, expected) in cases {
            let query = OTFCloudantQueryComponent.simpleComponent("field", selector, value).toQuery()
            XCTAssertNSDictionaryEqual(query, expected)
        }
    }

    func testNetworkHelpersBuildEscapedQueryStringsAndCurlCommands() throws {
        let queryString = OTFNetwork.shared.buildQueryString(fromDictionary: [
            "query": "heart rate",
            "limit": "10"
        ])

        XCTAssertTrue(queryString.hasPrefix("?"))
        XCTAssertEqual(Set(queryString.dropFirst().split(separator: "&").map(String.init)), [
            "query=heart%20rate",
            "limit=10"
        ])

        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/v1/documents")))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Authorization": "Bearer token",
            "API-KEY": "production-key",
            "Cookie": "session=secret"
        ]
        request.httpBody = Data(#"{"ok":true}"#.utf8)

        let curl = request.curlString
        XCTAssertTrue(curl.contains(#"curl "https://example.com/v1/documents""#))
        XCTAssertTrue(curl.contains("-X POST"))
        XCTAssertTrue(curl.contains("-H 'Authorization: <redacted>'"))
        XCTAssertTrue(curl.contains("-H 'API-KEY: <redacted>'"))
        XCTAssertTrue(curl.contains("-d '<redacted: 11 bytes>'"))
        XCTAssertFalse(curl.contains("Bearer token"))
        XCTAssertFalse(curl.contains("production-key"))
        XCTAssertFalse(curl.contains(#"{"ok":true}"#))
        XCTAssertFalse(curl.contains("Cookie"))

        let credentialRequest = URLRequest(
            url: try XCTUnwrap(URL(string: "https://sync-user:sync-password@example.com/v1/documents"))
        )
        XCTAssertFalse(credentialRequest.curlString.contains("sync-user"))
        XCTAssertFalse(credentialRequest.curlString.contains("sync-password"))
    }

    func testDocumentRevisionBridgeDecodesCloudantDictionaryBody() throws {
        let revision = [
            "id": "revision-1",
            "name": "vitals",
            "values": [1, 2, 3]
        ].toDocumentRevision(revId: "1-local")

        let decoded = try XCTUnwrap(try revision.data(as: RevisionPayload.self))
        XCTAssertEqual(decoded, RevisionPayload(id: "revision-1", name: "vitals", values: [1, 2, 3]))
    }

    func testUtilityExtensionsHandleEdgeCases() throws {
        let original: [String: Any] = [
            "existing": "keep",
            "nullValue": NSNull()
        ]
        let copied = try XCTUnwrap(original.copyValue(from: [
            "existing": "replace",
            "nullValue": "filled",
            "missing": "added"
        ]))

        XCTAssertEqual(copied["existing"] as? String, "keep")
        XCTAssertEqual(copied["nullValue"] as? String, "filled")
        XCTAssertEqual(copied["missing"] as? String, "added")
        XCTAssertNil(([1: "one"] as [Int: String]).copyValue(from: ["missing": "added"]))

        XCTAssertEqual("".randomString(length: 0), "")
        let random = "ignored receiver".randomString(length: 32)
        XCTAssertEqual(random.count, 32)
        XCTAssertTrue(random.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber)
        })

        XCTAssertEqual("heart rate+sleep".addPercentEncoding(), "heart%20rate+sleep")
    }

    func testDocumentRevisionBridgePropagatesDecodeErrorsAndDataStoreNamesStayStable() {
        let revision = CDTDocumentRevision(docId: "malformed-revision")
        revision.body = NSMutableDictionary(dictionary: [
            "id": 42,
            "name": "vitals",
            "values": [1, 2, 3]
        ])

        XCTAssertThrowsError(try revision.data(as: RevisionPayload.self)) { error in
            assertTypeMismatch(error, expectedPath: ["id"])
        }

        XCTAssertEqual(DataStoreName.manager, "cloudant-sync-datastore")
        XCTAssertEqual(DataStoreName.contact, "cloudant_contact_db")
        XCTAssertEqual(DataStoreName.patients, "cloudant_patient_db")
        XCTAssertEqual(DataStoreName.carePlan, "cloudant_careplan_db")
        XCTAssertEqual(DataStoreName.outcome, "cloudant_outcome_db")
        XCTAssertEqual(DataStoreName.task, "cloudant_task_db")
    }

    func testCloudantErrorsExposeLocalizedDescriptions() {
        XCTAssertEqual(OTFCloudantError.fetchFailed(reason: "missing").errorDescription, "Failed to fetch: missing")
        XCTAssertEqual(OTFCloudantError.addFailed(reason: "duplicate").errorDescription, "Failed to add: duplicate")
        XCTAssertEqual(OTFCloudantError.updateFailed(reason: "stale").errorDescription, "Failed to update: stale")
        XCTAssertEqual(OTFCloudantError.deleteFailed(reason: "locked").errorDescription, "Failed to delete: locked")
        XCTAssertEqual(OTFCloudantError.remoteSynchronizationFailed(reason: "offline").errorDescription, "Sync failed: offline")
        XCTAssertEqual(OTFCloudantError.invalidValue(reason: "zero").errorDescription, "Invalid value: zero")
        XCTAssertEqual(OTFCloudantError.timedOut(reason: "slow").errorDescription, "Timed out: slow")
    }

    private func assertDateRoundTrip(
        _ date: Date,
        encoding: CloudantEncoder.DateEncodingStrategy,
        decoding: CloudantDecoder.DateDecodingStrategy,
        encodedAssertion: ([String: Any].Value) -> Void
    ) throws {
        let encoder = CloudantEncoder()
        encoder.dateEncodingStrategy = encoding

        let encoded = try encoder.encode(DatePayload(createdAt: date))
        encodedAssertion(try XCTUnwrap(encoded["createdAt"]))

        let decoder = CloudantDecoder()
        decoder.dateDecodingStrategy = decoding

        let decoded = try decoder.decode(DatePayload.self, from: encoded)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }
}

private struct CloudantPayload: Codable, Equatable {
    let id: String
    let isActive: Bool
    let retryCount: Int
    let int8Value: Int8
    let int16Value: Int16
    let int32Value: Int32
    let int64Value: Int64
    let uintValue: UInt
    let uint8Value: UInt8
    let uint16Value: UInt16
    let uint32Value: UInt32
    let uint64Value: UInt64
    let score: Float
    let ratio: Double
    let decimal: Decimal
    let createdAt: Date
    let blob: Data
    let website: URL
    let note: String?
    let nested: NestedPayload
    let children: [NestedPayload]

    static let fixture = CloudantPayload(
        id: "document-1",
        isActive: true,
        retryCount: 42,
        int8Value: -8,
        int16Value: -1024,
        int32Value: -65536,
        int64Value: -9999999,
        uintValue: 42,
        uint8Value: 8,
        uint16Value: 1024,
        uint32Value: 65536,
        uint64Value: 9999999,
        score: 4.5,
        ratio: 0.25,
        decimal: Decimal(string: "19.95")!,
        createdAt: Date(timeIntervalSince1970: 1_717_171_717),
        blob: Data([0, 1, 2, 3, 255]),
        website: URL(string: "https://example.com/documents/1")!,
        note: nil,
        nested: NestedPayload(name: "parent", values: [1, 2, 3]),
        children: [
            NestedPayload(name: "child-a", values: []),
            NestedPayload(name: "child-b", values: [9])
        ]
    )
}

private struct NestedPayload: Codable, Equatable {
    let name: String
    let values: [Int]
}

private struct DatePayload: Codable, Equatable {
    let createdAt: Date
}

private struct IntPayload: Decodable {
    let value: Int
}

private struct Int8Payload: Decodable {
    let value: Int8
}

private struct UIntPayload: Decodable {
    let value: UInt
}

private struct UInt8Payload: Decodable {
    let value: UInt8
}

private struct BoolPayload: Decodable {
    let value: Bool
}

private struct CountPayload: Decodable {
    let count: Int
}

private struct BinaryPayload: Codable {
    let blob: Data
}

private struct NestedContainerPayload: Decodable {
    let id: String
    let keyedNil: Bool
    let optionalString: String?
    let firstValue: Int
    let unkeyedNil: Bool
    let childName: String
    let childNoteWasNil: Bool
    let topLevelNil: Bool

    enum CodingKeys: String, CodingKey {
        case metadata
        case values
        case nullable
    }

    enum MetadataKeys: String, CodingKey {
        case id
        case missing
    }

    enum ChildKeys: String, CodingKey {
        case name
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topLevelNil = try container.decodeNil(forKey: .nullable)

        let metadata = try container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata)
        id = try metadata.decode(String.self, forKey: .id)
        keyedNil = try metadata.decodeNil(forKey: .missing)
        optionalString = try metadata.decodeIfPresent(String.self, forKey: .missing)

        var values = try container.nestedUnkeyedContainer(forKey: .values)
        firstValue = try values.decode(Int.self)
        unkeyedNil = try values.decodeNil()
        let child = try values.nestedContainer(keyedBy: ChildKeys.self)
        childName = try child.decode(String.self, forKey: .name)
        childNoteWasNil = try child.decodeNil(forKey: .note)
    }
}

private struct IntArrayPayload: Decodable {
    let values: [Int]
}

private struct ExplicitContainerPayload: Encodable {
    enum CodingKeys: String, CodingKey {
        case explicitNil
        case metadata
        case values
    }

    enum MetadataKeys: String, CodingKey {
        case id
    }

    enum ChildKeys: String, CodingKey {
        case name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNil(forKey: .explicitNil)

        var metadata = container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata)
        try metadata.encode("document-1", forKey: .id)

        var values = container.nestedUnkeyedContainer(forKey: .values)
        try values.encode(1)
        try values.encodeNil()
        var child = values.nestedContainer(keyedBy: ChildKeys.self)
        try child.encode("leaf", forKey: .name)
    }
}

private struct RevisionPayload: Codable, Equatable {
    let id: String
    let name: String
    let values: [Int]
}

private enum StrategyError: Error, Equatable {
    case dateEncoding
    case dateDecoding
    case dataEncoding
    case dataDecoding
}

private func XCTAssertNSDictionaryEqual(
    _ actual: [String: Any],
    _ expected: [String: Any],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(NSDictionary(dictionary: actual), NSDictionary(dictionary: expected), file: file, line: line)
}

private func assertDataCorrupted(
    _ error: Error,
    expectedPath: [String],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard case DecodingError.dataCorrupted(let context) = error else {
        return XCTFail("Expected dataCorrupted, got \(error)", file: file, line: line)
    }
    XCTAssertEqual(context.codingPath.map(\.stringValue), expectedPath, file: file, line: line)
}

private func assertTypeMismatch(
    _ error: Error,
    expectedPath: [String],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard case DecodingError.typeMismatch(_, let context) = error else {
        return XCTFail("Expected typeMismatch, got \(error)", file: file, line: line)
    }
    XCTAssertEqual(context.codingPath.map(\.stringValue), expectedPath, file: file, line: line)
}
