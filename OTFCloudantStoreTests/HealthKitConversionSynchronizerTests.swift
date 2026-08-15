import XCTest

@testable import OTFCloudantStore

#if HEALTH
import HealthKit

final class HealthKitConversionSynchronizerTests: XCTestCase {
    private let patientID = "phase5-patient"
    private let startDate = Date(timeIntervalSince1970: 1_800_010_000)
    private let endDate = Date(timeIntervalSince1970: 1_800_010_060)

    func testCloudantSampleQuantityRoundTripsDatesUnitValueAndExternalUUID() throws {
        let externalID = "external-step-count"
        let sample = try makeQuantitySample(
            value: 57,
            metadata: [
                HKMetadataKeyExternalUUID: externalID,
                HKMetadataKeySyncIdentifier: "sync-step",
                HKMetadataKeySyncVersion: 7
            ]
        )

        let cloudant = OTFCloudantSample(sample: sample, patientId: patientID)
        let roundTrip = try XCTUnwrap(cloudant.toHKSample() as? HKQuantitySample)

        XCTAssertEqual(cloudant.id, externalID)
        XCTAssertEqual(cloudant.uuid, sample.uuid)
        XCTAssertEqual(cloudant.patientID, patientID)
        XCTAssertEqual(cloudant.startDate, startDate)
        XCTAssertEqual(cloudant.endDate, endDate)
        XCTAssertEqual(cloudant.syncIdentifier, "sync-step")
        XCTAssertEqual(cloudant.syncVersion, 7)
        XCTAssertEqual(cloudant.type, .quantity)
        XCTAssertEqual(cloudant.typeIdentifier, try stepCountType().identifier)
        XCTAssertEqual(cloudant.unit, "count")
        XCTAssertEqual(cloudant.value, 57, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.quantity.doubleValue(for: .count()), 57, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.startDate, startDate)
        XCTAssertEqual(roundTrip.endDate, endDate)
        XCTAssertEqual(roundTrip.metadata?[HKMetadataKeyExternalUUID] as? String, externalID)
        XCTAssertEqual(roundTrip.metadata?[HKMetadataKeySyncIdentifier] as? String, "sync-step")
        XCTAssertEqual(roundTrip.metadata?[HKMetadataKeySyncVersion] as? Int, 7)
    }

    func testCloudantSampleCategoryPreservesSupportedBoolMetadataAndDropsUnsupportedValues() throws {
        let type = try sleepAnalysisType()
        let sample = HKCategorySample(
            type: type,
            value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            start: startDate,
            end: endDate,
            metadata: [
                HKMetadataKeyExternalUUID: "external-sleep",
                HKMetadataKeyWasUserEntered: true,
                "unsupported-string": "drop-me",
                "unsupported-number": 12,
                "unsupported-nsnumber": NSNumber(value: 1)
            ]
        )

        let cloudant = OTFCloudantSample(sample: sample, patientId: patientID)
        let roundTrip = try XCTUnwrap(cloudant.toHKSample() as? HKCategorySample)

        XCTAssertEqual(cloudant.type, .category)
        XCTAssertEqual(cloudant.typeIdentifier, type.identifier)
        XCTAssertEqual(cloudant.value, Double(HKCategoryValueSleepAnalysis.asleepCore.rawValue))
        XCTAssertEqual(cloudant.metadata?[HKMetadataKeyWasUserEntered], true)
        XCTAssertNil(cloudant.metadata?["unsupported-string"])
        XCTAssertNil(cloudant.metadata?["unsupported-number"])
        XCTAssertNil(cloudant.metadata?["unsupported-nsnumber"])
        XCTAssertEqual(roundTrip.metadata?[HKMetadataKeyWasUserEntered] as? Bool, true)
        XCTAssertNil(roundTrip.metadata?["unsupported-string"])
        XCTAssertNil(roundTrip.metadata?["unsupported-number"])
        XCTAssertNil(roundTrip.metadata?["unsupported-nsnumber"])
        XCTAssertEqual(roundTrip.metadata?[HKMetadataKeyExternalUUID] as? String, "external-sleep")
    }

    func testCloudantSampleIdentityMatchesHealthKitUUIDWhenExternalUUIDIsMissing() throws {
        let sample = try makeQuantitySample(value: 9, metadata: nil)
        let cloudant = OTFCloudantSample(sample: sample, patientId: patientID)

        XCTAssertEqual(cloudant.id, sample.uuid.uuidString)
        XCTAssertTrue(cloudant.isEqual(to: sample))
    }

