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
import WatchConnectivity
import OTFCareKitStore
import OTFCDTDatastore

public enum OTFWatchConnectivityMessageKey {
    public static let incrementalRevisionPush = "OCKPeerIncrementalRevisionPush"
    public static let databaseSynced = "databaseSynced"
    public static let watchAppUpdate = "watchAppUpdate"
    public static let revisionError = "OCKPeerRevisionErrorKey"
    public static let revisionPushResult = "revisionPushResult"
    public static let watchAuthCommand = "watchAuthCommand"
    public static let authSessionID = "authSessionID"
    public static let authCommandGeneration = "authCommandGeneration"

    fileprivate static let revisionRequest = "OCKPeerRevisionRequest"
    fileprivate static let revisionReply = "OCKPeerRevisionReply"
    fileprivate static let revisionPush = "OCKPeerRevisionPush"
    fileprivate static let legacyError = "error"
}

@available(*, deprecated, message: "Use OTFWatchConnectivityMessageKey.databaseSynced instead.", renamed: "OTFWatchConnectivityMessageKey.databaseSynced")
public let databaseSyncedKey = OTFWatchConnectivityMessageKey.databaseSynced

@available(*, deprecated, message: "Use OTFWatchConnectivityMessageKey.watchAppUpdate instead.", renamed: "OTFWatchConnectivityMessageKey.watchAppUpdate")
public let watchAppUpdate = OTFWatchConnectivityMessageKey.watchAppUpdate

public struct OTFWatchAuthContext: Equatable {
    public let sessionID: String
    public let generation: Int

    public init(sessionID: String, generation: Int) {
        self.sessionID = sessionID
        self.generation = generation
    }

    public init?(message: [String: Any]) {
        guard let sessionID = message[OTFWatchConnectivityMessageKey.authSessionID] as? String,
              !sessionID.isEmpty,
              let generation = message[OTFWatchConnectivityMessageKey.authCommandGeneration] as? Int else {
            return nil
        }

        self.sessionID = sessionID
        self.generation = generation
    }

    public func addingFields(to message: [String: Any]) -> [String: Any] {
        var message = message
        message[OTFWatchConnectivityMessageKey.authSessionID] = sessionID
        message[OTFWatchConnectivityMessageKey.authCommandGeneration] = generation
        return message
    }
}

public struct OTFWatchSyncDeletion: Equatable {
    public enum EntityType: String {
        case task = "OCKTask"
        case outcome = "OCKOutcome"
    }

    private enum MessageKey {
        static let documentID = "documentID"
        static let entityType = "entityType"
        static let taskUUID = "taskUUID"
        static let occurrenceIndex = "occurrenceIndex"
    }

    public let documentID: String
    public let entityType: EntityType
    public let taskUUID: UUID?
    public let occurrenceIndex: Int?

    public init(
        documentID: String,
        entityType: EntityType,
        taskUUID: UUID? = nil,
        occurrenceIndex: Int? = nil
    ) {
        self.documentID = documentID
        self.entityType = entityType
        self.taskUUID = taskUUID
        self.occurrenceIndex = occurrenceIndex
    }

    var message: [String: Any] {
        var message: [String: Any] = [
            MessageKey.documentID: documentID,
            MessageKey.entityType: entityType.rawValue
        ]
        if let taskUUID {
            message[MessageKey.taskUUID] = taskUUID.uuidString
        }
        if let occurrenceIndex {
            message[MessageKey.occurrenceIndex] = occurrenceIndex
        }
        return message
    }

    init?(message: [String: Any]) {
        guard let documentID = message[MessageKey.documentID] as? String,
              let entityTypeRawValue = message[MessageKey.entityType] as? String,
              let entityType = EntityType(rawValue: entityTypeRawValue) else {
            return nil
        }

        let taskUUID: UUID?
        if let taskUUIDString = message[MessageKey.taskUUID] as? String {
            guard let parsedTaskUUID = UUID(uuidString: taskUUIDString) else {
                return nil
            }
            taskUUID = parsedTaskUUID
        } else if message[MessageKey.taskUUID] != nil {
            return nil
        } else {
            taskUUID = nil
        }

        let occurrenceIndex: Int?
        if let parsedOccurrenceIndex = message[MessageKey.occurrenceIndex] as? Int {
            occurrenceIndex = parsedOccurrenceIndex
        } else if message[MessageKey.occurrenceIndex] != nil {
            return nil
        } else {
            occurrenceIndex = nil
        }

        if entityType == .outcome {
            if (taskUUID == nil) != (occurrenceIndex == nil) {
                return nil
            }
            if taskUUID == nil,
               occurrenceIndex == nil,
               !Self.isCanonicalOutcomeDocumentID(documentID) {
                return nil
            }
        }

        self.documentID = documentID
        self.entityType = entityType
        self.taskUUID = taskUUID
        self.occurrenceIndex = occurrenceIndex
    }

