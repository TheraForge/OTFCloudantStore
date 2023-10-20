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

import UIKit
import OTFCDTDatastore

#if HEALTH
import HealthKit

// swiftlint:disable line_length
/*
 OTFCloudantQuery provides functionalities to help on querying data from OTFCloudantStore
 There're 2 types of querying data:
 1. Call method which queries data from single field and condition, this is used for simple query with one field and one condition
 example: query
 2. Call method which uses OTFCloudantQueryComponent, OTFCloudantCombinationQueryComponent or OTFCloudantComplexQueryComponent. They are used to create combined query which is use multiple fields and multiple query conditon selector and combination selector
 */
public class OTFCloudantQuery {
    private let cloudantStore: OTFCloudantStore
    private var dictionary = [String: Any]()
    private var sortDescriptors: [[String: String]]?
    private var limitNumber: UInt = 30
    private var skip: UInt = 0
    private var orderByAscending: String?
    private var orderByDescending: String?
    private var fields: [String]?

    // Use this method to init query to get CareKit data
    public init(store: OTFCloudantStore, careKitClassName: String, fields: [String]? = nil) {
        cloudantStore = store
        dictionary["entityType"] = careKitClassName
        self.fields = fields
    }

    // Use this method to init query to get HealthKit data
    public init(store: OTFCloudantStore, healthKitSampleType: OTFHealthSampleType, fields: [String]? = nil) {
        cloudantStore = store
        dictionary["entityType"] = "\(OTFCloudantSample.self)"
        dictionary["type"] = healthKitSampleType.rawValue
    }

    public init(store: OTFCloudantStore, healthSampleType: OTFHealthSampleType, fields: [String]? = nil) {
        cloudantStore = store
        dictionary["entityType"] = "OTFCloudantSample"
        dictionary["type"] = healthSampleType.rawValue
        self.fields = fields
    }

    public func `where`(_ property: String, isEqualTo value: String) -> OTFCloudantQuery {
        dictionary[property] = value
        return self
    }

    public func `where`(_ singleQuery: OTFCloudantQueryComponent, _ combinationSelector: OTFCloudantCombinationSelector, _ valueSingleQuery: OTFCloudantQueryComponent) -> OTFCloudantQuery {
        let combinedQuery = OTFCloudantCombinationQueryComponent(leftComponent: singleQuery, rightComponent: valueSingleQuery, combinationSelector: combinationSelector)
        return `where`(query: combinedQuery)
    }

    public func `where`(firstCondition: [String: Any], or secondCondition: [String: Any]) -> OTFCloudantQuery {
        dictionary["$or"] = [
            firstCondition,
            secondCondition
        ]
        return self
    }

    public func `where`(firstCondition: [String: Any], and secondCondition: [String: Any]) -> OTFCloudantQuery {
        dictionary["$and"] = [
            firstCondition,
            secondCondition
        ]
        return self
    }

    static func createAndCondition(params: [String: String]) -> [String: [[String: Any]]] {
        var conditionArray = [[String: Any]]()
        for (key, value) in params.enumerated() {
            conditionArray.append(["\(key)": value])
        }
        return ["$and": conditionArray]

    }

    public func `where`(_ property: String, isLessThan value: String) -> OTFCloudantQuery {
        dictionary[property] = ["$lt": value]
        return self
    }

    public func `where`(_ property: String, isGreeterThan value: String) -> OTFCloudantQuery {
        dictionary[property] = ["$gt": value]
        return self
    }

    public func `where`(_ property: String, isLessThanOrEquaTo value: String) -> OTFCloudantQuery {
        dictionary[property] = ["$lte": value]
        return self
    }

    public func `where`(_ property: String, isGreeterThanOrEqualTo value: String) -> OTFCloudantQuery {
        dictionary[property] = ["$gte": value]
        return self
    }

    public func `where`(_ property: String, notEqualTo value: String) -> OTFCloudantQuery {
        dictionary[property] = ["$neq": value]
        return self
    }

    // swiftlint:disable trailing_closure
    public func `where`(query: OTFCloudantQueryComponent) -> OTFCloudantQuery {
        dictionary.merge(query.toQuery(), uniquingKeysWith: { (_, last) in last })
        return self
    }

    // swiftlint:disable trailing_closure
    public func `where`(query: OTFCloudantCombinationQueryComponent) -> OTFCloudantQuery {
        dictionary.merge(query.toQuery(), uniquingKeysWith: { (_, last) in last })
        return self
    }

    // swiftlint:disable trailing_closure
    public func `where`(query: OTFCloudantComplexQueryComponent) -> OTFCloudantQuery {
        dictionary.merge(query.toQuery(), uniquingKeysWith: { (_, last) in last })
        return self
    }