    func testCloudantSampleCorrelationRoundTripsNestedQuantitySamples() throws {
        let correlation = try makeBloodPressureCorrelation(metadata: [HKMetadataKeyExternalUUID: "bp-external"])

        let cloudant = OTFCloudantSample(sample: correlation, patientId: patientID)
        let roundTrip = try XCTUnwrap(cloudant.toHKSample() as? HKCorrelation)

        XCTAssertEqual(cloudant.type, .correlation)
        XCTAssertEqual(cloudant.typeIdentifier, try bloodPressureType().identifier)
        XCTAssertEqual(cloudant.samples?.count, 2)
        XCTAssertEqual(roundTrip.correlationType.identifier, try bloodPressureType().identifier)
        XCTAssertEqual(roundTrip.objects.count, 2)
        XCTAssertEqual(roundTrip.metadata?[HKMetadataKeyExternalUUID] as? String, "bp-external")

        let cloudantSamples = try XCTUnwrap(cloudant.samples)
        let cloudantSamplesByType = Dictionary(uniqueKeysWithValues: cloudantSamples.map { ($0.typeIdentifier, $0) })
        let cloudantSystolic = try XCTUnwrap(cloudantSamplesByType[try systolicType().identifier])
        let cloudantDiastolic = try XCTUnwrap(cloudantSamplesByType[try diastolicType().identifier])
        XCTAssertEqual(cloudantSystolic.value, 120, accuracy: 0.0001)
        XCTAssertEqual(cloudantSystolic.unit, "mmHg")
        XCTAssertEqual(cloudantSystolic.id, "systolic-external")
        XCTAssertEqual(cloudantDiastolic.value, 80, accuracy: 0.0001)
        XCTAssertEqual(cloudantDiastolic.unit, "mmHg")
        XCTAssertEqual(cloudantDiastolic.id, "diastolic-external")

        let roundTripSamplesByType = Dictionary(
            uniqueKeysWithValues: roundTrip.objects.compactMap { sample -> (String, HKQuantitySample)? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return (quantitySample.quantityType.identifier, quantitySample)
            }
        )
        let roundTripSystolic = try XCTUnwrap(roundTripSamplesByType[try systolicType().identifier])
        let roundTripDiastolic = try XCTUnwrap(roundTripSamplesByType[try diastolicType().identifier])
        XCTAssertEqual(roundTripSystolic.quantity.doubleValue(for: .millimeterOfMercury()), 120, accuracy: 0.0001)
        XCTAssertEqual(roundTripSystolic.startDate, startDate)
        XCTAssertEqual(roundTripSystolic.endDate, endDate)
        XCTAssertEqual(roundTripSystolic.metadata?[HKMetadataKeyExternalUUID] as? String, "systolic-external")
        XCTAssertEqual(roundTripDiastolic.quantity.doubleValue(for: .millimeterOfMercury()), 80, accuracy: 0.0001)
        XCTAssertEqual(roundTripDiastolic.startDate, startDate)
        XCTAssertEqual(roundTripDiastolic.endDate, endDate)
        XCTAssertEqual(roundTripDiastolic.metadata?[HKMetadataKeyExternalUUID] as? String, "diastolic-external")
    }

    func testQuantityWrapperRoundTripsValueAndUnit() throws {
        let quantity = HKQuantity(unit: .meter(), doubleValue: 123.5)

        let wrapper = OTFCloudantHKQuantity(quantity: quantity)
        let roundTrip = wrapper.toHKQuantity()

        XCTAssertEqual(try XCTUnwrap(wrapper.value), 123.5, accuracy: 0.0001)
        XCTAssertEqual(wrapper.unit?.unitString, "m")
        XCTAssertEqual(roundTrip.doubleValue(for: .meter()), 123.5, accuracy: 0.0001)
    }

    func testQuantitySampleWrapperRoundTripsTypeValueAndDates() throws {
        let sample = try makeQuantitySample(value: 31)

        let wrapper = OTFCloudantHKQuantitySample(quantitySample: sample, patientId: patientID)
        let roundTrip = try XCTUnwrap(wrapper.toHKSample() as? HKQuantitySample)

        XCTAssertEqual(wrapper.quantityType, try stepCountType().identifier)
        XCTAssertEqual(wrapper.patientID, patientID)
        XCTAssertEqual(roundTrip.quantity.doubleValue(for: .count()), 31, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.startDate, startDate)
        XCTAssertEqual(roundTrip.endDate, endDate)
    }