    private static func isCanonicalOutcomeDocumentID(_ documentID: String) -> Bool {
        guard let separatorRange = documentID.range(of: "_", options: .backwards) else {
            return false
        }

        let uuidString = String(documentID[..<separatorRange.lowerBound])
        let occurrenceIndexString = String(documentID[separatorRange.upperBound...])
        return UUID(uuidString: uuidString) != nil && Int(occurrenceIndexString) != nil
    }
}

public struct OTFWatchSyncPayload {
    private enum MessageKey {
        static let schemaVersion = "schemaVersion"
        static let tasks = "tasks"
        static let outcomes = "outcomes"
        static let deletedDocuments = "deletedDocumentIDs"
        static let deletions = "deletions"
    }

    public let schemaVersion: Int
    public let tasks: [Data]
    public let outcomes: [Data]
    public let deletions: [OTFWatchSyncDeletion]
    public let legacyDeletedDocumentIDs: [String]

    public var deletedDocumentIDs: [String] {
        let typedDocumentIDs = deletions.map(\.documentID)
        if typedDocumentIDs.isEmpty {
            return legacyDeletedDocumentIDs
        }
        let legacyDocumentIDs = legacyDeletedDocumentIDs.filter { !typedDocumentIDs.contains($0) }
        return typedDocumentIDs + legacyDocumentIDs
    }

    public init(
        schemaVersion: Int = 2,
        tasks: [Data] = [],
        outcomes: [Data] = [],
        deletions: [OTFWatchSyncDeletion] = [],
        deletedDocumentIDs: [String] = []
    ) {
        self.schemaVersion = deletions.isEmpty && !deletedDocumentIDs.isEmpty ? 1 : schemaVersion
        self.tasks = tasks
        self.outcomes = outcomes
        self.deletions = deletions
        self.legacyDeletedDocumentIDs = deletedDocumentIDs
    }

    public var isEmpty: Bool {
        tasks.isEmpty && outcomes.isEmpty && deletions.isEmpty && legacyDeletedDocumentIDs.isEmpty
    }

    public var message: [String: Any] {
        var message: [String: Any] = [
            MessageKey.schemaVersion: schemaVersion,
            MessageKey.tasks: tasks,
            MessageKey.outcomes: outcomes,
            MessageKey.deletions: deletions.map(\.message)
        ]
        if !legacyDeletedDocumentIDs.isEmpty {
            message[MessageKey.deletedDocuments] = legacyDeletedDocumentIDs
        }
        return message
    }

    public init?(message: [String: Any]) {
        let schemaVersion = message[MessageKey.schemaVersion] as? Int ?? 1
        let tasks = message[MessageKey.tasks] as? [Data] ?? []
        let outcomes = message[MessageKey.outcomes] as? [Data] ?? []
        let deletionMessages = message[MessageKey.deletions] as? [[String: Any]] ?? []
        let deletions = deletionMessages.compactMap(OTFWatchSyncDeletion.init(message:))
        let legacyDeletedDocumentIDs = message[MessageKey.deletedDocuments] as? [String] ?? []

        if deletionMessages.count != deletions.count {
            return nil
        }

        if tasks.isEmpty && outcomes.isEmpty && deletions.isEmpty && legacyDeletedDocumentIDs.isEmpty {
            return nil
        }

        self.schemaVersion = schemaVersion
        self.tasks = tasks
        self.outcomes = outcomes
        self.deletions = deletions
        self.legacyDeletedDocumentIDs = legacyDeletedDocumentIDs
    }
}

public enum OTFWatchDeliveryOutcome: Equatable {
    case delivered
    case queued
}

protocol WatchSessioning: AnyObject {
    var activationState: WCSessionActivationState { get }
    var isReachable: Bool { get }

#if os(iOS)
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
#endif

#if os(watchOS)
    var isCompanionAppInstalled: Bool { get }
    var iOSDeviceNeedsUnlockAfterRebootForReachability: Bool { get }
#endif

    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    )
    func transferUserInfo(_ message: [String: Any])
}

private final class WCSessionAdapter: WatchSessioning {
    private let session: WCSession

