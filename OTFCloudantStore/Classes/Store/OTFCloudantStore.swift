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

import Foundation
import OTFCDTDatastore
import OTFUtilities
#if CARE && HEALTH
import OTFCareKitStore
import HealthKit
#elseif HEALTH
import HealthKit
#elseif CARE
import OTFCareKitStore
#endif

// swiftlint:disable all
/**
 - Description: OTFCloudantStore uses CDTDataStore as It's database. It provides functionalities to help on working with Carekit, HealthKit and OTFResearchKit
 */
open class OTFCloudantStore: Equatable {

    #if CARE
    /// The delegate receives callbacks when the contents of the patient store are modified.
    /// In `CareKit` apps, the delegate will be set automatically, and it should not be modified.
    public weak var patientDelegate: OCKPatientStoreDelegate?

    /// The delegate receives callbacks when the contents of the care plan store are modified.
    /// In `CareKit` apps, the delegate will be set automatically, and it should not be modified.
    public weak var carePlanDelegate: OCKCarePlanStoreDelegate?

    /// The delegate receives callbacks when the contents of the contacts store are modified.
    /// In `CareKit` apps, the delegate will be set automatically, and it should not be modified.
    public weak var contactDelegate: OCKContactStoreDelegate?

    /// The delegate receives callbacks when the contents of the tasks store are modified.
    /// In `CareKit` apps, the delegate will be set automatically, and it should not be modified.
    public weak var taskDelegate: OCKTaskStoreDelegate?

    /// The delegate receives callbacks when the contents of the outcome store are modified.
    /// In `CareKit` apps, the delegate will be set automatically, and it should not be modified.
    public weak var outcomeDelegate: OCKOutcomeStoreDelegate?

    /// The configuration can be modified to enable or disable versioning of database entities.
    public var resetDelegate: OCKResetDelegate?
    #endif

    /// The name of the store. When the store type is `onDisk`, this name will be used for the SQLite filename.
    public let storeName: String
    public let dataStore: CDTDatastore
    public let datastoreManager: CDTDatastoreManager

    /**
    - Description - Initializer for OTFCloudantStore
    - Parameter storeName: Store name required to initialize OTFCloudantStore
    - Throws - This initializer can throw an error, that should be handled using try and catch block.
    */
    public init(storeName: String) throws {
        self.storeName = storeName
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).last else {
            throw NSError(domain: "com.cloudant", code: 400, userInfo: [NSLocalizedDescriptionKey: "Can't access the document directory."])
        }
        let storeURL = documentsDirectory.appendingPathExtension("/\(DataStoreName.manager)")
        let path = storeURL.path
        self.datastoreManager = try CDTDatastoreManager(directory: path)

        let datastore = try datastoreManager.datastoreNamed(storeName)
        if let indexName = datastore.ensureIndexed(["id", "effectiveDate"]) {
            NSLog("indexName: \(indexName)")
        }
        self.dataStore = datastore
    }

    /**
    - Description - Function to compare two OTFCloudantStore objects for their equality.
    /// - Parameters:
    ///   - lhs: First OTFCloudantStore object that we need to compare
    ///   - rhs: Second OTFCloudantStore object that will be compared for equality.
    /// - Returns: It will return a Bool value depends upon if the both OTFCloudantStore objects are equal or not.
     */
    public static func == (lhs: OTFCloudantStore, rhs: OTFCloudantStore) -> Bool {
        return lhs.storeName == rhs.storeName
    }
}

#if CARE && HEALTH
extension OTFCloudantStore: OCKStoreProtocol, OCKAnyTaskStore {

    /**
     - Description: - This function can be used to reset all the data from CloudantStore as well as HealthKit.
     - Throws: - This can throw an error, it should be handled using try, catch block properly.
     */
    public func reset() throws {
        let sampleType: OTFHealthSampleType = .quantity
        collection(healthKitSampleType: sampleType).getSamples { result in
            switch result {
            case .success(let samples):
                self.deleteSamples(samples: samples)
                if let delegate = self.resetDelegate {
                    delegate.storeDidReset(self)
                } else {
                    OTFLog("Reset delegate is nil, Please assign value to reset delegate in order to get notified after reset finish.", "failure")
                }
            case .failure: break
            }
        }
    }

