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
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.
 */

import XCTest

#if CARE && HEALTH
@testable import OTFCloudantStore
import OTFCDTDatastore
import OTFCareKitStore

final class CareKitQueryMappingContractTests: CareKitStoreContractTestCase {

    func testTaskQueryMapsFiltersDateSortLimitAndOffset() {
        let taskUUID = uuid("11111111-1111-1111-1111-111111111111")
        let carePlanUUID = uuid("22222222-2222-2222-2222-222222222222")
        let interval = DateInterval(start: date(100), end: date(200))
        var query = OCKTaskQuery(dateInterval: interval)
        query.uuids = [taskUUID]
        query.groupIdentifiers = ["task-group"]
        query.carePlanUUIDs = [carePlanUUID]
        query.carePlanRemoteIDs = ["care-remote"]
        query.carePlanIDs = ["care-id"]
        query.remoteIDs = ["task-remote"]
        query.ids = ["task-id"]
        query.tags = ["one", "two"]
        query.limit = 7
        query.offset = 3
        query.sortDescriptors = [
            .effectiveDate(ascending: true),
            .groupIdentifier(ascending: false),
            .title(ascending: true)
        ]

        let cloudantQuery = OTFCloudantTaskQuery(taskQuery: query)

        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.uuid] as? String, taskUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.groupIdentifier] as? String, "task-group")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.carePlanUUID] as? String, carePlanUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.carePlanRemoteID] as? String, "care-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.carePlanID] as? String, "care-id")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.remoteID] as? String, "task-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.id] as? String, "task-id")
        XCTAssertEqual((cloudantQuery.parameters[PropertyKey.tag] as? [String: [String]])?["$in"], ["one", "two"])
        XCTAssertEqual(cloudantQuery.limit, 7)
        XCTAssertEqual(cloudantQuery.offset, 3)
        XCTAssertEqual(cloudantQuery.sortDescription, [
            [PropertyKey.effectiveDate: "asc"],
            [PropertyKey.groupIdentifier: "desc"],
            ["title": "asc"]
        ])
        let conditions = cloudantQuery.parameters["$and"] as? [[String: Any]]
        XCTAssertEqual(conditions?.count, 2)
        XCTAssertNotNil(conditions?.first?[PropertyKey.startDate])
        XCTAssertNotNil(conditions?.last?[OTFCloudantCombinationSelector.or.rawValue])
    }

    func testOutcomeQueryMapsTaskFiltersSortLimitAndOffset() {
        let outcomeUUID = uuid("33333333-3333-3333-3333-333333333333")
        let taskUUID = uuid("44444444-4444-4444-4444-444444444444")
        var query = OCKOutcomeQuery()
        query.uuids = [outcomeUUID]
        query.taskIDs = ["task-id"]
        query.taskUUIDs = [taskUUID]
        query.taskRemoteIDs = ["task-remote"]
        query.groupIdentifiers = ["outcome-group"]
        query.remoteIDs = ["outcome-remote"]
        query.ids = ["outcome-id"]
        query.tags = ["outcome-tag"]
        query.limit = 2
        query.offset = 1
        query.sortDescriptors = [.date(ascending: false)]

        let cloudantQuery = OTFCloudantOutcomeQuery(outcomeQuery: query)

        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.uuid] as? String, outcomeUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.taskID] as? String, "task-id")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.taskUUID] as? String, taskUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.taskRemoteID] as? String, "task-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.groupIdentifier] as? String, "outcome-group")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.remoteID] as? String, "outcome-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.id] as? String, "outcome-id")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.tag] as? String, "outcome-tag")
        XCTAssertEqual(cloudantQuery.limit, 2)
        XCTAssertEqual(cloudantQuery.offset, 1)
        XCTAssertEqual(cloudantQuery.sortDescription, [["createdDate": "desc"]])
    }

    func testPatientQueryMapsFiltersLimitAndOffset() {
        let patientUUID = uuid("55555555-5555-5555-5555-555555555555")
        var query = OCKPatientQuery()
        query.uuids = [patientUUID]
        query.remoteIDs = ["patient-remote"]
        query.ids = ["patient-id"]
        query.tags = ["patient-tag"]
        query.groupIdentifiers = ["patient-group"]
        query.limit = 4
        query.offset = 2

        let cloudantQuery = OTFCloudantPatientQuery(patientQuery: query)

        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.uuid] as? String, patientUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.remoteID] as? String, "patient-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.id] as? String, "patient-id")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.tag] as? String, "patient-tag")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.groupIdentifier] as? String, "patient-group")
        XCTAssertEqual(cloudantQuery.limit, 4)
        XCTAssertEqual(cloudantQuery.offset, 2)
    }

    func testContactQueryMapsCarePlanFiltersLimitAndOffset() {
        let contactUUID = uuid("66666666-6666-6666-6666-666666666666")
        var query = OCKContactQuery()
        query.uuids = [contactUUID]
        query.carePlanIDs = ["care-id"]
        query.carePlanRemoteIDs = ["care-remote"]
        query.remoteIDs = ["contact-remote"]
        query.ids = ["contact-id"]
        query.tags = ["contact-tag"]
        query.groupIdentifiers = ["contact-group"]
        query.limit = 5
        query.offset = 6

        let cloudantQuery = OTFCloudantContactQuery(contactQuery: query)

        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.uuid] as? String, contactUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.carePlanID] as? String, "care-id")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.carePlanRemoteID] as? String, "care-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.remoteID] as? String, "contact-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.id] as? String, "contact-id")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.tag] as? String, "contact-tag")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.groupIdentifier] as? String, "contact-group")
        XCTAssertEqual(cloudantQuery.limit, 5)
        XCTAssertEqual(cloudantQuery.offset, 6)
    }

    func testContactQueryMapsCarePlanUUIDsSeparatelyFromCarePlanIDs() {
        let carePlanUUID = uuid("66666666-7777-8888-9999-AAAAAAAAAAAA")
        var query = OCKContactQuery()
        query.carePlanUUIDs = [carePlanUUID]
        query.carePlanIDs = ["care-id"]

        let cloudantQuery = OTFCloudantContactQuery(contactQuery: query)

        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.carePlanUUID] as? String, carePlanUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.carePlanID] as? String, "care-id")
    }

    func testCarePlanQueryMapsPatientFiltersTitleAndEffectiveDateSorts() {
        let carePlanUUID = uuid("77777777-7777-7777-7777-777777777777")
        let patientUUID = uuid("88888888-8888-8888-8888-888888888888")
        var query = OCKCarePlanQuery()
        query.uuids = [carePlanUUID]
        query.groupIdentifiers = ["care-group"]
        query.patientUUIDs = [patientUUID]
        query.patientRemoteIDs = ["patient-remote"]
        query.patientIDs = ["patient-id"]
        query.remoteIDs = ["care-remote"]
        query.ids = ["care-id"]
        query.tags = ["care-tag"]
        query.limit = 8
        query.offset = 9
        query.sortDescriptors = [.title(ascending: false), .effectiveDate(ascending: true)]

        let cloudantQuery = OTFCloudantCarePlanQuery(carePlanQuery: query)

        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.uuid] as? String, carePlanUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.groupIdentifier] as? String, "care-group")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.patientUUID] as? String, patientUUID.uuidString)
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.patientRemoteId] as? String, "patient-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.patientID] as? String, "patient-id")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.remoteID] as? String, "care-remote")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.id] as? String, "care-id")
        XCTAssertEqual(cloudantQuery.parameters[PropertyKey.tag] as? String, "care-tag")
        XCTAssertEqual(cloudantQuery.limit, 8)
        XCTAssertEqual(cloudantQuery.offset, 9)
        XCTAssertEqual(cloudantQuery.sortDescription, [["title": "desc"], [PropertyKey.effectiveDate: "asc"]])
    }

    func testCareKitQueryAdaptersMapEmptySingleAndMultipleArrayFilters() {
        let firstUUID = uuid("AAAAAAAA-0000-0000-0000-000000000001")
        let secondUUID = uuid("AAAAAAAA-0000-0000-0000-000000000002")

        var taskQuery = OCKTaskQuery()
        taskQuery.uuids = [firstUUID, secondUUID]
        taskQuery.tags = []
        let taskCloudantQuery = OTFCloudantTaskQuery(taskQuery: taskQuery)
        XCTAssertEqual((taskCloudantQuery.parameters[PropertyKey.uuid] as? [String: [String]])?["$in"], [
            firstUUID.uuidString,
            secondUUID.uuidString
        ])
        XCTAssertNil(taskCloudantQuery.parameters[PropertyKey.tag])

        var outcomeQuery = OCKOutcomeQuery()
        outcomeQuery.taskUUIDs = [firstUUID, secondUUID]
        outcomeQuery.taskIDs = ["task-id"]
        let outcomeCloudantQuery = OTFCloudantOutcomeQuery(outcomeQuery: outcomeQuery)
        XCTAssertEqual((outcomeCloudantQuery.parameters[PropertyKey.taskUUID] as? [String: [String]])?["$in"], [
            firstUUID.uuidString,
            secondUUID.uuidString
        ])
        XCTAssertEqual(outcomeCloudantQuery.parameters[PropertyKey.taskID] as? String, "task-id")

        var patientQuery = OCKPatientQuery()
        patientQuery.groupIdentifiers = ["group-a", "group-b"]
        patientQuery.ids = []
        let patientCloudantQuery = OTFCloudantPatientQuery(patientQuery: patientQuery)
        XCTAssertEqual((patientCloudantQuery.parameters[PropertyKey.groupIdentifier] as? [String: [String]])?["$in"], [
            "group-a",
            "group-b"
        ])
        XCTAssertNil(patientCloudantQuery.parameters[PropertyKey.id])

        var contactQuery = OCKContactQuery()
        contactQuery.carePlanUUIDs = [firstUUID, secondUUID]
        contactQuery.carePlanIDs = ["care-id-a", "care-id-b"]
        let contactCloudantQuery = OTFCloudantContactQuery(contactQuery: contactQuery)
        XCTAssertEqual((contactCloudantQuery.parameters[PropertyKey.carePlanUUID] as? [String: [String]])?["$in"], [
            firstUUID.uuidString,
            secondUUID.uuidString
        ])
        XCTAssertEqual((contactCloudantQuery.parameters[PropertyKey.carePlanID] as? [String: [String]])?["$in"], [
            "care-id-a",
            "care-id-b"
        ])

        var carePlanQuery = OCKCarePlanQuery()
        carePlanQuery.patientUUIDs = [firstUUID, secondUUID]
        carePlanQuery.patientIDs = ["patient-id-a", "patient-id-b"]
        let carePlanCloudantQuery = OTFCloudantCarePlanQuery(carePlanQuery: carePlanQuery)
        XCTAssertEqual((carePlanCloudantQuery.parameters[PropertyKey.patientUUID] as? [String: [String]])?["$in"], [
            firstUUID.uuidString,
            secondUUID.uuidString
        ])
        XCTAssertEqual((carePlanCloudantQuery.parameters[PropertyKey.patientID] as? [String: [String]])?["$in"], [
            "patient-id-a",
            "patient-id-b"
        ])
    }

    func testTaskQueryDateIntervalMapsInclusiveScheduleOverlapSelector() {
        let interval = DateInterval(start: date(100), end: date(200))
        let cloudantQuery = OTFCloudantTaskQuery(taskQuery: OCKTaskQuery(dateInterval: interval))

        let conditions = cloudantQuery.parameters["$and"] as? [[String: Any]]
        XCTAssertEqual(conditions?.count, 2)

        let startCondition = conditions?.first?[PropertyKey.startDate] as? [String: String]
        XCTAssertEqual(startCondition?[OTFCloudantConditionSelector.lessThanOrEqual.rawValue], theraForgeISO8601Formatter.string(from: interval.end))

        let endCondition = conditions?.last?[OTFCloudantCombinationSelector.or.rawValue] as? [[String: Any]]
        XCTAssertEqual(endCondition?.count, 2)
        let missingEndDate = endCondition?.first?[PropertyKey.endDate] as? [String: Bool]
        XCTAssertEqual(missingEndDate?[OTFCloudantConditionSelector.exists.rawValue], false)
        let overlappingEndDate = endCondition?.last?[PropertyKey.endDate] as? [String: String]
        XCTAssertEqual(overlappingEndDate?[OTFCloudantConditionSelector.greaterThanOrEqual.rawValue], theraForgeISO8601Formatter.string(from: interval.start))
    }

    func testCareKitQueryAdaptersLeaveSortDescriptionNilWhenNoSortDescriptorsAreRequested() {
        XCTAssertNil(OTFCloudantTaskQuery(taskQuery: OCKTaskQuery()).sortDescription)
        XCTAssertNil(OTFCloudantOutcomeQuery(outcomeQuery: OCKOutcomeQuery()).sortDescription)
        XCTAssertNil(OTFCloudantCarePlanQuery(carePlanQuery: OCKCarePlanQuery()).sortDescription)
    }
}