    init(session: WCSession) {
        self.session = session
    }

    var activationState: WCSessionActivationState {
        session.activationState
    }

    var isReachable: Bool {
        session.isReachable
    }

#if os(iOS)
    var isPaired: Bool {
        session.isPaired
    }

    var isWatchAppInstalled: Bool {
        session.isWatchAppInstalled
    }
#endif

#if os(watchOS)
    var isCompanionAppInstalled: Bool {
        session.isCompanionAppInstalled
    }

    var iOSDeviceNeedsUnlockAfterRebootForReachability: Bool {
        session.iOSDeviceNeedsUnlockAfterRebootForReachability
    }
#endif

    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    func transferUserInfo(_ message: [String: Any]) {
        session.transferUserInfo(message)
    }
}

/// `OTFWatchConnectivityPeer` enables synchronizing two instances of `CloudantStore`
/// where one store is part of an iPhone app and the other belongs to the watchOS companion
/// app.
///
/// The watch is capable of waking its companion app to send it messages, so the watch can
/// synchronize with the phone at any time. The phone however, cannot wake the watch, so
/// synchronizations initiated from the phone will only succeed when the companion app is in a
/// reachable state.
open class OTFWatchConnectivityPeer: OCKRemoteSynchronizable {

    private let session: WatchSessioning

    public init() {
        session = WCSessionAdapter(session: WCSession.default)
    }

    init(session: WatchSessioning) {
        self.session = session
    }
    
    /// You should call this method anytime you receive a message from the companion app.
    /// CareKit will inspect the message to see if it contains any synchronization requests that
    /// require a response. If there are, the appropriate response will be returned. Be sure to
    /// pass the returned keys and values to the reply handler in `WCSessionDelegate`'s
    /// `session(_:didReceiveMessage:replyHandler:)` method.
    ///
    /// - Parameters:
    ///   - peerMessage: A message received from the peer for which a response will be created.
    ///   - store: A store from which the reply can be built.
    ///   - sendReply: A callback that will be invoked with the response when it is ready.
    
    public func reply(to peerMessage: [String: Any],
                      store: OTFCloudantStore,
                      sendReply: @escaping (_ message: [String: Any]) -> Void) {
        
        // If the peer requested the latest revision, compute and return it.
        if peerMessage[OTFWatchConnectivityMessageKey.revisionRequest] is String {
            store.computeRevision(store: store) { result in
                if let data = result {
                    sendReply([OTFWatchConnectivityMessageKey.revisionReply: data])
                } else {
                    sendReply([OTFWatchConnectivityMessageKey.revisionError: "Revision Error"])
                }
            }
            return
        }
        
        // If the peer just pushed a revision, attempt to merge.
        // If unsuccessful, send back an error.
        if peerMessage[OTFWatchConnectivityMessageKey.revisionPush] is String {
            pullRevisions { revision in
                store.mergeRevision(revision)
                sendReply([:])
            } completion: { error in
                if let error = error {
                    sendReply([OTFWatchConnectivityMessageKey.revisionError: error])
                }
            }
            return
        }

        if let payloadMessage = peerMessage[OTFWatchConnectivityMessageKey.incrementalRevisionPush] as? [String: Any] {
            guard let payload = OTFWatchSyncPayload(message: payloadMessage) else {
                sendReply([OTFWatchConnectivityMessageKey.revisionError: "Invalid incremental sync payload"])
                return
            }

            do {
                let result = try store.applyIncrementalSync(payload: payload)
                sendReply([
                    OTFWatchConnectivityMessageKey.revisionPushResult: [
                        "tasks": result.tasks,
                        "outcomes": result.outcomes,
                        "deletions": result.deletions,
                        "skipped": result.skipped,
                        "skippedDeletions": result.skippedDeletions
                    ]
                ])
            } catch {
                sendReply([OTFWatchConnectivityMessageKey.revisionError: error.localizedDescription])
            }
            return
        }
    }
    // MARK: OCKRemoteSynchronizable
    
    public var automaticallySynchronizes: Bool = true
    
    public weak var delegate: OCKRemoteSynchronizationDelegate?
    public var outboundMessageContextProvider: (() -> OTFWatchAuthContext?)?
    