    // MARK: - CRUD Operations
    // MARK: - Create query for CareKitData
    public func collection(className: String, fields: [String]? = nil) -> OTFCloudantQuery {
        let query = OTFCloudantQuery(store: self, careKitClassName: className, fields: fields)
        return query
    }

    // MARK: - Create Query for HealthKitData
    public func collection(healthKitSampleType: OTFHealthSampleType, fields: [String]? = nil) -> OTFCloudantQuery {
        let query = OTFCloudantQuery(store: self, healthKitSampleType: healthKitSampleType, fields: fields)
        return query
    }

    // MARK: - Delete healthkit samples
    // swiftlint:disable closure_spacing
    public func deleteSamples(samples: [HKSample], callbackQueue: DispatchQueue = .main, completion: OCKResultClosure<[HKSample]>? = nil) {
        let cloudantSamples = samples.map { OTFCloudantSample(sample: $0, patientId: "")}
        delete(cloudantSamples) { (result) in
            switch result {
            case .success:
                completion?(.success(samples))
            case .failure(let error):
                OTFError("Deleting samples failed with error: %{public}@", error.localizedDescription)
                completion?(.failure(error.toOCKStoreError()))
            }
        }
    }

    // Maybe use this so that we have only one database?
    open func fetch<Entity: Codable & Identifiable & OTFCloudantRevision>(cloudantQuery: OTFQueryProtocol,
                                                                          callbackQueue: DispatchQueue = .main,
                                                                          filter: ((Entity) -> Bool)? = nil,
                                                                          completion: OCKResultClosure<[Entity]>? = nil)
        where Entity.ID == String {
            var query = cloudantQuery.parameters

            // "entityType" is something that will not have any representation in the CareKit
            // It only serves the Cloudant serialization and deserialization purposes
            // Encoding and decoding
            query["entityType"] = "\(Entity.self)"

            var errors = [Error]()
            var succeededItems = [Entity]()
            let result = dataStore.find(query, skip: 0, limit: UInt(cloudantQuery.limit ?? 0), fields: nil, sort: cloudantQuery.sortDescription)
            result?.enumerateObjects({ (revision: CDTDocumentRevision, offset: UInt, pointer: UnsafeMutablePointer<ObjCBool>) in
                do {
                    if var item = try revision.data(as: Entity.self) {
                        if let filterClosure = filter, filterClosure(item) == false {
                            return
                        }
                        
                        item.revId = revision.revId
                        succeededItems.append(item)
                    }
                } catch {
                    errors.append(error)
                }
            })

            callbackQueue.async {
                if succeededItems.count > 0 {
                    callbackQueue.async {
                        NSLog("Successfully fetched: \(succeededItems.map { $0.toDictionary() })")
                        completion?(.success(succeededItems))
                    }
                } else if errors.count > 0 {
                    callbackQueue.async {
                        NSLog("Failed to fetch: Errors: \(errors.map { $0.localizedDescription })")
                        completion?(.failure(.fetchFailed(reason: "Errors: \(errors.map { $0.localizedDescription })")))
                    }
                } else {
                    NSLog("Returning empty data")
                    completion?(.success([]))
                }
            }
    }