    public func `where`(field: String, in values: [Any]) -> OTFCloudantQuery {
        dictionary[field] = ["$in": values]
        return self
    }

    public func `where`(field: String, notIn values: [Any]) -> OTFCloudantQuery {
        dictionary[field] = ["$nin": values]
        return self
    }

    public func `where`(field: String, exists: Bool) -> OTFCloudantQuery {
        dictionary[field] = ["$exists": exists]
        return self
    }

    public func `where`(field: String, mode divisor: Int, equal result: Int) throws -> OTFCloudantQuery {
        if divisor == 0 {
            throw OTFCloudantError.invalidValue(reason: "Divisor cannot be zero")
        } else {
            dictionary[field] = ["$mod": [divisor, result]]
        }
        return self
    }

    public func `where`(field: String, hasSize size: Int) -> OTFCloudantQuery {
        dictionary[field] = ["$size": size]
        return self
    }

    public func limit(limit: UInt) -> OTFCloudantQuery {
        limitNumber = limit
        return self
    }

    public func skip(skip: UInt) -> OTFCloudantQuery {
        self.skip = skip
        return self
    }

    /**
    - Description This function will return a query to order the result (ascending or descending) based on some propery.
     - Parameter property: give the property name by which you want to change the order of the result list.
     - Parameter ascending: Pass true or false in this to change the order of the resultant list. By default it will order the list to ascending.
     */
    public func ordered(by property: String, ascending: Bool = true) -> OTFCloudantQuery {
        if sortDescriptors == nil {
            sortDescriptors = [[String: String]]()
        }
        if ascending {
            sortDescriptors?.append([property: "asc"])
        } else {
            sortDescriptors?.append([property: "desc"])
        }
        return self
    }

    /**
     - Description this is sort query, to sort the result list in ascending manner by the given property
     - Parameter property: pass the property to sort the result list in acsending order.
     */
    public func sort(ascendingBy property: String) -> OTFCloudantQuery {
        if sortDescriptors == nil {
            sortDescriptors = [[String: String]]()
        }
        sortDescriptors?.append([property: "asc"])
        return self
    }

    /**
     - Description this is sort query, to sort the result list in descending manner by the given property
     - Parameter property: pass the property to sort the result list in descending order.
     */
    public func sort(descendingBy property: String) -> OTFCloudantQuery {
        if sortDescriptors == nil {
            sortDescriptors = [[String: String]]()
        }
        sortDescriptors?.append([property: "desc"])
        return self
    }

    /**
      - Description - This function can be used to get all the samples store in CloudantStore in the form of HKSample.
      - Parameter callbackQueue: Define on which queue you want to execute this query. Default is main.
      - Parameter completion: It will return a result object containing array of HKSamples and an OTFCloudantError.
     */
    public func getSamples(callbackQueue: DispatchQueue = .main,
                           completion: @escaping (Result<[HKSample], OTFCloudantError>) -> Void) {
        if let sortDescriptors = sortDescriptors, !sortDescriptors.isEmpty {
            let orders = sortDescriptors.flatMap { Array($0.values) }
            let sortFields = sortDescriptors.flatMap { Array($0.keys) }
            if let firstValue = orders.first {
                for order in orders where firstValue == order {
                    completion(.failure(.fetchFailed(reason: "All the sort fields should be in the same order")))
                    return
                }
            }
            let indexes = cloudantStore.dataStore.listIndexes()
            var tempSortFields = sortFields
            for key in indexes.keys {
                if let fields = indexes[key]?["fields"] as? [String] {
                    tempSortFields.removeAll { fields.contains($0) }
                }
            }
            if !tempSortFields.isEmpty {
                let adj = tempSortFields.count > 1 ? "are" : "is"
                completion(.failure(.fetchFailed(reason: "\(tempSortFields) \(adj) not indexed, the result will be empty")))
                return
            }
        }
        var errors = [Error]()
        var succeededItems = [OTFCloudantSample?]()
        let result = cloudantStore.dataStore.find(dictionary, skip: skip, limit: limitNumber, fields: fields, sort: sortDescriptors)
        result?.enumerateObjects({ (revision: CDTDocumentRevision, _: UInt, _: UnsafeMutablePointer<ObjCBool>) in
            do {
                if var item = try revision.data(as: OTFCloudantSample.self) {
                    item.revId = revision.revId
                    succeededItems.append(item)
                }
            } catch {
                errors.append(error)
            }
        })
        callbackQueue.async {
            if !succeededItems.isEmpty {
                callbackQueue.async {
                    completion(.success(succeededItems.map { $0?.toHKSample() }.compactMap { $0 }))
                }
            } else if let firstError = errors.first {
                callbackQueue.async {
                    completion(.failure(.fetchFailed(reason: firstError.localizedDescription)))
                }
            } else {
                NSLog("Returning empty data")
                completion(.success([]))
            }
        }
    }