    /// Requests a full snapshot from the paired device using the current auth context.
    public func pullRevisions(mergeRevision: @escaping ([String: [Data]]) -> Void,
                              completion: @escaping (Error?) -> Void) {
        
        do {
            try validateSession()
            let message = addingOutboundContext(to: [
                OTFWatchConnectivityMessageKey.revisionRequest: "Sending pull request from watch App"
            ])
            session.sendMessage(
                message,
                replyHandler: { response in
                    if let data = response[OTFWatchConnectivityMessageKey.revisionReply] as? [String: [Data]] {
                        mergeRevision(data)
                        completion(nil)
                    } else {
                        let error = OCKStoreError.remoteSynchronizationFailed(reason: "No Tasks for today")
                        completion(error)
                    }
                    
                },
                errorHandler: completion)
        } catch {
            completion(error)
        }
    }
    
    public func pushRevisions(completion: @escaping (Error?) -> Void) {
        do {
            try validateSession()
            let message = addingOutboundContext(to: [
                OTFWatchConnectivityMessageKey.revisionPush: "Sending push request from mobile app"
            ])
            
            session.sendMessage(
                message,
                replyHandler: { message in
                    
                    if let problem = message[OTFWatchConnectivityMessageKey.revisionError] as? String {
                        let error = OCKStoreError.remoteSynchronizationFailed(reason: problem)
                        completion(error)
                    } else {
                        completion(nil)
                    }
                },
                errorHandler: completion)
            
        } catch {
            completion(error)
        }
    }

