/*
Copyright (c) 2021, Hippocrates Technologies S.r.l.. All rights reserved.

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
import os.log
import OTFCareKitStore
import OTFCDTDatastore

private let tasksKey = "tasks"
private let outcomesKey = "outcomes"

public enum Target {
    case mobile, watchOS, watchAppUpdate
}

extension OTFCloudantStore: OCKRemoteSynchronizationDelegate {
    
    public func remote(_ remote: OCKRemoteSynchronizable, didUpdateProgress progress: Double) {
        
    }
    
    public func didRequestSynchronization(_ remote: OCKRemoteSynchronizable) {
        os_log("Remote requested synchronization", type: .debug)
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
    public func synchronize(target: Target = Target.watchOS, completion: @escaping(Error?) -> Void) {
        switch target {
        case .watchOS:
            pull(completion: completion)
        case .mobile:
            push(completion: completion)
        case .watchAppUpdate:
            watchAppUpdate(completion: completion)
        }
    }
    
    /// Calls synchronize if the remote is set and requests to notified after each database modification.
    func autoSynchronizeIfRequired() {
        if remote?.automaticallySynchronizes == true {
            push { error in
                if let error = error {
                    os_log("Failed to automatically synchronize. %{private}@",
                           type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    private func pull(completion: @escaping (Error?) -> Void){
        // 1. Make sure a remote is setup
        guard let remote = self.remote else {
            completion(OCKStoreError.remoteSynchronizationFailed(
                reason: "No remote set on OTFCloudantStore!"))
            return
        }
        
        // 2. Pull revisions
        remote.pullRevisions() { revision in
            print("Pull revisions \(revision)")
            self.mergeRevision(revision)
            completion(nil)
        } completion: { error in
            if let error = error {
                completion(error)
            }
        }
    }
    
    private func push(completion: @escaping (Error?) -> Void){
        guard let remote = self.remote else {
            completion(OCKStoreError.remoteSynchronizationFailed(
                reason: "No remote set on OTFCloudantStore!"))
            return
        }
        remote.updatewatchOS()
        completion(nil)
    }
    
    private func watchAppUpdate(completion: @escaping (Error?) -> Void){
        guard let remote = self.remote else {
            completion(OCKStoreError.remoteSynchronizationFailed(
                reason: "No remote set on OTFCloudantStore!"))
            return
        }
        remote.pushRevisions { error in
            if let error = error {
                completion(error)
            } else {
                remote.updatewatchOS()
                completion(nil)
            }
        }
    }
    
    func computeRevision(store: OTFCloudantStore, completion: @escaping (([String: [Data]]?) -> Void)) {
#if CARE && HEALTH
        
        store.fetchTasks { result in
            switch result {
            case .success(let todayTasks):
                if !todayTasks.isEmpty  {
                    store.fetchOutcomes(
                    ) { result in
                        switch result {
                        case .success(let todayOutcome):
                            do {
                                var tasks : [Data] = [Data]()
                                for task in todayTasks {
                                    let dic = try JSONEncoder().encode(task)
                                    tasks.append(dic)
                                }
                                var outcomes : [Data] = [Data]()
                                for outcome in todayOutcome {
                                    let dic = try JSONEncoder().encode(outcome)
                                    outcomes.append(dic)
                                }
                                var data: [String: [Data]] = [String: [Data]]()
                                data[tasksKey] = tasks
                                data[outcomesKey] = outcomes
                                completion(data)
                            } catch _ {
                                completion(nil)
                            }
                        case .failure(_):
                            completion(nil)
                        }
                    }
                } else {
                    completion(nil)
                }
            case .failure(_):
                completion(nil)
            }
        }
#endif
    }
    
    func mergeRevision(_ revision: [String: [Data]]) {
        let tasks = revision[tasksKey]
        let outcomes = revision[outcomesKey]
        var docsIds: [String] =  [String]()
#if CARE && HEALTH
        let documents = self.dataStore.getAllDocuments()
        if let tasks = tasks, let outcomes = outcomes {
            for item in tasks {
                do {
                    let task = try JSONDecoder().decode(OCKTask.self, from: item)
                    let revision = CDTDocumentRevision.revision(fromEntity: task)
                    guard let docId = revision.docId else { return  }
                    docsIds.append(docId)
                    try resolveConflictAndStore(documents: documents, docId: docId, revision: revision)
                } catch let error {
                    print(error)
                }
            }
            for item in outcomes {
                do {
                    let outcome = try JSONDecoder().decode(OCKOutcome.self, from: item)
                    let revision = CDTDocumentRevision.revision(fromEntity: outcome)
                    guard let docId = revision.docId else { return  }
                    docsIds.append(docId)
                    try resolveConflictAndStore(documents: documents, docId: docId, revision: revision)
                } catch let error {
                    print(error)
                }
            }
            
            if let documents = documents, !documents.isEmpty   {
                for doc in documents {
                    let value = docsIds.first(where: { $0 == doc.docId })
                    if(value == nil){
                        do {
                            if let docId =  doc.docId {
                                try self.dataStore.deleteDocument(withId: docId)
                            }
                        } catch let error {
                            print(error)
                        }
                    }
                }
            }
        }
        else {
            print("Something went wrong on sync data")
        }
#endif
    }
    
    func resolveConflictAndStore(documents: [CDTDocumentRevision]?,docId : String, revision: CDTDocumentRevision) throws {
        do {
            let value = documents?.first(where: { $0.docId == docId })
            if(value == nil){
                try self.dataStore.createDocument(from: revision)
            } else {
                var rev: CDTDocumentRevision
                if  let revId = value?.revId {
                    rev  = CDTDocumentRevision(docId: docId, revId: revId)
                } else {
                    rev  = CDTDocumentRevision(docId: docId)
                }
                rev.body  = revision.body
                let _ =  try self.dataStore.updateDocument(from: rev)
            }
        } catch let error {
            throw error
        }
    }
    
    public func deleteRecords(completion: @escaping (String?) -> Void)  {
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