final class CareKitFetchContractTests: CareKitStoreContractTestCase {

    func testFetchTasksReturnsDateFilteredSortedPage() throws {
        let store = try makeStore(prefix: "fetch_tasks")
        let interval = DateInterval(start: date(100), end: date(200))
        try insert(makeTask(id: "alpha", title: "Alpha", start: date(80), end: date(220)), into: store)
        try insert(makeTask(id: "beta", title: "Beta", start: date(90), end: date(210)), into: store)
        try insert(makeTask(id: "gamma", title: "Gamma", start: date(95), end: date(205)), into: store)
        try insert(makeTask(id: "outside", title: "Outside", start: date(300), end: date(400)), into: store)
        var query = OCKTaskQuery(dateInterval: interval)
        query.sortDescriptors = [.title(ascending: true)]
        query.offset = 1
        query.limit = 2

        let (queue, key, value) = taggedQueue("phase3.fetch.tasks")
        let result = waitForResult("fetch tasks", on: queue, key: key) { completion in
            store.fetchTasks(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        XCTAssertEqual(try taskIDs(result.result.get()), ["beta", "gamma"])
    }

    func testFetchTasksAppliesMultipleSortDescriptorsBeforePagination() throws {
        let store = try makeStore(prefix: "fetch_tasks_multisort")
        var alphaZeta = makeTask(id: "alpha-zeta", title: "Zeta")
        alphaZeta.groupIdentifier = "Alpha"
        var alphaAlpha = makeTask(id: "alpha-alpha", title: "Alpha")
        alphaAlpha.groupIdentifier = "Alpha"
        var betaZeta = makeTask(id: "beta-zeta", title: "Zeta")
        betaZeta.groupIdentifier = "Beta"
        var betaAlpha = makeTask(id: "beta-alpha", title: "Alpha")
        betaAlpha.groupIdentifier = "Beta"
        try insert(alphaZeta, into: store)
        try insert(alphaAlpha, into: store)
        try insert(betaZeta, into: store)
        try insert(betaAlpha, into: store)
        var query = OCKTaskQuery()
        query.sortDescriptors = [.groupIdentifier(ascending: true), .title(ascending: false)]
        query.offset = 1
        query.limit = 2

        let (queue, key, value) = taggedQueue("phase3.fetch.tasks-multisort")
        let result = waitForResult("fetch tasks multi-sort", on: queue, key: key) { completion in
            store.fetchTasks(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        XCTAssertEqual(try taskIDs(result.result.get()), ["alpha-alpha", "beta-zeta"])
    }

    func testFetchOutcomesFiltersByTaskUUIDOccurrenceIdentityAndDateInterval() throws {
        let store = try makeStore(prefix: "fetch_outcomes")
        let taskUUID = uuid("99999999-9999-9999-9999-999999999999")
        let otherTaskUUID = uuid("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
        let occurrenceZero = makeOutcome(taskUUID: taskUUID, occurrenceIndex: 0, value: 1, createdDate: date(150), updatedDate: date(151))
        let occurrenceOne = makeOutcome(taskUUID: taskUUID, occurrenceIndex: 1, value: 2, createdDate: date(160), updatedDate: date(161))
        let otherTaskOutcome = makeOutcome(taskUUID: otherTaskUUID, occurrenceIndex: 1, value: 3, createdDate: date(170), updatedDate: date(171))
        let outsideDate = makeOutcome(taskUUID: uuid("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"), occurrenceIndex: 0, value: 4, createdDate: date(250), updatedDate: date(251))
        try insertOutcome(occurrenceZero, into: store)
        try insertOutcome(occurrenceOne, into: store)
        try insertOutcome(otherTaskOutcome, into: store)
        try insertOutcome(outsideDate, into: store)

        var occurrenceQuery = OCKOutcomeQuery()
        occurrenceQuery.taskUUIDs = [taskUUID]
        occurrenceQuery.ids = ["\(taskUUID.uuidString)_1"]
        let (queue, key, value) = taggedQueue("phase3.fetch.outcomes-filter")
        let occurrenceResult = waitForResult("fetch outcome occurrence", on: queue, key: key) { completion in
            store.fetchOutcomes(query: occurrenceQuery, callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(occurrenceResult.queueValue, value)
        XCTAssertEqual(try occurrenceResult.result.get().map(\.taskOccurrenceIndex), [1])

        var dateQuery = OCKOutcomeQuery(dateInterval: DateInterval(start: date(100), end: date(200)))
        dateQuery.sortDescriptors = [.date(ascending: true)]
        let dateResult = waitForResult("fetch outcomes by date", on: queue, key: key) { completion in
            store.fetchOutcomes(query: dateQuery, callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(dateResult.queueValue, value)
        XCTAssertEqual(try dateResult.result.get().map { $0.values.first?.integerValue }, [1, 2, 3])
    }

    func testFetchOutcomesNormalizesDuplicateLogicalOccurrences() throws {
        let store = try makeStore(prefix: "normalize_outcomes")
        let taskUUID = uuid("CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")
        let older = makeOutcome(taskUUID: taskUUID, occurrenceIndex: 0, value: 1, createdDate: date(100), updatedDate: date(110))
        let newer = makeOutcome(taskUUID: taskUUID, occurrenceIndex: 0, value: 2, createdDate: date(100), updatedDate: date(120))
        try insertOutcome(older, documentID: "legacy-outcome", into: store)
        try insertOutcome(newer, into: store)

        var query = OCKOutcomeQuery()
        query.taskUUIDs = [taskUUID]
        let (queue, key, value) = taggedQueue("phase3.fetch.outcomes-normalize")
        let result = waitForResult("fetch normalized outcomes", on: queue, key: key) { completion in
            store.fetchOutcomes(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        let outcomes = try result.result.get()
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes.first?.values.first?.integerValue, 2)
    }

    func testFetchOutcomesNormalizesSortsAndPaginates() throws {
        let store = try makeStore(prefix: "outcome_page_after_normalize")
        let duplicateTaskUUID = uuid("DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")
        let secondTaskUUID = uuid("EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")
        let thirdTaskUUID = uuid("F0F0F0F0-F0F0-F0F0-F0F0-F0F0F0F0F0F0")
        let fourthTaskUUID = uuid("ABCDABCD-ABCD-ABCD-ABCD-ABCDABCDABCD")
        let olderDuplicate = makeOutcome(taskUUID: duplicateTaskUUID, occurrenceIndex: 0, value: 10, createdDate: date(90), updatedDate: date(100))
        let newerDuplicate = makeOutcome(taskUUID: duplicateTaskUUID, occurrenceIndex: 0, value: 11, createdDate: date(125), updatedDate: date(130))
        let second = makeOutcome(taskUUID: secondTaskUUID, occurrenceIndex: 0, value: 20, createdDate: date(110), updatedDate: date(111))
        let third = makeOutcome(taskUUID: thirdTaskUUID, occurrenceIndex: 0, value: 30, createdDate: date(120), updatedDate: date(121))
        let fourth = makeOutcome(taskUUID: fourthTaskUUID, occurrenceIndex: 0, value: 40, createdDate: date(130), updatedDate: date(131))
        try insertOutcome(olderDuplicate, documentID: "legacy-duplicate-outcome", into: store)
        try insertOutcome(newerDuplicate, into: store)
        try insertOutcome(second, into: store)
        try insertOutcome(third, into: store)
        try insertOutcome(fourth, into: store)
        var query = OCKOutcomeQuery()
        query.sortDescriptors = [.date(ascending: true)]
        query.offset = 1
        query.limit = 2

        let (queue, key, value) = taggedQueue("phase3.fetch.outcomes-page")
        let result = waitForResult("fetch outcomes sorted normalized page", on: queue, key: key) { completion in
            store.fetchOutcomes(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        XCTAssertEqual(try result.result.get().map { $0.values.first?.integerValue }, [30, 11])
    }

    func testFetchPatientsSortsAndPaginates() throws {
        let store = try makeStore(prefix: "fetch_patients")
        try insert(makePatient(id: "zoe", givenName: "Zoe", familyName: "Zeal"), into: store)
        try insert(makePatient(id: "amy", givenName: "Amy", familyName: "Able"), into: store)
        try insert(makePatient(id: "bob", givenName: "Bob", familyName: "Baker"), into: store)
        var query = OCKPatientQuery()
        query.sortDescriptors = [.givenName(ascending: true)]
        query.offset = 1
        query.limit = 1

        let (queue, key, value) = taggedQueue("phase3.fetch.patients")
        let result = waitForResult("fetch patients", on: queue, key: key) { completion in
            store.fetchPatients(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        XCTAssertEqual(try result.result.get().map { $0.id }, ["bob"])
    }

    func testFetchPatientsAppliesMultipleSortDescriptorsBeforePagination() throws {
        let store = try makeStore(prefix: "fetch_patients_multisort")
        try insert(makePatient(id: "able-anna", givenName: "Anna", familyName: "Able"), into: store)
        try insert(makePatient(id: "able-zoe", givenName: "Zoe", familyName: "Able"), into: store)
        try insert(makePatient(id: "baker-mark", givenName: "Mark", familyName: "Baker"), into: store)
        try insert(makePatient(id: "baker-yara", givenName: "Yara", familyName: "Baker"), into: store)
        var query = OCKPatientQuery()
        query.sortDescriptors = [.familyName(ascending: true), .givenName(ascending: false)]
        query.offset = 1
        query.limit = 2

        let (queue, key, value) = taggedQueue("phase3.fetch.patients-multisort")
        let result = waitForResult("fetch patients multi-sort", on: queue, key: key) { completion in
            store.fetchPatients(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        XCTAssertEqual(try result.result.get().map { $0.id }, ["able-anna", "baker-yara"])
    }

    func testFetchContactsSortsCaseInsensitivelyAndPaginates() throws {
        let store = try makeStore(prefix: "fetch_contacts")
        try insert(makeContact(id: "clara", givenName: "clara", familyName: "Clark"), into: store)
        try insert(makeContact(id: "alice", givenName: "Alice", familyName: "Adams"), into: store)
        try insert(makeContact(id: "bob", givenName: "bob", familyName: "Baker"), into: store)
        var query = OCKContactQuery()
        query.sortDescriptors = [.givenName(ascending: true)]
        query.offset = 1
        query.limit = 1

        let (queue, key, value) = taggedQueue("phase3.fetch.contacts")
        let result = waitForResult("fetch contacts", on: queue, key: key) { completion in
            store.fetchContacts(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        XCTAssertEqual(try result.result.get().map { $0.id }, ["bob"])
    }

    func testFetchContactsAppliesMultipleSortDescriptorsBeforePagination() throws {
        let store = try makeStore(prefix: "fetch_contacts_multisort")
        try insert(makeContact(id: "able-anna", givenName: "anna", familyName: "Able"), into: store)
        try insert(makeContact(id: "able-zoe", givenName: "Zoe", familyName: "Able"), into: store)
        try insert(makeContact(id: "baker-mark", givenName: "mark", familyName: "Baker"), into: store)
        try insert(makeContact(id: "baker-yara", givenName: "Yara", familyName: "Baker"), into: store)
        var query = OCKContactQuery()
        query.sortDescriptors = [.familyName(ascending: true), .givenName(ascending: false)]
        query.offset = 1
        query.limit = 2

        let (queue, key, value) = taggedQueue("phase3.fetch.contacts-multisort")
        let result = waitForResult("fetch contacts multi-sort", on: queue, key: key) { completion in
            store.fetchContacts(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        XCTAssertEqual(try result.result.get().map { $0.id }, ["able-anna", "baker-yara"])
    }

    func testFetchCarePlansSortsByTitleAndEffectiveDateAndPaginates() throws {
        let store = try makeStore(prefix: "fetch_careplans")
        try insert(makeCarePlan(id: "late", title: "Late", effectiveDate: date(300)), into: store)
        try insert(makeCarePlan(id: "early", title: "Early", effectiveDate: date(100)), into: store)
        try insert(makeCarePlan(id: "middle", title: "Middle", effectiveDate: date(200)), into: store)

        var titleQuery = OCKCarePlanQuery()
        titleQuery.sortDescriptors = [.title(ascending: true)]
        titleQuery.offset = 1
        titleQuery.limit = 1
        let (queue, key, value) = taggedQueue("phase3.fetch.careplans")
        let titleResult = waitForResult("fetch care plans by title", on: queue, key: key) { completion in
            store.fetchCarePlans(query: titleQuery, callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(titleResult.queueValue, value)
        XCTAssertEqual(try titleResult.result.get().map { $0.id }, ["late"])

        var dateQuery = OCKCarePlanQuery()
        dateQuery.sortDescriptors = [.effectiveDate(ascending: false)]
        dateQuery.offset = 1
        dateQuery.limit = 1
        let dateResult = waitForResult("fetch care plans by effective date", on: queue, key: key) { completion in
            store.fetchCarePlans(query: dateQuery, callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(dateResult.queueValue, value)
        XCTAssertEqual(try dateResult.result.get().map { $0.id }, ["middle"])
    }

    func testFetchCarePlansAppliesMultipleSortDescriptorsBeforePagination() throws {
        let store = try makeStore(prefix: "fetch_careplans_multisort")
        try insert(makeCarePlan(id: "alpha-new", title: "Alpha", effectiveDate: date(300)), into: store)
        try insert(makeCarePlan(id: "alpha-old", title: "Alpha", effectiveDate: date(100)), into: store)
        try insert(makeCarePlan(id: "beta-new", title: "Beta", effectiveDate: date(400)), into: store)
        try insert(makeCarePlan(id: "beta-old", title: "Beta", effectiveDate: date(200)), into: store)
        var query = OCKCarePlanQuery()
        query.sortDescriptors = [.title(ascending: true), .effectiveDate(ascending: false)]
        query.offset = 1
        query.limit = 2

        let (queue, key, value) = taggedQueue("phase3.fetch.careplans-multisort")
        let result = waitForResult("fetch care plans multi-sort", on: queue, key: key) { completion in
            store.fetchCarePlans(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        XCTAssertEqual(try result.result.get().map { $0.id }, ["alpha-old", "beta-new"])
    }
}

final class CareKitMutationContractTests: CareKitStoreContractTestCase {

    func testTaskMutationsPersistAndNotifyDelegates() throws {
        let store = try makeStore(prefix: "mutate_tasks")
        let delegate = CareKitTaskDelegateSpy()
        store.taskDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.tasks")
        let added = makeTask(id: "task", title: "Original")

        let add = waitForResult("add tasks", on: queue, key: key) { completion in
            store.addTasks([added], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(add.queueValue, value)
        var stored = try XCTUnwrap(add.result.get().first)
        XCTAssertNotNil(stored.revId)
        XCTAssertEqual(delegate.addedIDs, ["task"])

        stored.title = "Updated"
        let update = waitForResult("update tasks", on: queue, key: key) { completion in
            store.updateTasks([stored], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(update.queueValue, value)
        let updated = try XCTUnwrap(update.result.get().first)
        XCTAssertEqual(updated.title, "Updated")
        XCTAssertEqual(delegate.updatedIDs, ["task"])

        let delete = waitForResult("delete tasks", on: queue, key: key) { completion in
            store.deleteTasks([updated], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(delete.queueValue, value)
        XCTAssertEqual(try taskIDs(delete.result.get()), ["task"])
        XCTAssertEqual(delegate.deletedIDs, ["task"])
        XCTAssertNil(try? store.dataStore.getDocumentWithId("task"))
    }

    func testTaskUpdateWithoutRevIdFetchesCurrentRevisionAndReturnsNewRevId() throws {
        let store = try makeStore(prefix: "task_update_without_rev")
        var task = makeTask(id: "task", title: "Original")
        try insert(task, into: store)

        task.title = "Updated"
        task.revId = nil

        let (queue, key, expectedQueue) = taggedQueue("task.update.without.rev")
        let update = waitForResult("update task without rev", on: queue, key: key) { completion in
            store.updateTasks([task], callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(update.queueValue, expectedQueue)
        let updated = try XCTUnwrap(try update.result.get().first)
        XCTAssertEqual(updated.title, "Updated")
        XCTAssertNotNil(updated.revId)
        let stored = try XCTUnwrap(try store.dataStore.getDocumentWithId("task").data(as: OCKTask.self))
        XCTAssertEqual(stored.title, "Updated")
    }

    func testTaskUpdateWithoutRevIdFailsWhenDocumentIsMissing() throws {
        let store = try makeStore(prefix: "task_update_missing_rev")
        var task = makeTask(id: "missing", title: "Missing")
        task.revId = nil

        let result = waitForResult("missing update without rev") { completion in
            store.updateTasks([task], callbackQueue: .main, completion: completion)
        }

        assertError(try XCTUnwrap(result.failure), is: .updateFailed)
        XCTAssertNil(try? store.dataStore.getDocumentWithId("missing"))
    }

    func testOutcomeMutationsPersistAndNotifyDelegates() throws {
        let store = try makeStore(prefix: "mutate_outcomes")
        let delegate = CareKitOutcomeDelegateSpy()
        store.outcomeDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.outcomes")
        let added = makeOutcome(taskUUID: uuid("DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"), occurrenceIndex: 0, value: 1)
        let documentID = canonicalOutcomeID(for: added)

        let add = waitForResult("add outcomes", on: queue, key: key) { completion in
            store.addOutcomes([added], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(add.queueValue, value)
        var stored = try XCTUnwrap(add.result.get().first)
        XCTAssertNotNil(stored.revId)
        XCTAssertEqual(delegate.addedIDs, [documentID])

        stored.values = [OCKOutcomeValue(2)]
        let update = waitForResult("update outcomes", on: queue, key: key) { completion in
            store.updateOutcomes([stored], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(update.queueValue, value)
        let updated = try XCTUnwrap(update.result.get().first)
        XCTAssertEqual(updated.values.first?.integerValue, 2)
        XCTAssertEqual(delegate.updatedIDs, [documentID])

        let delete = waitForResult("delete outcomes", on: queue, key: key) { completion in
            store.deleteOutcomes([updated], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(delete.queueValue, value)
        XCTAssertEqual(try delete.result.get().map { $0.id }, [documentID])
        XCTAssertEqual(delegate.deletedIDs, [documentID])
        XCTAssertNil(try? store.dataStore.getDocumentWithId(documentID))
    }

    func testPatientMutationsPersistAndNotifyDelegates() throws {
        let store = try makeStore(prefix: "mutate_patients")
        let delegate = CareKitPatientDelegateSpy()
        store.patientDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.patients")
        let added = makePatient(id: "patient", givenName: "Jane", familyName: "Doe")

        let add = waitForResult("add patients", on: queue, key: key) { completion in
            store.addPatients([added], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(add.queueValue, value)
        var stored = try XCTUnwrap(add.result.get().first)
        XCTAssertNotNil(stored.revId)
        XCTAssertEqual(delegate.addedIDs, ["patient"])

        stored.name.familyName = "Updated"
        let update = waitForResult("update patients", on: queue, key: key) { completion in
            store.updatePatients([stored], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(update.queueValue, value)
        let updated = try XCTUnwrap(update.result.get().first)
        XCTAssertEqual(updated.name.familyName, "Updated")
        XCTAssertEqual(delegate.updatedIDs, ["patient"])

        let delete = waitForResult("delete patients", on: queue, key: key) { completion in
            store.deletePatients([updated], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(delete.queueValue, value)
        XCTAssertEqual(try delete.result.get().map { $0.id }, ["patient"])
        XCTAssertEqual(delegate.deletedIDs, ["patient"])
        XCTAssertNil(try? store.dataStore.getDocumentWithId("patient"))
    }

    func testContactMutationsPersistAndNotifyDelegates() throws {
        let store = try makeStore(prefix: "mutate_contacts")
        let delegate = CareKitContactDelegateSpy()
        store.contactDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.contacts")
        let added = makeContact(id: "contact", givenName: "Jane", familyName: "Doe")

        let add = waitForResult("add contacts", on: queue, key: key) { completion in
            store.addContacts([added], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(add.queueValue, value)
        var stored = try XCTUnwrap(add.result.get().first)
        XCTAssertNotNil(stored.revId)
        XCTAssertEqual(delegate.addedIDs, ["contact"])

        stored.name.familyName = "Updated"
        let update = waitForResult("update contacts", on: queue, key: key) { completion in
            store.updateContacts([stored], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(update.queueValue, value)
        let updated = try XCTUnwrap(update.result.get().first)
        XCTAssertEqual(updated.name.familyName, "Updated")
        XCTAssertEqual(delegate.updatedIDs, ["contact"])

        let delete = waitForResult("delete contacts", on: queue, key: key) { completion in
            store.deleteContacts([updated], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(delete.queueValue, value)
        XCTAssertEqual(try delete.result.get().map { $0.id }, ["contact"])
        XCTAssertEqual(delegate.deletedIDs, ["contact"])
        XCTAssertNil(try? store.dataStore.getDocumentWithId("contact"))
    }

    func testCarePlanMutationsPersistAndNotifyDelegates() throws {
        let store = try makeStore(prefix: "mutate_careplans")
        let delegate = CareKitCarePlanDelegateSpy()
        store.carePlanDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.careplans")
        let added = makeCarePlan(id: "plan", title: "Original")

        let add = waitForResult("add care plans", on: queue, key: key) { completion in
            store.addCarePlans([added], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(add.queueValue, value)
        var stored = try XCTUnwrap(add.result.get().first)
        XCTAssertNotNil(stored.revId)
        XCTAssertEqual(delegate.addedIDs, ["plan"])

        stored.title = "Updated"
        let update = waitForResult("update care plans", on: queue, key: key) { completion in
            store.updateCarePlans([stored], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(update.queueValue, value)
        let updated = try XCTUnwrap(update.result.get().first)
        XCTAssertEqual(updated.title, "Updated")
        XCTAssertEqual(delegate.updatedIDs, ["plan"])

        let delete = waitForResult("delete care plans", on: queue, key: key) { completion in
            store.deleteCarePlans([updated], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(delete.queueValue, value)
        XCTAssertEqual(try delete.result.get().map { $0.id }, ["plan"])
        XCTAssertEqual(delegate.deletedIDs, ["plan"])
        XCTAssertNil(try? store.dataStore.getDocumentWithId("plan"))
    }

    func testAddUpdateOrDeleteTasksSplitsMixedInputsAndNotifiesDelegatesOnce() throws {
        let store = try makeStore(prefix: "split_tasks")
        let delegate = CareKitTaskDelegateSpy()
        store.taskDelegate = delegate
        try insert(makeTask(id: "update", title: "Old"), into: store)
        try insert(makeTask(id: "delete", title: "Delete"), into: store)

        var fetchExisting = OCKTaskQuery()
        fetchExisting.ids = ["update", "delete"]
        let (fetchQueue, fetchKey, fetchValue) = taggedQueue("phase3.fetch.task-split-existing")
        let existingFetch = waitForResult("fetch existing tasks", on: fetchQueue, key: fetchKey) { completion in
            store.fetchTasks(query: fetchExisting, callbackQueue: fetchQueue, completion: completion)
        }
        XCTAssertEqual(existingFetch.queueValue, fetchValue)
        let existing = try existingFetch.result.get()
        var updateTask = try XCTUnwrap(existing.first { taskID($0) == "update" })
        updateTask.title = "Updated"
        let deleteTask = try XCTUnwrap(existing.first { taskID($0) == "delete" })
        let addTask = makeTask(id: "add", title: "Added")
        let (queue, key, value) = taggedQueue("phase3.task-split")

        let split = waitForResult("split tasks", on: queue, key: key) { completion in
            store.addUpdateOrDeleteTasks(
                addOrUpdate: [addTask, updateTask],
                delete: [deleteTask],
                callbackQueue: queue,
                completion: completion
            )
        }

        XCTAssertEqual(split.queueValue, value)
        let splitResult = try split.result.get()
        XCTAssertEqual(taskIDs(splitResult.0), ["add"])
        XCTAssertEqual(taskIDs(splitResult.1), ["update"])
        XCTAssertEqual(taskIDs(splitResult.2), ["delete"])
        XCTAssertEqual(delegate.addedIDs, ["add"])
        XCTAssertEqual(delegate.updatedIDs, ["update"])
        XCTAssertEqual(delegate.deletedIDs, ["delete"])
    }

    func testUpdateOutcomesRemainsUpdateOnlyUntilOutcomeSplitAPIIsApproved() throws {
        let store = try makeStore(prefix: "outcome_update_only")
        let delegate = CareKitOutcomeDelegateSpy()
        store.outcomeDelegate = delegate
        let newOutcome = makeOutcome(taskUUID: uuid("EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE"), occurrenceIndex: 0, value: 1)

        let (queue, key, value) = taggedQueue("phase3.outcome-update-only")
        let result = waitForResult("update missing outcome", on: queue, key: key) { completion in
            store.updateOutcomes([newOutcome], callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        assertError(try XCTUnwrap(result.result.failure), is: .updateFailed)
        XCTAssertTrue(delegate.addedIDs.isEmpty)
        XCTAssertTrue(delegate.updatedIDs.isEmpty)
        XCTAssertNil(try? store.dataStore.getDocumentWithId(canonicalOutcomeID(for: newOutcome)))
    }

    func testDeleteOutcomeRemovesLegacyDocumentWithSameLogicalIdentity() throws {
        let store = try makeStore(prefix: "delete_legacy_outcome")
        let taskUUID = uuid("10101010-1010-1010-1010-101010101010")
        let outcome = makeOutcome(taskUUID: taskUUID, occurrenceIndex: 0, value: 1)
        try insertOutcome(outcome, documentID: "legacy-outcome-doc", into: store)

        let result = waitForResult("delete legacy outcome") { completion in
            store.deleteOutcomes([outcome], callbackQueue: .main, completion: completion)
        }

        XCTAssertEqual(try result.get().count, 1)
        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-outcome-doc"))
    }

    func testDeleteOutcomeRemovesDuplicateCanonicalAndLegacyDocuments() throws {
        let store = try makeStore(prefix: "delete_duplicate_outcomes")
        let taskUUID = uuid("20202020-2020-2020-2020-202020202020")
        let outcome = makeOutcome(taskUUID: taskUUID, occurrenceIndex: 0, value: 1)
        let canonicalID = canonicalOutcomeID(for: outcome)
        try insertOutcome(outcome, documentID: canonicalID, into: store)
        try insertOutcome(outcome, documentID: "legacy-duplicate-outcome", into: store)

        let result = waitForResult("delete duplicate outcomes") { completion in
            store.deleteOutcomes([outcome], callbackQueue: .main, completion: completion)
        }

        XCTAssertEqual(try result.get().count, 1)
        XCTAssertNil(try? store.dataStore.getDocumentWithId(canonicalID))
        XCTAssertNil(try? store.dataStore.getDocumentWithId("legacy-duplicate-outcome"))
    }

    func testDeleteOutcomeRemovesAlreadySoftDeletedLogicalRecord() throws {
        let store = try makeStore(prefix: "delete_soft_deleted_outcome")
        let taskUUID = uuid("30303030-3030-3030-3030-303030303030")
        var outcome = makeOutcome(taskUUID: taskUUID, occurrenceIndex: 0, value: 1)
        outcome.deletedDate = date(30)
        let documentID = canonicalOutcomeID(for: outcome)
        try insertOutcome(outcome, documentID: documentID, into: store)

        let result = waitForResult("delete soft deleted outcome") { completion in
            store.deleteOutcomes([outcome], callbackQueue: .main, completion: completion)
        }

        XCTAssertEqual(try result.get().count, 1)
        XCTAssertNil(try? store.dataStore.getDocumentWithId(documentID))
    }
}

final class CareKitFailureContractTests: CareKitStoreContractTestCase {

    func testTaskFailurePathsMapErrorsAndDoNotNotifyDelegate() throws {
        let store = try makeStore(prefix: "task_failures")
        try insert(makeTask(id: "task", title: "Existing"), into: store)
        let delegate = CareKitTaskDelegateSpy()
        store.taskDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.task-failures")

        let duplicateAdd = waitForResult("duplicate task add", on: queue, key: key) { completion in
            store.addTasks([makeTask(id: "task", title: "Duplicate")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(duplicateAdd.queueValue, value)
        assertError(try XCTUnwrap(duplicateAdd.result.failure), is: .addFailed)

        let missingUpdate = waitForResult("missing task update", on: queue, key: key) { completion in
            store.updateTasks([makeTask(id: "missing", title: "Missing")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingUpdate.queueValue, value)
        assertError(try XCTUnwrap(missingUpdate.result.failure), is: .updateFailed)

        let missingDelete = waitForResult("missing task delete", on: queue, key: key) { completion in
            store.deleteTasks([makeTask(id: "missing", title: "Missing")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingDelete.queueValue, value)
        assertError(try XCTUnwrap(missingDelete.result.failure), is: .deleteFailed)
        XCTAssertTrue(delegate.isEmpty)
    }

    func testOutcomeFailurePathsMapErrorsAndDoNotNotifyDelegate() throws {
        let store = try makeStore(prefix: "outcome_failures")
        let outcome = makeOutcome(taskUUID: uuid("ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB"), occurrenceIndex: 0, value: 1)
        try insertOutcome(outcome, into: store)
        let delegate = CareKitOutcomeDelegateSpy()
        store.outcomeDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.outcome-failures")

        let duplicateAdd = waitForResult("duplicate outcome add", on: queue, key: key) { completion in
            store.addOutcomes([outcome], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(duplicateAdd.queueValue, value)
        assertError(try XCTUnwrap(duplicateAdd.result.failure), is: .addFailed)

        let missingUpdate = waitForResult("missing outcome update", on: queue, key: key) { completion in
            store.updateOutcomes([makeOutcome(taskUUID: uuid("CDCDCDCD-CDCD-CDCD-CDCD-CDCDCDCDCDCD"), occurrenceIndex: 0, value: 2)], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingUpdate.queueValue, value)
        assertError(try XCTUnwrap(missingUpdate.result.failure), is: .updateFailed)

        let missingDelete = waitForResult("missing outcome delete", on: queue, key: key) { completion in
            store.deleteOutcomes([makeOutcome(taskUUID: uuid("EFEFEFEF-EFEF-EFEF-EFEF-EFEFEFEFEFEF"), occurrenceIndex: 0, value: 3)], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingDelete.queueValue, value)
        assertError(try XCTUnwrap(missingDelete.result.failure), is: .deleteFailed)
        XCTAssertTrue(delegate.isEmpty)
    }

    func testPatientFailurePathsMapErrorsAndDoNotNotifyDelegate() throws {
        let store = try makeStore(prefix: "patient_failures")
        try insert(makePatient(id: "patient", givenName: "Jane", familyName: "Doe"), into: store)
        let delegate = CareKitPatientDelegateSpy()
        store.patientDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.patient-failures")

        let duplicateAdd = waitForResult("duplicate patient add", on: queue, key: key) { completion in
            store.addPatients([makePatient(id: "patient", givenName: "Janet", familyName: "Doe")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(duplicateAdd.queueValue, value)
        assertError(try XCTUnwrap(duplicateAdd.result.failure), is: .addFailed)

        let missingUpdate = waitForResult("missing patient update", on: queue, key: key) { completion in
            store.updatePatients([makePatient(id: "missing", givenName: "Missing", familyName: "Patient")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingUpdate.queueValue, value)
        assertError(try XCTUnwrap(missingUpdate.result.failure), is: .updateFailed)

        let missingDelete = waitForResult("missing patient delete", on: queue, key: key) { completion in
            store.deletePatients([makePatient(id: "missing", givenName: "Missing", familyName: "Patient")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingDelete.queueValue, value)
        assertError(try XCTUnwrap(missingDelete.result.failure), is: .deleteFailed)
        XCTAssertTrue(delegate.isEmpty)
    }

    func testContactFailurePathsMapErrorsAndDoNotNotifyDelegate() throws {
        let store = try makeStore(prefix: "contact_failures")
        try insert(makeContact(id: "contact", givenName: "Jane", familyName: "Doe"), into: store)
        let delegate = CareKitContactDelegateSpy()
        store.contactDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.contact-failures")

        let duplicateAdd = waitForResult("duplicate contact add", on: queue, key: key) { completion in
            store.addContacts([makeContact(id: "contact", givenName: "Janet", familyName: "Doe")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(duplicateAdd.queueValue, value)
        assertError(try XCTUnwrap(duplicateAdd.result.failure), is: .addFailed)

        let missingUpdate = waitForResult("missing contact update", on: queue, key: key) { completion in
            store.updateContacts([makeContact(id: "missing", givenName: "Missing", familyName: "Contact")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingUpdate.queueValue, value)
        assertError(try XCTUnwrap(missingUpdate.result.failure), is: .updateFailed)

        let missingDelete = waitForResult("missing contact delete", on: queue, key: key) { completion in
            store.deleteContacts([makeContact(id: "missing", givenName: "Missing", familyName: "Contact")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingDelete.queueValue, value)
        assertError(try XCTUnwrap(missingDelete.result.failure), is: .deleteFailed)
        XCTAssertTrue(delegate.isEmpty)
    }

    func testCarePlanFailurePathsMapErrorsAndDoNotNotifyDelegate() throws {
        let store = try makeStore(prefix: "careplan_failures")
        try insert(makeCarePlan(id: "plan", title: "Existing"), into: store)
        let delegate = CareKitCarePlanDelegateSpy()
        store.carePlanDelegate = delegate
        let (queue, key, value) = taggedQueue("phase3.careplan-failures")

        let duplicateAdd = waitForResult("duplicate care plan add", on: queue, key: key) { completion in
            store.addCarePlans([makeCarePlan(id: "plan", title: "Duplicate")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(duplicateAdd.queueValue, value)
        assertError(try XCTUnwrap(duplicateAdd.result.failure), is: .addFailed)

        let missingUpdate = waitForResult("missing care plan update", on: queue, key: key) { completion in
            store.updateCarePlans([makeCarePlan(id: "missing", title: "Missing")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingUpdate.queueValue, value)
        assertError(try XCTUnwrap(missingUpdate.result.failure), is: .updateFailed)

        let missingDelete = waitForResult("missing care plan delete", on: queue, key: key) { completion in
            store.deleteCarePlans([makeCarePlan(id: "missing", title: "Missing")], callbackQueue: queue, completion: completion)
        }
        XCTAssertEqual(missingDelete.queueValue, value)
        assertError(try XCTUnwrap(missingDelete.result.failure), is: .deleteFailed)
        XCTAssertTrue(delegate.isEmpty)
    }

    func testMalformedDocumentsReturnFetchFailed() throws {
        let store = try makeStore(prefix: "malformed_fetch")
        let revision = CDTDocumentRevision(docId: "malformed-task")
        revision.body = NSMutableDictionary(dictionary: [
            "id": "malformed-task",
            "entityType": String(describing: OCKTask.self),
            "uuid": "not-a-uuid",
            "title": "Malformed"
        ])
        try store.dataStore.createDocument(from: revision)
        var query = OCKTaskQuery()
        query.ids = ["malformed-task"]
        let (queue, key, value) = taggedQueue("phase3.malformed-fetch")

        let result = waitForResult("fetch malformed task", on: queue, key: key) { completion in
            store.fetchTasks(query: query, callbackQueue: queue, completion: completion)
        }

        XCTAssertEqual(result.queueValue, value)
        assertError(try XCTUnwrap(result.result.failure), is: .fetchFailed)
    }

    func testCloudantErrorsMapToCareKitStoreErrors() {
        assertError(OTFCloudantError.addFailed(reason: "a").toOCKStoreError(), is: .addFailed, reason: "a")
        assertError(OTFCloudantError.deleteFailed(reason: "d").toOCKStoreError(), is: .deleteFailed, reason: "d")
        assertError(OTFCloudantError.fetchFailed(reason: "f").toOCKStoreError(), is: .fetchFailed, reason: "f")
        assertError(OTFCloudantError.invalidValue(reason: "i").toOCKStoreError(), is: .invalidValue, reason: "i")
        assertError(OTFCloudantError.remoteSynchronizationFailed(reason: "r").toOCKStoreError(), is: .remoteSynchronizationFailed, reason: "r")
        assertError(OTFCloudantError.timedOut(reason: "t").toOCKStoreError(), is: .timedOut, reason: "t")
        assertError(OTFCloudantError.updateFailed(reason: "u").toOCKStoreError(), is: .updateFailed, reason: "u")
    }
}

class CareKitStoreContractTestCase: XCTestCase {

    enum StoreErrorKind {
        case addFailed
        case deleteFailed
        case fetchFailed
        case invalidValue
        case remoteSynchronizationFailed
        case timedOut
        case updateFailed
    }

    private var temporaryDirectories = [URL]()

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func makeStore(prefix: String) throws -> OTFCloudantStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        let manager = try CDTDatastoreManager(directory: directory.path)
        let storeName = prefix.replacingOccurrences(of: "-", with: "_")
        let dataStore = try manager.datastoreNamed(storeName)
        return OTFCloudantStore(
            storeName: storeName,
            datastoreManager: manager,
            dataStore: dataStore,
            indexBootstrap: .ensure
        )
    }

    func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_900_000_000 + offset)
    }

    func uuid(_ string: String) -> UUID {
        UUID(uuidString: string)!
    }

    func taskID(_ task: OCKTask) -> String {
        (task as OCKAnyTask).id
    }

    func taskIDs(_ tasks: [OCKTask]) -> [String] {
        tasks.map { taskID($0) }
    }

    func makeTask(
        id: String,
        title: String,
        start: Date? = nil,
        end: Date? = nil,
        uuid: UUID? = nil
    ) -> OCKTask {
        let schedule = OCKSchedule.dailyAtTime(
            hour: 8,
            minutes: 0,
            start: start ?? date(100),
            end: end,
            text: nil
        )
        var task = OCKTask(id: id, title: title, carePlanUUID: nil, schedule: schedule)
        if let uuid {
            task.uuid = uuid
        }
        task.createdDate = date(10)
        task.updatedDate = date(20)
        return task
    }

    func makeOutcome(
        taskUUID: UUID,
        occurrenceIndex: Int,
        value: Int,
        createdDate: Date? = nil,
        updatedDate: Date? = nil
    ) -> OCKOutcome {
        var outcome = OCKOutcome(
            taskUUID: taskUUID,
            taskOccurrenceIndex: occurrenceIndex,
            values: [OCKOutcomeValue(value)]
        )
        outcome.createdDate = createdDate ?? date(10)
        outcome.updatedDate = updatedDate ?? date(20)
        outcome.effectiveDate = outcome.createdDate ?? date(10)
        return outcome
    }

    func makePatient(
        id: String,
        givenName: String,
        familyName: String,
        effectiveDate: Date? = nil
    ) -> OCKPatient {
        var patient = OCKPatient(id: id, givenName: givenName, familyName: familyName)
        patient.effectiveDate = effectiveDate ?? date(100)
        patient.createdDate = date(10)
        patient.updatedDate = date(20)
        return patient
    }

    func makeContact(
        id: String,
        givenName: String,
        familyName: String,
        effectiveDate: Date? = nil
    ) -> OCKContact {
        var contact = OCKContact(id: id, givenName: givenName, familyName: familyName, carePlanUUID: nil)
        contact.effectiveDate = effectiveDate ?? date(100)
        contact.createdDate = date(10)
        contact.updatedDate = date(20)
        return contact
    }

    func makeCarePlan(
        id: String,
        title: String,
        effectiveDate: Date? = nil
    ) -> OCKCarePlan {
        var plan = OCKCarePlan(id: id, title: title, patientUUID: nil)
        plan.effectiveDate = effectiveDate ?? date(100)
        plan.createdDate = date(10)
        plan.updatedDate = date(20)
        return plan
    }

    func insert<Entity: Encodable & Identifiable & OTFCloudantRevision>(
        _ item: Entity,
        into store: OTFCloudantStore
    ) throws where Entity.ID == String {
        try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: item))
    }

    func insertOutcome(
        _ outcome: OCKOutcome,
        documentID: String? = nil,
        into store: OTFCloudantStore
    ) throws {
        if let documentID {
            var body = CDTDocumentRevision.encodedDictionary(fromEntity: outcome)
            body["id"] = documentID
            let revision = CDTDocumentRevision(docId: documentID)
            revision.body = NSMutableDictionary(dictionary: body)
            try store.dataStore.createDocument(from: revision)
        } else {
            try store.dataStore.createDocument(from: CDTDocumentRevision.revision(fromEntity: outcome))
        }
    }

    func canonicalOutcomeID(for outcome: OCKOutcome) -> String {
        "\(outcome.taskUUID.uuidString)_\(outcome.taskOccurrenceIndex)"
    }

    func taggedQueue(_ label: String) -> (DispatchQueue, DispatchSpecificKey<String>, String) {
        let queue = DispatchQueue(label: label)
        let key = DispatchSpecificKey<String>()
        queue.setSpecific(key: key, value: label)
        return (queue, key, label)
    }

    func waitForResult<T>(
        _ description: String,
        work: (@escaping (Result<T, OCKStoreError>) -> Void) -> Void
    ) -> Result<T, OCKStoreError> {
        let expectation = expectation(description: description)
        var receivedResult: Result<T, OCKStoreError>?

        work { result in
            receivedResult = result
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        return receivedResult ?? .failure(.timedOut(reason: "No callback for \(description)"))
    }

    func waitForResult<T>(
        _ description: String,
        on queue: DispatchQueue,
        key: DispatchSpecificKey<String>,
        work: (@escaping (Result<T, OCKStoreError>) -> Void) -> Void
    ) -> (result: Result<T, OCKStoreError>, queueValue: String?) {
        let expectation = expectation(description: description)
        var receivedResult: Result<T, OCKStoreError>?
        var queueValue: String?

        work { result in
            queueValue = DispatchQueue.getSpecific(key: key)
            receivedResult = result
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        return (
            receivedResult ?? .failure(.timedOut(reason: "No callback for \(description)")),
            queueValue
        )
    }

    func assertError(
        _ error: OCKStoreError,
        is expectedKind: StoreErrorKind,
        reason expectedReason: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual: (kind: StoreErrorKind, reason: String)
        switch error {
        case .addFailed(let reason):
            actual = (.addFailed, reason)
        case .deleteFailed(let reason):
            actual = (.deleteFailed, reason)
        case .fetchFailed(let reason):
            actual = (.fetchFailed, reason)
        case .invalidValue(let reason):
            actual = (.invalidValue, reason)
        case .remoteSynchronizationFailed(let reason):
            actual = (.remoteSynchronizationFailed, reason)
        case .timedOut(let reason):
            actual = (.timedOut, reason)
        case .updateFailed(let reason):
            actual = (.updateFailed, reason)
        }

        XCTAssertEqual(actual.kind, expectedKind, file: file, line: line)
        if let expectedReason {
            XCTAssertEqual(actual.reason, expectedReason, file: file, line: line)
        }
    }
}

private extension Result {
    var failure: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

final class CareKitModelExtensionContractTests: XCTestCase {

    func testTaskRevIdPreservesExistingUserInfo() {
        var task = OCKTask(
            id: "task",
            title: "Task",
            carePlanUUID: nil,
            schedule: OCKSchedule.dailyAtTime(hour: 8, minutes: 0, start: Date(), end: nil, text: nil)
        )
        task.userInfo = ["existing": "value"]

        task.revId = "2-task"

        XCTAssertEqual(task.revId, "2-task")
        XCTAssertEqual(task.userInfo?["existing"] as? String, "value")
    }

    func testOutcomeRevIdPreservesExistingUserInfo() {
        var outcome = OCKOutcome(
            taskUUID: UUID(),
            taskOccurrenceIndex: 0,
            values: [OCKOutcomeValue(1)]
        )
        outcome.userInfo = ["existing": "value"]

        outcome.revId = "2-outcome"

        XCTAssertEqual(outcome.revId, "2-outcome")
        XCTAssertEqual(outcome.userInfo?["existing"] as? String, "value")
    }

    func testPatientContactAndCarePlanRevIdsPreserveExistingUserInfo() {
        var patient = OCKPatient(id: "patient", givenName: "A", familyName: "B")
        patient.userInfo = ["existing": "patient"]
        patient.revId = "2-patient"
        XCTAssertEqual(patient.revId, "2-patient")
        XCTAssertEqual(patient.userInfo?["existing"] as? String, "patient")

        var contact = OCKContact(id: "contact", givenName: "C", familyName: "D", carePlanUUID: nil)
        contact.userInfo = ["existing": "contact"]
        contact.revId = "2-contact"
        XCTAssertEqual(contact.revId, "2-contact")
        XCTAssertEqual(contact.userInfo?["existing"] as? String, "contact")

        var plan = OCKCarePlan(id: "plan", title: "Plan", patientUUID: nil)
        plan.userInfo = ["existing": "plan"]
        plan.revId = "2-plan"
        XCTAssertEqual(plan.revId, "2-plan")
        XCTAssertEqual(plan.userInfo?["existing"] as? String, "plan")
    }
}

private final class CareKitTaskDelegateSpy: OCKTaskStoreDelegate {
    var addedIDs = [String]()
    var updatedIDs = [String]()
    var deletedIDs = [String]()
    var isEmpty: Bool { addedIDs.isEmpty && updatedIDs.isEmpty && deletedIDs.isEmpty }

    func taskStore(_ store: OCKAnyReadOnlyTaskStore, didAddTasks tasks: [OCKAnyTask]) {
        addedIDs.append(contentsOf: tasks.map { $0.id })
    }

    func taskStore(_ store: OCKAnyReadOnlyTaskStore, didUpdateTasks tasks: [OCKAnyTask]) {
        updatedIDs.append(contentsOf: tasks.map { $0.id })
    }

    func taskStore(_ store: OCKAnyReadOnlyTaskStore, didDeleteTasks tasks: [OCKAnyTask]) {
        deletedIDs.append(contentsOf: tasks.map { $0.id })
    }
}

private final class CareKitOutcomeDelegateSpy: OCKOutcomeStoreDelegate {
    var addedIDs = [String]()
    var updatedIDs = [String]()
    var deletedIDs = [String]()
    var unknownChanges = [String]()
    var isEmpty: Bool {
        addedIDs.isEmpty && updatedIDs.isEmpty && deletedIDs.isEmpty && unknownChanges.isEmpty
    }

    func outcomeStore(_ store: OCKAnyReadOnlyOutcomeStore, didAddOutcomes outcomes: [OCKAnyOutcome]) {
        addedIDs.append(contentsOf: outcomes.map { $0.id })
    }

    func outcomeStore(_ store: OCKAnyReadOnlyOutcomeStore, didUpdateOutcomes outcomes: [OCKAnyOutcome]) {
        updatedIDs.append(contentsOf: outcomes.map { $0.id })
    }

    func outcomeStore(_ store: OCKAnyReadOnlyOutcomeStore, didDeleteOutcomes outcomes: [OCKAnyOutcome]) {
        deletedIDs.append(contentsOf: outcomes.map { $0.id })
    }

    func outcomeStore(_ store: OCKAnyReadOnlyOutcomeStore, didEncounterUnknownChange change: String) {
        unknownChanges.append(change)
    }
}

private final class CareKitPatientDelegateSpy: OCKPatientStoreDelegate {
    var addedIDs = [String]()
    var updatedIDs = [String]()
    var deletedIDs = [String]()
    var isEmpty: Bool { addedIDs.isEmpty && updatedIDs.isEmpty && deletedIDs.isEmpty }

    func patientStore(_ store: OCKAnyReadOnlyPatientStore, didAddPatients patients: [OCKAnyPatient]) {
        addedIDs.append(contentsOf: patients.map { $0.id })
    }

    func patientStore(_ store: OCKAnyReadOnlyPatientStore, didUpdatePatients patients: [OCKAnyPatient]) {
        updatedIDs.append(contentsOf: patients.map { $0.id })
    }

    func patientStore(_ store: OCKAnyReadOnlyPatientStore, didDeletePatients patients: [OCKAnyPatient]) {
        deletedIDs.append(contentsOf: patients.map { $0.id })
    }
}

private final class CareKitContactDelegateSpy: OCKContactStoreDelegate {
    var addedIDs = [String]()
    var updatedIDs = [String]()
    var deletedIDs = [String]()
    var isEmpty: Bool { addedIDs.isEmpty && updatedIDs.isEmpty && deletedIDs.isEmpty }

    func contactStore(_ store: OCKAnyReadOnlyContactStore, didAddContacts contacts: [OCKAnyContact]) {
        addedIDs.append(contentsOf: contacts.map { $0.id })
    }

    func contactStore(_ store: OCKAnyReadOnlyContactStore, didUpdateContacts contacts: [OCKAnyContact]) {
        updatedIDs.append(contentsOf: contacts.map { $0.id })
    }

    func contactStore(_ store: OCKAnyReadOnlyContactStore, didDeleteContacts contacts: [OCKAnyContact]) {
        deletedIDs.append(contentsOf: contacts.map { $0.id })
    }
}

private final class CareKitCarePlanDelegateSpy: OCKCarePlanStoreDelegate {
    var addedIDs = [String]()
    var updatedIDs = [String]()
    var deletedIDs = [String]()
    var isEmpty: Bool { addedIDs.isEmpty && updatedIDs.isEmpty && deletedIDs.isEmpty }

    func carePlanStore(_ store: OCKAnyReadOnlyCarePlanStore, didAddCarePlans carePlans: [OCKAnyCarePlan]) {
        addedIDs.append(contentsOf: carePlans.map { $0.id })
    }

    func carePlanStore(_ store: OCKAnyReadOnlyCarePlanStore, didUpdateCarePlans carePlans: [OCKAnyCarePlan]) {
        updatedIDs.append(contentsOf: carePlans.map { $0.id })
    }

    func carePlanStore(_ store: OCKAnyReadOnlyCarePlanStore, didDeleteCarePlans carePlans: [OCKAnyCarePlan]) {
        deletedIDs.append(contentsOf: carePlans.map { $0.id })
    }
}
#endif
