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
#if CARE
import OTFCareKitStore

/**
 A query that limits which tasks your fetch returns.
 */
public protocol OTFQueryProtocol {

    /// The maximum number of results the query returns.
    var limit: Int? { get set }

    /// An integer value that indicates how much to offset the query results, and which can be used to paginate results.
    var offset: Int? { get set }

    /// The order in which you want to sort the query results.
    var sortDescription: [[String: String]]? { get set }

    var parameters: [String: Any] { get set }
}

/**
 Extends OTFQueryProtocol to perform the map functionality.
 */
extension OTFQueryProtocol {

    /**
     Maps the array of the values to the query parameter.
     
     - Parameter stringArray: the array values to which query parameter  "$in" is mapped.
     
     - Returns: the resulting mapped value.
     */
    func mapArrayToQueryParameter(stringArray: [String]) -> Any? {
        if stringArray.isEmpty { return nil }

        if stringArray.count > 1 {
            return ["$in": stringArray]
        } else {
            return stringArray.first
        }
    }

}

/**
 Set of property keys.
 */
struct PropertyKey {

    /// The unique identifiers that belong to the entities that match the query.
    static let id = "id"

    /// The UUID for the entities that match the query.
    static let uuid = "uuid"

    /// UUID of the care plan.
    static let carePlanUUID = "carePlanUUID"

    /// Care plan remote identifier you can use to match tasks in the query-returned results.
    static let carePlanRemoteID = "carePlanRemoteID"

    /// Care plan identifier you can use to match contacts in the query-returned results.
    static let carePlanID = "carePlanID"

    /// Remote identifier for entities that match the query.
    static let remoteID = "remoteID"

    /// Tag by which to limit the query results.
    static let tag = "tag"

    /// Group identifers that match the query.
    static let groupIdentifier = "groupIdentifier"

    /// The task identifier for entities that match the query.
    static let taskID = "taskID"

    /// UUID of the tasks.
    static let taskUUID = "taskUUID"

    /// Remote identifier for the tasks query.
    static let taskRemoteID = "taskRemoteID"

    /// UUID of the patient.
    static let patientUUID = "patientUUID"

    /// Remote identifier for the patient query.
    static let patientRemoteId = "patientRemoteId"

    /// The patient identifier for entities that match the query.
    static let patientID = "patientID"
}

/**
 A query that limits which contacts the store returns, when you are fetching.
 */
open class OTFCloudantContactQuery: OTFQueryProtocol {

    public var parameters = [String: Any]()

    /// The maximum number of results the query returns.
    public var limit: Int?

    /// An integer value that indicates how much to offset the query results, and which can be used to paginate results.
    public var offset: Int?

    /// The order in which you want to sort the query results.
    public var sortDescription: [[String: String]]?

    /// Creates a new contact query from a specific query.
    init(contactQuery: OCKContactQuery) {
        parameters[PropertyKey.uuid] = mapArrayToQueryParameter(stringArray: contactQuery.uuids.map { $0.uuidString })
        parameters[PropertyKey.carePlanUUID] = mapArrayToQueryParameter(stringArray: contactQuery.carePlanIDs)
        parameters[PropertyKey.carePlanRemoteID] = mapArrayToQueryParameter(stringArray: contactQuery.carePlanRemoteIDs)
        parameters[PropertyKey.carePlanID] = mapArrayToQueryParameter(stringArray: contactQuery.carePlanIDs)
        parameters[PropertyKey.remoteID] = mapArrayToQueryParameter(stringArray: contactQuery.remoteIDs.compactMap { $0 })
        parameters[PropertyKey.id] = mapArrayToQueryParameter(stringArray: contactQuery.ids)
        parameters[PropertyKey.tag] = mapArrayToQueryParameter(stringArray: contactQuery.tags)
        parameters[PropertyKey.groupIdentifier] = mapArrayToQueryParameter(stringArray: contactQuery.groupIdentifiers.compactMap { $0 })
        limit = contactQuery.limit
        offset = contactQuery.offset
    }
}

/**
 A query that limits which outcomes the store returns, when you are fetching.
 */
open class OTFCloudantOutcomeQuery: OTFQueryProtocol {

    /// The maximum number of results the query returns.
    public var limit: Int?

    /// An integer value that indicates how much to offset the query results, and which can be used to paginate results.
    public var offset: Int?

    /// The order in which you want to sort the query results.
    public var sortDescription: [[String: String]]?

    public var parameters = [String: Any]()

    /// Creates an outcome query with a specific query.
    init(outcomeQuery: OCKOutcomeQuery) {
        parameters[PropertyKey.uuid] = mapArrayToQueryParameter(stringArray: outcomeQuery.uuids.map({ $0.uuidString }))
        parameters[PropertyKey.taskID] = mapArrayToQueryParameter(stringArray: outcomeQuery.taskIDs)
        parameters[PropertyKey.taskUUID] = mapArrayToQueryParameter(stringArray: outcomeQuery.taskUUIDs.map { $0.uuidString })
        parameters[PropertyKey.taskRemoteID] = mapArrayToQueryParameter(stringArray: outcomeQuery.taskRemoteIDs)
        parameters[PropertyKey.groupIdentifier] = mapArrayToQueryParameter(stringArray: outcomeQuery.groupIdentifiers.compactMap { $0 })
        parameters[PropertyKey.remoteID] = mapArrayToQueryParameter(stringArray: outcomeQuery.remoteIDs.compactMap { $0 })
        parameters[PropertyKey.id] = mapArrayToQueryParameter(stringArray: outcomeQuery.ids)
        parameters[PropertyKey.tag] = mapArrayToQueryParameter(stringArray: outcomeQuery.tags)
        limit = outcomeQuery.limit
        offset = outcomeQuery.offset
        for sortDescriptor in outcomeQuery.sortDescriptors {
            switch sortDescriptor {
            case .date(let ascending):
                sortDescription?.append(["createdDate": ascending ? "asc" : "desc"])
            }
        }
    }
}