    func testAudiogramWrapperRoundTripsSensitivityPoints() throws {
        let point = try HKAudiogramSensitivityPoint(
            frequency: HKQuantity(unit: .hertz(), doubleValue: 1000),
            leftEarSensitivity: HKQuantity(unit: .decibelHearingLevel(), doubleValue: 12),
            rightEarSensitivity: HKQuantity(unit: .decibelHearingLevel(), doubleValue: 14)
        )
        let sample = HKAudiogramSample(
            sensitivityPoints: [point],
            start: startDate,
            end: endDate,
            metadata: nil
        )

        let wrapper = OTFCloudantHKAudiogramSample(audiogramSample: sample, patientId: patientID)
        let roundTrip = try XCTUnwrap(wrapper.toHKSample() as? HKAudiogramSample)

        XCTAssertEqual(wrapper.sensitivityPoints?.count, 1)
        let wrappedPoint = try XCTUnwrap(wrapper.sensitivityPoints?.first)
        XCTAssertEqual(try XCTUnwrap(wrappedPoint.frequency?.value), 1000, accuracy: 0.0001)
        XCTAssertEqual(wrappedPoint.frequency?.unit?.unitString, "Hz")
        XCTAssertEqual(try XCTUnwrap(wrappedPoint.leftEarSensitivity?.value), 12, accuracy: 0.0001)
        XCTAssertEqual(wrappedPoint.leftEarSensitivity?.unit?.unitString, "dBHL")
        XCTAssertEqual(try XCTUnwrap(wrappedPoint.rightEarSensitivity?.value), 14, accuracy: 0.0001)
        XCTAssertEqual(wrappedPoint.rightEarSensitivity?.unit?.unitString, "dBHL")
        XCTAssertEqual(roundTrip.sensitivityPoints.count, 1)
        let roundTripPoint = try XCTUnwrap(roundTrip.sensitivityPoints.first)
        XCTAssertEqual(roundTripPoint.frequency.doubleValue(for: .hertz()), 1000, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(roundTripPoint.leftEarSensitivity).doubleValue(for: .decibelHearingLevel()), 12, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(roundTripPoint.rightEarSensitivity).doubleValue(for: .decibelHearingLevel()), 14, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.startDate, startDate)
        XCTAssertEqual(roundTrip.endDate, endDate)
    }