    public func pushIncrementalPayload(_ payload: OTFWatchSyncPayload, completion: @escaping (Error?) -> Void) {
        pushIncrementalPayloadWithDeliveryOutcome(payload) { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }

    /// Sends an incremental payload and reports whether it was delivered immediately or queued.
    public func pushIncrementalPayloadWithDeliveryOutcome(
        _ payload: OTFWatchSyncPayload,
        completion: @escaping (Result<OTFWatchDeliveryOutcome, Error>) -> Void
    ) {
        guard !payload.isEmpty else {
            completion(.success(.delivered))
            return
        }

        let message = addingOutboundContext(to: [
            OTFWatchConnectivityMessageKey.incrementalRevisionPush: payload.message
        ])

        do {
            try validateQueuedDeliverySession()
        } catch {
            completion(.failure(error))
            return
        }

        guard session.isReachable else {
            session.transferUserInfo(message)
            completion(.success(.queued))
            return
        }

        session.sendMessage(
            message,
            replyHandler: { response in
                switch OTFWatchConnectivityPeer.incrementalDeliveryResult(for: response) {
                case .success(let outcome):
                    completion(.success(outcome))
                case .failure(let error):
                    completion(.failure(error))
                }
            },
            errorHandler: { [weak self] error in
                guard let self else {
                    completion(.failure(error))
                    return
                }

                if self.shouldFallbackToQueuedDelivery(for: error) {
                    self.session.transferUserInfo(message)
                    completion(.success(.queued))
                } else {
                    completion(.failure(error))
                }
            }
        )
    }

    static func incrementalDeliveryResult(for response: [String: Any]) -> Result<OTFWatchDeliveryOutcome, Error> {
        if let error = response[OTFWatchConnectivityMessageKey.revisionError] as? Error ??
            response[OTFWatchConnectivityMessageKey.legacyError] as? Error {
            return .failure(error)
        }

        if let problem = response[OTFWatchConnectivityMessageKey.revisionError] as? String ??
            response[OTFWatchConnectivityMessageKey.legacyError] as? String {
            return .failure(OCKStoreError.remoteSynchronizationFailed(reason: problem))
        }

        if let validationError = validateIncrementalResultCounts(in: response) {
            return .failure(validationError)
        }

        if let skippedDeletions = incrementalResultInt("skippedDeletions", in: response),
           skippedDeletions > 0 {
            return .failure(OCKStoreError.remoteSynchronizationFailed(
                reason: "Incremental sync skipped deletion request"
            ))
        }

        return .success(.delivered)
    }

    private static func validateIncrementalResultCounts(in response: [String: Any]) -> Error? {
        guard response[OTFWatchConnectivityMessageKey.revisionPushResult] != nil else {
            return nil
        }

        guard let result = incrementalResultDictionary(in: response) else {
            return OCKStoreError.remoteSynchronizationFailed(reason: "Invalid incremental sync reply")
        }

        for key in ["tasks", "outcomes", "deletions", "skipped", "skippedDeletions"] where result[key] != nil {
            guard let count = incrementalResultCount(from: result[key]), count >= 0 else {
                return OCKStoreError.remoteSynchronizationFailed(reason: "Invalid incremental sync reply")
            }
        }

        return nil
    }

    private static func incrementalResultInt(_ key: String, in response: [String: Any]) -> Int? {
        guard let result = incrementalResultDictionary(in: response) else { return nil }
        return incrementalResultCount(from: result[key])
    }

    private static func incrementalResultDictionary(in response: [String: Any]) -> [String: Any]? {
        guard let result = response[OTFWatchConnectivityMessageKey.revisionPushResult] else { return nil }
        if let typedResult = result as? [String: Int] {
            return typedResult.reduce(into: [String: Any]()) { dictionary, entry in
                dictionary[entry.key] = entry.value
            }
        }

        if let anyResult = result as? [String: Any] {
            return anyResult
        }

        if let dictionaryResult = result as? NSDictionary {
            var result = [String: Any]()
            for (key, value) in dictionaryResult {
                guard let stringKey = key as? String else { return nil }
                result[stringKey] = value
            }
            return result
        }

        return nil
    }

    private static func incrementalResultCount(from value: Any?) -> Int? {
        if value is Bool { return nil }
        if let intValue = value as? Int {
            return intValue
        }
        if let numberValue = value as? NSNumber {
            let doubleValue = numberValue.doubleValue
            guard doubleValue.isFinite,
                  doubleValue.rounded(.towardZero) == doubleValue,
                  doubleValue >= Double(Int.min),
                  doubleValue <= Double(Int.max) else {
                return nil
            }
            return Int(doubleValue)
        }
        return nil
    }
    
    public func updatewatchOS() {
        deliverQueuedNotification([OTFWatchConnectivityMessageKey.databaseSynced: "Success"])
    }
    
    public func dataUpdateOnWatch() {
        deliverQueuedNotification([OTFWatchConnectivityMessageKey.watchAppUpdate: "Success"])
    }
    
    public func chooseConflictResolution(conflicts: [OCKEntity],
                                         completion: @escaping OCKResultClosure<OCKEntity>) {
    }
    
    // MARK: Test Seams

#if DEBUG
    func messageWithOutboundContextForTesting(_ message: [String: Any]) -> [String: Any] {
        addingOutboundContext(to: message)
    }
#endif
    
    func validateSession() throws {
        try validateQueuedDeliverySession()

        if !session.isReachable {
            throw OCKStoreError.remoteSynchronizationFailed(
                reason: "Companion app is not reachable")
        }
    }

    private func validateQueuedDeliverySession() throws {
        if session.activationState != .activated {
            throw OCKStoreError.remoteSynchronizationFailed(reason:
            """
            WatchConnectivity session has not been activated yet. \
            Make sure you have set the delegate for and activated \
            `WCSession.default` before attempting to synchronize \
            `OCKWatchConnectivityPeer`.
            """)
        }

#if os(iOS)
        if !session.isPaired {
            throw OCKStoreError.remoteSynchronizationFailed(
                reason: "No Apple Watch is paired")
        }
        
        if !session.isWatchAppInstalled {
            throw OCKStoreError.remoteSynchronizationFailed(
                reason: "Companion app not installed on Apple Watch")
        }
#endif
        
#if os(watchOS)
        if !session.isCompanionAppInstalled {
            throw OCKStoreError.remoteSynchronizationFailed(reason:
            """
            Could not complete synchronization because the companion \
            app is not installed on the peer iOS device.
            """)
        }
        
        if session.iOSDeviceNeedsUnlockAfterRebootForReachability {
            throw OCKStoreError.remoteSynchronizationFailed(reason:
            """
            iOS peer has recently been rebooted and needs to be unlocked \
            at least once before the companion app can be woken up.
            """
            )
        }
#endif
    }

    private func shouldFallbackToQueuedDelivery(for error: Error) -> Bool {
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

        return false
    }

    /// Adds the current auth context to outbound watch messages when one is available.
    private func addingOutboundContext(to message: [String: Any]) -> [String: Any] {
        guard let context = outboundMessageContextProvider?() else {
            return message
        }
        return context.addingFields(to: message)
    }

    /// Delivers a queued notification, falling back to `transferUserInfo` when needed.
    private func deliverQueuedNotification(_ message: [String: Any]) {
        let message = addingOutboundContext(to: message)

        do {
            try validateQueuedDeliverySession()
        } catch {
            return
        }

        guard session.isReachable else {
            session.transferUserInfo(message)
            return
        }

        session.sendMessage(
            message,
            replyHandler: nil,
            errorHandler: { [weak self] error in
                guard let self else { return }
                if self.shouldFallbackToQueuedDelivery(for: error) {
                    self.session.transferUserInfo(message)
                }
            }
        )
    }
}