    /**
      - Description - This function can be used to get all the samples store in CloudantStore in the form of OTFCloudantSample.
      - Parameter callbackQueue: Define on which queue you want to execute this query. Default is main.
      - Parameter completion: It will return a result object containing array of OTFCloudantSample and an OTFCloudantError.
     */
    public func getCloudantSamples(callbackQueue: DispatchQueue = .main,
                                   completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void) {
        if let sortDescriptors = sortDescriptors, !sortDescriptors.isEmpty {
            let orders = sortDescriptors.flatMap { Array($0.values) }
            let sortFields = sortDescriptors.flatMap { Array($0.keys) }
            if let firstValue = orders.first {
                for order in orders where firstValue == order {
                    completion(.failure(.fetchFailed(reason: "All the sort fields should be in the same order")))
                    return
                }
            }
            let indexes = cloudantStore.dataStore.listIndexes()
            var tempSortFields = sortFields
            for key in indexes.keys {
                if let fields = indexes[key]?["fields"] as? [String] {
                    tempSortFields.removeAll { fields.contains($0) }
                }
            }
            if !tempSortFields.isEmpty {
                let adj = tempSortFields.count > 1 ? "are" : "is"
                completion(.failure(.fetchFailed(reason: "\(tempSortFields) \(adj) not indexed, the result will be empty")))
                return
            }
        }
        var errors = [Error]()
        var succeededItems = [OTFCloudantSample?]()
        let result = cloudantStore.dataStore.find(dictionary, skip: skip, limit: limitNumber, fields: fields, sort: sortDescriptors)
        result?.enumerateObjects({ (revision: CDTDocumentRevision, _: UInt, _: UnsafeMutablePointer<ObjCBool>) in
            do {
                if var item = try revision.data(as: OTFCloudantSample.self) {
                    item.revId = revision.revId
                    succeededItems.append(item)
                }
            } catch {
                errors.append(error)
            }
        })
        callbackQueue.async {
            if !succeededItems.isEmpty {
                callbackQueue.async {
                    completion(.success(succeededItems.compactMap { $0 }))
                }
            } else if let firstError = errors.first {
                callbackQueue.async {
                    completion(.failure(.fetchFailed(reason: firstError.localizedDescription)))
                }
            } else {
                NSLog("Returning empty data")
                completion(.success([]))
            }
        }
    }

    public func get<Entity: Codable & Identifiable & OTFCloudantRevision>(callbackQueue: DispatchQueue = .main,
                                                                          completion: @escaping (Result<[Entity], OTFCloudantError>) -> Void) {
        if let sortDescriptors = sortDescriptors, !sortDescriptors.isEmpty {
            let orders = sortDescriptors.flatMap { Array($0.values) }
            let sortFields = sortDescriptors.flatMap { Array($0.keys) }
            if let firstValue = orders.first {
                for order in orders where firstValue == order {
                    completion(.failure(.fetchFailed(reason: "All the sort fields should be in the same order")))
                    return
                }
            }
            let indexes = cloudantStore.dataStore.listIndexes()
            var tempSortFields = sortFields
            for key in indexes.keys {
                if let fields = indexes[key]?["fields"] as? [String] {
                    tempSortFields.removeAll { fields.contains($0) }
                }
            }
            if !tempSortFields.isEmpty {
                let adj = tempSortFields.count > 1 ? "are" : "is"
                completion(.failure(.fetchFailed(reason: "\(tempSortFields) \(adj) not indexed, the result will be empty")))
                return
            }
        }
        var errors = [Error]()
        var succeededItems = [Entity]()
        let result = cloudantStore.dataStore.find(dictionary, skip: skip, limit: limitNumber, fields: fields, sort: sortDescriptors)
        result?.enumerateObjects({ (revision: CDTDocumentRevision, _: UInt, _: UnsafeMutablePointer<ObjCBool>) in
            do {
                if var item = try revision.data(as: Entity.self) {
                    item.revId = revision.revId
                    succeededItems.append(item)
                }
            } catch {
                errors.append(error)
            }
        })
        callbackQueue.async {
            if !succeededItems.isEmpty {
                callbackQueue.async {
                    completion(.success(succeededItems))
                }
            } else if let firstError = errors.first {
                callbackQueue.async {
                    completion(.failure(.fetchFailed(reason: firstError.localizedDescription)))
                }
            } else {
                NSLog("Returning empty data")
                completion(.success([]))
            }
        }
    }
}

#endif