    func testCDADocumentWrapperRejectsInvalidDocumentDataWithoutTouchingHealthStore() throws {
        let invalidDocumentData = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
          <title>Phase 5 CDA</title>
        </ClinicalDocument>
        """.utf8)
        struct CDADocumentFixture: Encodable {
            let documentData: Data
        }
        struct CDADocumentSampleFixture: Encodable {
            let id: String
            let patientID: String
            let document: CDADocumentFixture
            let startDate: Date
            let endDate: Date
        }

        let fixture = CDADocumentSampleFixture(
            id: "invalid-cda",
            patientID: patientID,
            document: CDADocumentFixture(documentData: invalidDocumentData),
            startDate: startDate,
            endDate: endDate
        )
        let data = try JSONEncoder().encode(fixture)
        let wrapper = try JSONDecoder().decode(OTFCloudantHKCDADocumentSample.self, from: data)

        XCTAssertNil(wrapper.toHKSample())
    }

    func testActivitySummaryWrapperRoundTripsMoveExerciseAndStandQuantities() {
        let summary = HKActivitySummary()
        summary.activeEnergyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: 300)
        summary.activeEnergyBurnedGoal = HKQuantity(unit: .kilocalorie(), doubleValue: 500)
        summary.appleExerciseTime = HKQuantity(unit: .minute(), doubleValue: 45)
        summary.appleExerciseTimeGoal = HKQuantity(unit: .minute(), doubleValue: 30)
        summary.appleStandHours = HKQuantity(unit: .count(), doubleValue: 10)
        if #available(iOS 14.0, *) {
            summary.appleMoveTime = HKQuantity(unit: .minute(), doubleValue: 60)
            summary.appleMoveTimeGoal = HKQuantity(unit: .minute(), doubleValue: 90)
        }

        let wrapper = OTFCloudantHKActivitySummary(activitySummary: summary)
        let roundTrip = wrapper.toHKActivitySummary()

        XCTAssertEqual(roundTrip.activeEnergyBurned.doubleValue(for: .kilocalorie()), 300, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()), 500, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.appleExerciseTime.doubleValue(for: .minute()), 45, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.appleExerciseTimeGoal.doubleValue(for: .minute()), 30, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.appleStandHours.doubleValue(for: .count()), 10, accuracy: 0.0001)
        if #available(iOS 14.0, *) {
            XCTAssertEqual(roundTrip.appleMoveTime.doubleValue(for: .minute()), 60, accuracy: 0.0001)
            XCTAssertEqual(roundTrip.appleMoveTimeGoal.doubleValue(for: .minute()), 90, accuracy: 0.0001)
        }
    }

    func testWorkoutEventAndConfigurationCodablePreserveCoreFields() throws {
        let event = HKWorkoutEvent(
            type: .pause,
            dateInterval: DateInterval(start: startDate, end: startDate),
            metadata: ["reason": "phase5"]
        )
        let wrappedEvent = OTFCloudantHKWorkoutEvent(workoutEvent: event)
        let encodedEvent = try JSONEncoder().encode(wrappedEvent)
        let decodedEvent = try JSONDecoder().decode(OTFCloudantHKWorkoutEvent.self, from: encodedEvent)

        XCTAssertEqual(decodedEvent.type, HKWorkoutEventType.pause.rawValue)
        XCTAssertEqual(decodedEvent.dateInterval?.start, startDate)
        XCTAssertEqual(decodedEvent.dateInterval?.end, startDate)
        XCTAssertEqual(decodedEvent.metadata?["reason"] as? String, "phase5")

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: 400)
        let wrappedConfiguration = OTFCloudantHKWorkoutConfiguration(configuration: configuration)

        XCTAssertEqual(wrappedConfiguration.activityType, HKWorkoutActivityType.running.rawValue)
        XCTAssertEqual(wrappedConfiguration.locationType, HKWorkoutSessionLocationType.outdoor.rawValue)
        let lapLength = try XCTUnwrap(wrappedConfiguration.lapLength?.toHKQuantity())
        XCTAssertEqual(lapLength.doubleValue(for: .meter()), 400, accuracy: 0.0001)

        let encodedConfiguration = try JSONEncoder().encode(wrappedConfiguration)
        let decodedConfiguration = try JSONDecoder().decode(OTFCloudantHKWorkoutConfiguration.self, from: encodedConfiguration)
        XCTAssertEqual(decodedConfiguration.activityType, HKWorkoutActivityType.running.rawValue)
        XCTAssertEqual(decodedConfiguration.locationType, HKWorkoutSessionLocationType.outdoor.rawValue)
        let decodedLapLength = try XCTUnwrap(decodedConfiguration.lapLength?.toHKQuantity())
        XCTAssertEqual(decodedLapLength.doubleValue(for: .meter()), 400, accuracy: 0.0001)
    }

    func testParsingHelperMapsSupportedSampleTypeIdentifiers() throws {
        let mappings: [(String, AnyClass)] = [
            (try stepCountType().identifier, HKQuantityType.self),
            (try sleepAnalysisType().identifier, HKCategoryType.self),
            (try bloodPressureType().identifier, HKCorrelationType.self),
            (HKObjectType.workoutType().identifier, HKWorkoutType.self),
            (HKObjectType.audiogramSampleType().identifier, HKAudiogramSampleType.self),
            (try XCTUnwrap(HKObjectType.documentType(forIdentifier: .CDA)).identifier, HKDocumentType.self),
            (try XCTUnwrap(HKObjectType.clinicalType(forIdentifier: .allergyRecord)).identifier, HKClinicalType.self),
            (HKSeriesType.heartbeat().identifier, HKSeriesType.self)
        ]

        for mapping in mappings {
            let identifier = mapping.0
            let expectedType: AnyClass = mapping.1
            let sampleType = try XCTUnwrap(OTFParsingHelper.getSampleType(for: identifier), identifier)
            XCTAssertTrue(
                type(of: sampleType) === expectedType,
                "Expected \(identifier) to map to \(expectedType), got \(type(of: sampleType))"
            )
        }
        XCTAssertNil(OTFParsingHelper.getSampleType(for: "not-a-healthkit-sample-type"))
    }

    func testParsingHelperProcessesSupportedUnitStrings() throws {
        let units: [(String, HKUnit)] = [
            ("count", .count()),
            ("m", .meter()),
            ("kcal", .kilocalorie()),
            ("mmHg", .millimeterOfMercury()),
            ("count/min", HKUnit.count().unitDivided(by: .minute())),
            ("m/s", HKUnit.meter().unitDivided(by: .second())),
            ("mmol/L", HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter()))
        ]

        for (unitString, expectedUnit) in units {
            let unit = try XCTUnwrap(OTFParsingHelper.processUnitString(unitString), unitString)
            XCTAssertEqual(unit.unitString, expectedUnit.unitString)
        }
        XCTAssertNil(OTFParsingHelper.processUnitString("not-a-unit"))
    }

    func testParsingHelperPreferredUnitsCoverRepresentativeQuantityIdentifiers() {
        let preferredUnits: [(HKQuantityTypeIdentifier, String)] = [
            (.stepCount, "count"),
            (.distanceWalkingRunning, "m"),
            (.activeEnergyBurned, "kcal"),
            (.bloodPressureSystolic, "mmHg"),
            (.heartRate, "count/min"),
            (.walkingSpeed, "m/s")
        ]

        for (identifier, expectedUnitString) in preferredUnits {
            XCTAssertEqual(OTFParsingHelper.preferredUnit(for: identifier.rawValue)?.unitString, expectedUnitString)
        }
    }

    #if CARE && HEALTH
    func testSynchronizerPersistsHealthKitOnlySampleToCloudant() throws {
        let type = try stepCountType()
        let sample = try makeQuantitySample(value: 101, metadata: [HKMetadataKeyExternalUUID: "hk-only"])
        let healthKit = Phase5FakeHealthKitClient()
        healthKit.samplesByType[type.identifier] = [sample]
        let cloudant = Phase5FakeCloudantSampleStore(samples: [])
        let synchronizer = OTFHealthKitSynchronizer(healthKitClient: healthKit, cloudantSampleStore: cloudant, sampleTypes: [type])

        waitForSync(synchronizer, direction: .fromHKToCloudant, type: type)

        XCTAssertEqual(healthKit.fetchedTypes, [type.identifier])
        XCTAssertEqual(cloudant.addedSamples.map(\.id), ["hk-only"])
        XCTAssertEqual(healthKit.savedSamples.count, 0)
    }

    func testSynchronizerSavesCloudantOnlySampleToHealthKit() throws {
        let type = try stepCountType()
        let sample = try makeQuantitySample(value: 202, metadata: [HKMetadataKeyExternalUUID: "cloudant-only"])
        let cloudantSample = OTFCloudantSample(sample: sample, patientId: patientID)
        let healthKit = Phase5FakeHealthKitClient()
        healthKit.samplesByType[type.identifier] = []
        let cloudant = Phase5FakeCloudantSampleStore(samples: [cloudantSample])
        let synchronizer = OTFHealthKitSynchronizer(healthKitClient: healthKit, cloudantSampleStore: cloudant, sampleTypes: [type])

        waitForSync(synchronizer, direction: .fromCloudantToHK, type: type)

        XCTAssertEqual(healthKit.savedSamples.count, 1)
        XCTAssertEqual(cloudant.addedSamples.count, 0)
    }

    func testSynchronizerDoesNotDuplicateSampleAlreadyPresentInBothStores() throws {
        let type = try stepCountType()
        let sample = try makeQuantitySample(value: 303, metadata: [HKMetadataKeyExternalUUID: "same-sample"])
        let cloudantSample = OTFCloudantSample(sample: sample, patientId: patientID)
        let healthKit = Phase5FakeHealthKitClient()
        healthKit.samplesByType[type.identifier] = [sample]
        let cloudant = Phase5FakeCloudantSampleStore(samples: [cloudantSample])
        let synchronizer = OTFHealthKitSynchronizer(healthKitClient: healthKit, cloudantSampleStore: cloudant, sampleTypes: [type])

        waitForSync(synchronizer, direction: .biDirection, type: type)

        XCTAssertEqual(cloudant.addedSamples.count, 0)
        XCTAssertEqual(healthKit.savedSamples.count, 0)
    }

    func testSynchronizerDoesNotReusePreviousHealthKitSamplesAcrossSyncRuns() throws {
        let type = try stepCountType()
        let firstSample = try makeQuantitySample(value: 1, metadata: [HKMetadataKeyExternalUUID: "first"])
        let healthKit = Phase5FakeHealthKitClient()
        healthKit.samplesByType[type.identifier] = [firstSample]
        let cloudant = Phase5FakeCloudantSampleStore(samples: [])
        let synchronizer = OTFHealthKitSynchronizer(healthKitClient: healthKit, cloudantSampleStore: cloudant, sampleTypes: [type])

        waitForSync(synchronizer, direction: .fromHKToCloudant, type: type)
        healthKit.samplesByType[type.identifier] = []
        waitForSync(synchronizer, direction: .fromHKToCloudant, type: type)

        XCTAssertEqual(cloudant.addedSamples.map(\.id), ["first"])
    }

    func testAnchoredSampleOnlyInitialCallbackAddsCloudantSamples() throws {
        let type = try stepCountType()
        let sample = try makeQuantitySample(value: 404, metadata: [HKMetadataKeyExternalUUID: "anchored-sample"])
        let healthKit = Phase5FakeHealthKitClient()
        let cloudant = Phase5FakeCloudantSampleStore(samples: [])
        let synchronizer = OTFHealthKitSynchronizer(healthKitClient: healthKit, cloudantSampleStore: cloudant, sampleTypes: [type])

        synchronizer.observeOnHKStoreRealTimeUpdates()
        healthKit.triggerInitialSamples([sample], deletedSamples: nil, for: type)

        XCTAssertEqual(cloudant.addedSamples.map(\.id), ["anchored-sample"])
        XCTAssertEqual(cloudant.deletedSamples.count, 0)
    }

    func testAnchoredDeletionOnlyUpdateDeletesMatchingCloudantSamples() throws {
        let type = try stepCountType()
        let deletedUUID = UUID()
        let existingSample = try makeQuantitySample(value: 505, metadata: nil)
        let existingCloudantSample = OTFCloudantSample(sample: existingSample, patientId: patientID)
        let healthKit = Phase5FakeHealthKitClient()
        let cloudant = Phase5FakeCloudantSampleStore(samples: [])
        cloudant.samplesByDeletedUUID[deletedUUID.uuidString] = [existingCloudantSample]
        let synchronizer = OTFHealthKitSynchronizer(healthKitClient: healthKit, cloudantSampleStore: cloudant, sampleTypes: [type])

        synchronizer.observeOnHKStoreRealTimeUpdates()
        healthKit.triggerUpdatedSamples(nil, deletedSamples: [HealthKitDeletedSample(uuid: deletedUUID)], for: type)

        XCTAssertEqual(cloudant.deletionFetches.map(\.uuid), [deletedUUID.uuidString])
        XCTAssertEqual(cloudant.deletedSamples.map(\.id), [existingCloudantSample.id])
        XCTAssertEqual(cloudant.updatedSamples.count, 0)
    }

    func testSynchronizerFetchErrorDoesNotWriteSamples() throws {
        let type = try stepCountType()
        let healthKit = Phase5FakeHealthKitClient()
        healthKit.fetchErrorsByType[type.identifier] = NSError(
            domain: HKErrorDomain,
            code: HKError.Code.errorAuthorizationDenied.rawValue
        )
        let cloudant = Phase5FakeCloudantSampleStore(samples: [])
        let synchronizer = OTFHealthKitSynchronizer(healthKitClient: healthKit, cloudantSampleStore: cloudant, sampleTypes: [type])

        waitForSync(synchronizer, direction: .fromHKToCloudant, type: type)

        XCTAssertEqual(cloudant.addedSamples.count, 0)
        XCTAssertEqual(cloudant.updatedSamples.count, 0)
        XCTAssertEqual(cloudant.deletedSamples.count, 0)
        XCTAssertEqual(healthKit.savedSamples.count, 0)
    }

    func testSynchronizerUnavailableHealthDataDoesNotFetchOrWriteSamples() throws {
        let type = try stepCountType()
        let healthKit = Phase5FakeHealthKitClient()
        healthKit.isHealthDataAvailable = false
        let cloudant = Phase5FakeCloudantSampleStore(samples: [])
        let synchronizer = OTFHealthKitSynchronizer(healthKitClient: healthKit, cloudantSampleStore: cloudant, sampleTypes: [type])

        synchronizer.syncWithHealthKit(direction: .fromHKToCloudant, type: type, completion: nil)

        XCTAssertEqual(healthKit.fetchedTypes, [])
        XCTAssertEqual(cloudant.fetchSamplesCallCount, 0)
        XCTAssertEqual(cloudant.addedSamples.count, 0)
        XCTAssertEqual(healthKit.savedSamples.count, 0)
    }

    func testSynchronizerContinuesWithHealthKitToCloudantWhenCloudantFetchFails() throws {
        let type = try XCTUnwrap(HKQuantityType.quantityType(forIdentifier: .stepCount))
        let sample = try makeQuantitySample(value: 12, metadata: [HKMetadataKeyExternalUUID: "hk-cloudant-fetch-failure"])
        let healthKit = Phase5FakeHealthKitClient()
        healthKit.samplesByType[type.identifier] = [sample]
        let cloudant = Phase5FakeCloudantSampleStore(samples: [])
        cloudant.fetchResult = .failure(.fetchFailed(reason: "cloudant unavailable"))
        let synchronizer = OTFHealthKitSynchronizer(
            healthKitClient: healthKit,
            cloudantSampleStore: cloudant,
            sampleTypes: [type]
        )

        waitForSync(synchronizer, direction: .fromHKToCloudant, type: type)

        XCTAssertEqual(cloudant.fetchSamplesCallCount, 1)
        XCTAssertEqual(cloudant.addedSamples.count, 1)
    }

    func testAnchoredDeletionFetchFailureDoesNotDeleteSamples() throws {
        let type = try XCTUnwrap(HKQuantityType.quantityType(forIdentifier: .stepCount))
        let deletedUUID = UUID()
        let healthKit = Phase5FakeHealthKitClient()
        let cloudant = Phase5FakeCloudantSampleStore(samples: [])
        cloudant.deletionFetchErrorsByUUID[deletedUUID.uuidString] = .fetchFailed(reason: "missing")
        let synchronizer = OTFHealthKitSynchronizer(
            healthKitClient: healthKit,
            cloudantSampleStore: cloudant,
            sampleTypes: [type]
        )

        synchronizer.observeOnHKStoreRealTimeUpdates()
        healthKit.triggerUpdatedSamples(nil, deletedSamples: [HealthKitDeletedSample(uuid: deletedUUID)], for: type)

        XCTAssertEqual(cloudant.deletionFetches.map(\.uuid), [deletedUUID.uuidString])
        XCTAssertEqual(cloudant.deletedSamples.count, 0)
    }
    #endif

    private func stepCountType() throws -> HKQuantityType {
        try XCTUnwrap(HKObjectType.quantityType(forIdentifier: .stepCount))
    }

    private func sleepAnalysisType() throws -> HKCategoryType {
        try XCTUnwrap(HKObjectType.categoryType(forIdentifier: .sleepAnalysis))
    }

    private func systolicType() throws -> HKQuantityType {
        try XCTUnwrap(HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic))
    }

    private func diastolicType() throws -> HKQuantityType {
        try XCTUnwrap(HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic))
    }

    private func bloodPressureType() throws -> HKCorrelationType {
        try XCTUnwrap(HKObjectType.correlationType(forIdentifier: .bloodPressure))
    }

    private func makeQuantitySample(
        value: Double = 42,
        metadata: [String: Any]? = nil
    ) throws -> HKQuantitySample {
        HKQuantitySample(
            type: try stepCountType(),
            quantity: HKQuantity(unit: .count(), doubleValue: value),
            start: startDate,
            end: endDate,
            metadata: metadata
        )
    }

    private func makeBloodPressureCorrelation(metadata: [String: Any]? = nil) throws -> HKCorrelation {
        let systolic = HKQuantitySample(
            type: try systolicType(),
            quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 120),
            start: startDate,
            end: endDate,
            metadata: [HKMetadataKeyExternalUUID: "systolic-external"]
        )
        let diastolic = HKQuantitySample(
            type: try diastolicType(),
            quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 80),
            start: startDate,
            end: endDate,
            metadata: [HKMetadataKeyExternalUUID: "diastolic-external"]
        )
        return HKCorrelation(
            type: try bloodPressureType(),
            start: startDate,
            end: endDate,
            objects: Set([systolic, diastolic]),
            metadata: metadata
        )
    }

    private func assertQuantitySample(
        _ sample: HKSample?,
        expectedValue: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let quantitySample = try XCTUnwrap(sample as? HKQuantitySample, file: file, line: line)
        XCTAssertEqual(quantitySample.quantity.doubleValue(for: .count()), expectedValue, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(quantitySample.startDate, startDate, file: file, line: line)
        XCTAssertEqual(quantitySample.endDate, endDate, file: file, line: line)
    }

    #if CARE && HEALTH
    private func waitForSync(
        _ synchronizer: OTFHealthKitSynchronizer,
        direction: OTFSyncDirection,
        type: HKSampleType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = expectation(description: "wait for HealthKit synchronizer")
        synchronizer.syncWithHealthKit(direction: direction, type: type) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    private final class Phase5FakeHealthKitClient: HealthKitClient {
        var isHealthDataAvailable = true
        var samplesByType = [String: [HKSample]]()
        var fetchErrorsByType = [String: Error]()
        private(set) var fetchedTypes = [String]()
        private(set) var savedSamples = [HKSample]()
        private(set) var observedTypes = [String]()
        private var initialHandlers = [String: ([HKSample]?, [HealthKitDeletedSample]?) -> Void]()
        private var updateHandlers = [String: ([HKSample]?, [HealthKitDeletedSample]?) -> Void]()

        func fetchSamples(of type: HKSampleType, completion: @escaping ([HKSample]?, Error?) -> Void) {
            fetchedTypes.append(type.identifier)
            completion(samplesByType[type.identifier], fetchErrorsByType[type.identifier])
        }

        func save(_ sample: HKSample, completion: @escaping (Bool, Error?) -> Void) {
            savedSamples.append(sample)
            completion(true, nil)
        }

        func observeSamples(
            of type: HKSampleType,
            initialHandler: @escaping ([HKSample]?, [HealthKitDeletedSample]?) -> Void,
            updateHandler: @escaping ([HKSample]?, [HealthKitDeletedSample]?) -> Void
        ) {
            observedTypes.append(type.identifier)
            initialHandlers[type.identifier] = initialHandler
            updateHandlers[type.identifier] = updateHandler
        }

        func triggerInitialSamples(
            _ samples: [HKSample]?,
            deletedSamples: [HealthKitDeletedSample]?,
            for type: HKSampleType
        ) {
            initialHandlers[type.identifier]?(samples, deletedSamples)
        }

        func triggerUpdatedSamples(
            _ samples: [HKSample]?,
            deletedSamples: [HealthKitDeletedSample]?,
            for type: HKSampleType
        ) {
            updateHandlers[type.identifier]?(samples, deletedSamples)
        }
    }

    private final class Phase5FakeCloudantSampleStore: CloudantSampleStore {
        var fetchResult: Result<[OTFCloudantSample], OTFCloudantError>
        var samplesByDeletedUUID = [String: [OTFCloudantSample]]()
        var deletionFetchErrorsByUUID = [String: OTFCloudantError]()
        private(set) var fetchSamplesCallCount = 0
        private(set) var addedSamples = [OTFCloudantSample]()
        private(set) var updatedSamples = [OTFCloudantSample]()
        private(set) var deletedSamples = [OTFCloudantSample]()
        private(set) var deletionFetches = [(type: OTFHealthSampleType, uuid: String)]()

        init(samples: [OTFCloudantSample]) {
            self.fetchResult = .success(samples)
        }

        func fetchSamples(completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void) {
            fetchSamplesCallCount += 1
            completion(fetchResult)
        }

        func addSamples(_ samples: [OTFCloudantSample]) {
            addedSamples.append(contentsOf: samples)
        }

        func updateSamples(_ samples: [OTFCloudantSample]) {
            updatedSamples.append(contentsOf: samples)
        }

        func deleteSamples(_ samples: [OTFCloudantSample]) {
            deletedSamples.append(contentsOf: samples)
        }

        func fetchSamples(
            healthKitSampleType: OTFHealthSampleType,
            uuid: String,
            completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void
        ) {
            deletionFetches.append((healthKitSampleType, uuid))
            if let error = deletionFetchErrorsByUUID[uuid] {
                completion(.failure(error))
            } else {
                completion(.success(samplesByDeletedUUID[uuid] ?? []))
            }
        }
    }
    #endif
}
#endif