    /**
     Adds the document to the data store.
     
     - Parameter items: the entities whose document is added to the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func add<Entity: Codable & Identifiable & OTFCloudantRevision>(_ items: [Entity],
                          callbackQueue: DispatchQueue = .main,
                          completion: ((Result<[Entity], OTFCloudantError>) -> Void)? = nil)
        where Entity.ID == String {
            processWithCallback(items: items, process: { item in
                let revision = CDTDocumentRevision.revision(fromEntity: item)
                do {
                    let document = try dataStore.createDocument(from: revision)
                    NSLog("Added document: \(document)")
                    return try revision.data(as: Entity.self)
                } catch {
                    OTFError("Error: %{public}@", error.localizedDescription)
                    
                    throw error
                }
            }, failureError: { (items, errors) -> OTFCloudantError in
                NSLog("Adding Failed: [\(items)]. Errors: \(errors.map { $0.localizedDescription })")
                return .addFailed(reason: "[\(items)]. Errors: \(errors.map { $0.localizedDescription })")
            }, completion: completion)
    }

    /**
     Updates the document in the data store.
     
     - Parameter items: the entities whose document is updates in the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func update<Entity: Codable & Identifiable & OTFCloudantRevision>(_ items: [Entity],
                             callbackQueue: DispatchQueue = .main,
                             completion: ((Result<[Entity], OTFCloudantError>) -> Void)? = nil)
        where Entity.ID == String {
            processWithCallback(items: items, process: { item in
                let revision = CDTDocumentRevision.revision(fromEntity: item)
                do {
                    try dataStore.updateDocument(from: revision)
                    return try revision.data(as: Entity.self)
                } catch {
                    OTFError("Error: %{public}@", error.localizedDescription)
                    throw error
                }
            }, failureError: { (items, errors) -> OTFCloudantError in
                return .updateFailed(reason: "[\(items)]. Errors: \(errors.map { $0.localizedDescription })")
            }, completion: completion)
    }

    /**
     Deletes the document from the data store.
     
     - Parameter items: the entities whose document is deleted from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func delete<Entity: Encodable & Identifiable>(_ items: [Entity],
                             callbackQueue: DispatchQueue = .main,
                             completion: ((Result<[Entity], OTFCloudantError>) -> Void)? = nil)
                             where Entity.ID == String {
        process(items: items, process: { item in
            try dataStore.deleteDocument(withId: item.id)
        }, failureError: { (items, errors) -> OTFCloudantError in
            return .deleteFailed(reason: "[\(items)]. Errors: \(errors.map { $0.localizedDescription })")
        }, completion: completion)
    }

    /**
     Process to perform actions on the document in the data store.
     
     - Parameter items: the entities whose document is processed in the store.
     - Parameter process: the action which is to be processed.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter failureError: the error thrown during the process.
     - Parameter completion: a callback that fires on a background thread.
     */
    private func process<Entity: Encodable & Identifiable>(items: [Entity],
                                                           process: (_ item: Entity) throws -> Void,
                                                           callbackQueue: DispatchQueue = .main,
                                                           failureError: @escaping (_ items: [Entity], _ errors: [Error]) -> OTFCloudantError,
                                                           completion: ((Result<[Entity], OTFCloudantError>) -> Void)? = nil)
        where Entity.ID == String {

        var failedItems = [Entity]()
        var errors = [Error]()
        var succeededItems = [Entity]()

        for item in items {
            do {
                try process(item)
                succeededItems.append(item)
            } catch {
                failedItems.append(item)
                errors.append(error)
            }
        }

        callbackQueue.async {
            if succeededItems.count > 0 {
                completion?(.success(items))
            }
            if failedItems.count > 0 {
                completion?(.failure(failureError(failedItems, errors)))
            }
        }
    }
    
    /**
     Process to perform actions on the document in the data store.
     
     - Parameter items: the entities whose document is processed in the store.
     - Parameter process: the action which is to be processed.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter failureError: the error thrown during the process.
     - Parameter completion: a callback that fires on a background thread.
     */
    private func processWithCallback<Entity: Encodable & Identifiable>(items: [Entity],
                                                           process: (_ item: Entity) throws -> Entity?,
                                                           callbackQueue: DispatchQueue = .main,
                                                           failureError: @escaping (_ items: [Entity], _ errors: [Error]) -> OTFCloudantError,
                                                           completion: ((Result<[Entity], OTFCloudantError>) -> Void)? = nil)
        where Entity.ID == String {

        var failedItems = [Entity]()
        var errors = [Error]()
        var succeededItems = [Entity]()

        for item in items {
            do {
                let processedItem = try process(item)
                if let newItem = processedItem {
                    succeededItems.append(newItem)
                } else {
                    succeededItems.append(item)
                }
            } catch {
                failedItems.append(item)
                errors.append(error)
            }
        }

        callbackQueue.async {
            if succeededItems.count > 0 {
                completion?(.success(succeededItems))
            }
            if failedItems.count > 0 {
                completion?(.failure(failureError(failedItems, errors)))
            }
        }
    }
    
}
#endif
