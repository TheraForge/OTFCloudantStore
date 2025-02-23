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

private let revisionRequestKey = "OCKPeerRevisionRequest"
private let revisionReplyKey = "OCKPeerRevisionReply"
private let revisionPushKey = "OCKPeerRevisionPush"
private let revisionPushResultKey = "revisionPushResult"
public let databaseSyncedKey = "databaseSynced"
public let watchAppUpdate = "watchAppUpdate"

private let revisionErrorKey = "OCKPeerRevisionErrorKey"

/// `OTFWatchConnectivityPeer` enables synchronizing two instances of `CloudantStore`
/// where one store is part of an iPhone app and the other belongs to the watchOS companion
/// app.
///
/// The watch is capable of waking its companion app to send it messages, so the watch can
/// synchronize with the phone at any time. The phone however, cannot wake the watch, so
/// synchronizations initiated from the phone will only succeed when the companion app is in a
/// reachable state.
open class OTFWatchConnectivityPeer: OCKRemoteSynchronizable {
    
    public init() {}
    
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
                      sendReply: @escaping(_ message: [String: Any]) -> Void) {
        
        // If the peer requested the latest revision, compute and return it.
        if let _ = peerMessage[revisionRequestKey] as? String {
            store.computeRevision(store: store) { result in
                if let data = result {
                    sendReply([revisionReplyKey: data])
                } else {
                    sendReply([revisionErrorKey: "Revision Error"])
                }
            }
            return
        }
        
        // If the peer just pushed a revision, attempt to merge.
        // If unsuccessful, send back an error.
        if let _ = peerMessage[revisionPushKey] as? String {
            pullRevisions() { revision in
                store.mergeRevision(revision)
                sendReply([:])
            } completion: { error in
                if let error = error {
                    sendReply([revisionErrorKey: error])
                }
            }
            return
        }
    }
    // MARK: OCKRemoteSynchronizable
    
    public var automaticallySynchronizes: Bool = true
    
    public weak var delegate: OCKRemoteSynchronizationDelegate?
    
    public func pullRevisions(mergeRevision: @escaping ([String: [Data]]) -> Void,
                              completion: @escaping (Error?) -> Void) {
        
        do {
            try validateSession()
            session.sendMessage(
                [revisionRequestKey: "Sending pull request from watch App"],
                replyHandler: { response in
                    // swiftlint:disable:this force_cast
                    if let data = response[revisionReplyKey] as? [String: [Data]] {
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
            
            session.sendMessage(
                [revisionPushKey: "Sending push request from mobile app"],
                replyHandler: { message in
                    
                    if let problem = message[revisionErrorKey] as? String {
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
    
    public func updatewatchOS() {
        session.sendMessage([databaseSyncedKey: "Success"]) { _ in }
    }
    
    public func dataUpdateOnWatch(){
        session.sendMessage([watchAppUpdate: "Success"]) { _ in }
    }
    
    public func chooseConflictResolution(conflicts: [OCKEntity],
                                         completion: @escaping OCKResultClosure<OCKEntity>) {
    }
    
    // MARK: Internal
    
    fileprivate let session = WCSession.default
    
    // MARK: Test Seams
    
    func validateSession() throws {
        if session.activationState != .activated {
            throw OCKStoreError.remoteSynchronizationFailed(reason:
            """
            WatchConnectivity session has not been activated yet. \
            Make sure you have set the delegate for and activated \
            `WCSession.default` before attempting to synchronize \
            `OCKWatchConnectivityPeer`.
            """)
        }
        
        if !session.isReachable {
            throw OCKStoreError.remoteSynchronizationFailed(
                reason: "Companion app is not reachable")
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
}