/**
 A query that limits which patients the store returns, when you are fetching.
 */
open class OTFCloudantPatientQuery: OTFQueryProtocol {

    /// The maximum number of results the query returns.
    public var limit: Int?

    /// An integer value that indicates how much to offset the query results, and which can be used to paginate results.
    public var offset: Int?

    /// The order in which you want to sort the query results.
    public var sortDescription: [[String: String]]?

    public var parameters = [String: Any]()

    /// Creates an patient query with a specific query.
    init(patientQuery: OCKPatientQuery) {
        parameters[PropertyKey.uuid] = mapArrayToQueryParameter(stringArray: patientQuery.uuids.map { $0.uuidString })
        parameters[PropertyKey.remoteID] = mapArrayToQueryParameter(stringArray: patientQuery.remoteIDs.compactMap { $0 })
        parameters[PropertyKey.id] = mapArrayToQueryParameter(stringArray: patientQuery.ids)
        parameters[PropertyKey.tag] = mapArrayToQueryParameter(stringArray: patientQuery.tags)
        parameters[PropertyKey.groupIdentifier] = mapArrayToQueryParameter(stringArray: patientQuery.groupIdentifiers.compactMap { $0 })
        limit = patientQuery.limit
        offset = patientQuery.offset
    }
}

/**
 A query that limits which tasks the store returns, when you are fetching.
 */
open class OTFCloudantTaskQuery: OTFQueryProtocol {

    /// The maximum number of results the query returns.
    public var limit: Int?

    /// An integer value that indicates how much to offset the query results, and which can be used to paginate results.
    public var offset: Int?

    /// The order in which you want to sort the query results.
    public var sortDescription: [[String: String]]?

    public var parameters = [String: Any]()

    /// Creates the tasks with a specific query.
    init(taskQuery: OCKTaskQuery) {
        parameters[PropertyKey.uuid] = mapArrayToQueryParameter(stringArray: taskQuery.uuids.map { $0.uuidString })
        parameters[PropertyKey.groupIdentifier] = mapArrayToQueryParameter(stringArray: taskQuery.groupIdentifiers.compactMap{ $0 })
        parameters[PropertyKey.carePlanUUID] = mapArrayToQueryParameter(stringArray: taskQuery.carePlanUUIDs.map { $0.uuidString })
        parameters[PropertyKey.carePlanRemoteID] = mapArrayToQueryParameter(stringArray: taskQuery.carePlanRemoteIDs)
        parameters[PropertyKey.carePlanID] = mapArrayToQueryParameter(stringArray: taskQuery.carePlanIDs)
        parameters[PropertyKey.remoteID] = mapArrayToQueryParameter(stringArray: taskQuery.remoteIDs.compactMap{ $0 })
        parameters[PropertyKey.id] = mapArrayToQueryParameter(stringArray: taskQuery.ids)
        parameters[PropertyKey.tag] = mapArrayToQueryParameter(stringArray: taskQuery.tags)
        limit = taskQuery.limit
        offset = taskQuery.offset
    }
}

/**
 A query that limits which care plans the store returns, when you are fetching.
 */
open class OTFCloudantCarePlanQuery: OTFQueryProtocol {

    /// The maximum number of results the query returns.
    public var limit: Int?

    /// An integer value that indicates how much to offset the query results, and which can be used to paginate results.
    public var offset: Int?

    /// The order in which you want to sort the query results.
    public var sortDescription: [[String: String]]?

    public var parameters = [String: Any]()

    /// Creates the care plan with a specific query.
    init(carePlanQuery: OCKCarePlanQuery) {
        parameters[PropertyKey.uuid] = mapArrayToQueryParameter(stringArray: carePlanQuery.uuids.map { $0.uuidString })
        parameters[PropertyKey.groupIdentifier] = mapArrayToQueryParameter(stringArray: carePlanQuery.groupIdentifiers.compactMap { $0 })
        parameters[PropertyKey.patientUUID] = mapArrayToQueryParameter(stringArray: carePlanQuery.patientUUIDs.map { $0.uuidString })
        parameters[PropertyKey.patientRemoteId] = mapArrayToQueryParameter(stringArray: carePlanQuery.patientRemoteIDs)
        parameters[PropertyKey.patientID] = mapArrayToQueryParameter(stringArray: carePlanQuery.patientIDs)
        parameters[PropertyKey.remoteID] = mapArrayToQueryParameter(stringArray: carePlanQuery.remoteIDs.compactMap { $0 })
        parameters[PropertyKey.id] = mapArrayToQueryParameter(stringArray: carePlanQuery.ids)
        parameters[PropertyKey.tag] = mapArrayToQueryParameter(stringArray: carePlanQuery.tags)
        limit = carePlanQuery.limit
        offset = carePlanQuery.offset
        if !carePlanQuery.sortDescriptors.isEmpty {
            sortDescription = [[String: String]]()
            for sortDescriptor in carePlanQuery.sortDescriptors {
                switch sortDescriptor {
                case .title(let ascending):
                    sortDescription?.append(["title": ascending ? "asc" : "desc"])
                case .effectiveDate(ascending: let asc):
                    sortDescription?.append(["title": asc ? "asc" : "desc"])
                }
            }
        }
    }
}
#endif
