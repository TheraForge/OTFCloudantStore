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

#if CARE && HEALTH
import HealthKit
import OTFCareKitStore
#endif
import OTFUtilities
/*
 OTFHealthKitSynchronizer is used to sync data bi-direction between HealthKitStore and CloudantStore.
 The synchronisation will be performed when:
 - New samples are added into HealthKitStore, they will be synced to CloudantStore
 - The datas which are synced to CloudantStore will be synced to another devices which are supported for HealthData
 */

public enum OTFSyncDirection {
    case fromCloudantToHK
    case fromHKToCloudant
    case biDirection
}

#if HEALTH && CARE

struct HealthKitDeletedSample {
    let uuid: UUID
}

protocol HealthKitClient {
    var isHealthDataAvailable: Bool { get }

    func fetchSamples(of type: HKSampleType, completion: @escaping ([HKSample]?, Error?) -> Void)
    func save(_ sample: HKSample, completion: @escaping (Bool, Error?) -> Void)
    func observeSamples(
        of type: HKSampleType,
        initialHandler: @escaping ([HKSample]?, [HealthKitDeletedSample]?) -> Void,
        updateHandler: @escaping ([HKSample]?, [HealthKitDeletedSample]?) -> Void
    )
}

protocol CloudantSampleStore {
    func fetchSamples(completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void)
    func addSamples(_ samples: [OTFCloudantSample])
    func updateSamples(_ samples: [OTFCloudantSample])
    func deleteSamples(_ samples: [OTFCloudantSample])
    func fetchSamples(
        healthKitSampleType: OTFHealthSampleType,
        uuid: String,
        completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void
    )
}

private final class HKHealthStoreClient: HealthKitClient {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func fetchSamples(of type: HKSampleType, completion: @escaping ([HKSample]?, Error?) -> Void) {
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            completion(samples, error)
        }
        healthStore.execute(query)
    }

    func save(_ sample: HKSample, completion: @escaping (Bool, Error?) -> Void) {
        healthStore.save(sample, withCompletion: completion)
    }

    func observeSamples(
        of type: HKSampleType,
        initialHandler: @escaping ([HKSample]?, [HealthKitDeletedSample]?) -> Void,
        updateHandler: @escaping ([HKSample]?, [HealthKitDeletedSample]?) -> Void
    ) {
        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { _, samples, deletedObjects, _, _ in
            initialHandler(samples, deletedObjects?.map { HealthKitDeletedSample(uuid: $0.uuid) })
        }
        query.updateHandler = { _, samples, deletedObjects, _, _ in
            updateHandler(samples, deletedObjects?.map { HealthKitDeletedSample(uuid: $0.uuid) })
        }
        healthStore.execute(query)
    }
}

private final class OTFCloudantSampleStoreAdapter: CloudantSampleStore {
    private let dataStore: OTFCloudantStore

    init(dataStore: OTFCloudantStore) {
        self.dataStore = dataStore
    }

    func fetchSamples(completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void) {
        dataStore.collection(className: "OTFCloudantSample").get { (result: Result<[OTFCloudantSample], OTFCloudantError>) in
            completion(result)
        }
    }

    func addSamples(_ samples: [OTFCloudantSample]) {
        dataStore.add(samples)
    }

    func updateSamples(_ samples: [OTFCloudantSample]) {
        dataStore.update(samples)
    }

    func deleteSamples(_ samples: [OTFCloudantSample]) {
        dataStore.delete(samples)
    }

    func fetchSamples(
        healthKitSampleType: OTFHealthSampleType,
        uuid: String,
        completion: @escaping (Result<[OTFCloudantSample], OTFCloudantError>) -> Void
    ) {
        dataStore.collection(healthKitSampleType: healthKitSampleType)
            .where("uuid", isEqualTo: uuid)
            .getCloudantSamples(completion: completion)
    }
}

public class OTFHealthKitSynchronizer {
    /**
    The synchronisation between HealthKitStore and CloudantStore.
     */
    
    private let cloudantSampleStore: CloudantSampleStore
    private let healthKitClient: HealthKitClient
    
    /// A health store samples.
    private var healthStoreSamples = [HKSample]()
    
    /// A sample represents a piece of data that is associated with a start and end time.
    private var dataStoreSamples = [OTFCloudantSample]()
    
    /// The queue on which your app calls the completion closure.
    private let dispatchQueue = DispatchQueue(label: "com.otfcloudant.hkstore", qos: .background, attributes: .concurrent, autoreleaseFrequency: .never, target: nil)
    
    /// The health kit sample types.
    private var allTypes = Set<HKSampleType>()

    /**
     - Description: Creates a new sync between HealthKitStore and CloudantStore.
     - Parameter dataStore: This function requires a OTFCloudantStore object as parameter in order to initialize.
     - Parameter healthStore: This function requires a HKHealthStore object as parameter in order to initialize.
     */
    public init(dataStore: OTFCloudantStore, healthStore: HKHealthStore) {
        self.cloudantSampleStore = OTFCloudantSampleStoreAdapter(dataStore: dataStore)
        self.healthKitClient = HKHealthStoreClient(healthStore: healthStore)
        allTypes = Set([HKObjectType.workoutType(),
                            HKObjectType.audiogramSampleType(),
                            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
                            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
                            HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!,
                            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
                            HKObjectType.quantityType(forIdentifier: .bloodAlcoholContent)!,
                            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
                            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
                            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
                            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
                            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
                            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!,
                            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryBiotin)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryCaffeine)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryCalcium)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryChloride)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryCholesterol)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryChromium)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryCopper)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryFatMonounsaturated)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryFatPolyunsaturated)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryFatSaturated)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryFiber)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryFolate)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryIodine)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryIron)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryMagnesium)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryManganese)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryMolybdenum)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryNiacin)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryPantothenicAcid)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryPhosphorus)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryPotassium)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryRiboflavin)!,
                            HKObjectType.quantityType(forIdentifier: .dietarySelenium)!,
                            HKObjectType.quantityType(forIdentifier: .dietarySodium)!,
                            HKObjectType.quantityType(forIdentifier: .dietarySugar)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryThiamin)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryVitaminA)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryVitaminB12)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryVitaminB6)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryVitaminC)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryVitaminD)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryVitaminE)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryVitaminK)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
                            HKObjectType.quantityType(forIdentifier: .dietaryZinc)!,
                            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
                            HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!,
                            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
                            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                            HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!,
                            HKObjectType.quantityType(forIdentifier: .electrodermalActivity)!,
                            HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)!,
                            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
                            HKObjectType.quantityType(forIdentifier: .forcedExpiratoryVolume1)!,
                            HKObjectType.quantityType(forIdentifier: .forcedVitalCapacity)!,
                            HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)!,
                            HKObjectType.quantityType(forIdentifier: .heartRate)!,
                            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
                            HKObjectType.quantityType(forIdentifier: .height)!,
                            HKObjectType.quantityType(forIdentifier: .inhalerUsage)!,
                            HKObjectType.quantityType(forIdentifier: .insulinDelivery)!,
                            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
                            HKObjectType.quantityType(forIdentifier: .nikeFuel)!,
                            HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen)!,
                            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
                            HKObjectType.quantityType(forIdentifier: .peakExpiratoryFlowRate)!,
                            HKObjectType.quantityType(forIdentifier: .peripheralPerfusionIndex)!,
                            HKObjectType.quantityType(forIdentifier: .pushCount)!,
                            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
                            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
                            HKObjectType.quantityType(forIdentifier: .stepCount)!,
                            HKObjectType.quantityType(forIdentifier: .swimmingStrokeCount)!,
                            HKObjectType.quantityType(forIdentifier: .uvExposure)!,
                            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
                            HKObjectType.quantityType(forIdentifier: .waistCircumference)!,
                            HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
                            HKObjectType.documentType(forIdentifier: .CDA)!,
                            HKObjectType.clinicalType(forIdentifier: .allergyRecord)!,
                            HKObjectType.clinicalType(forIdentifier: .conditionRecord)!,
                            HKObjectType.clinicalType(forIdentifier: .immunizationRecord)!,
                            HKObjectType.clinicalType(forIdentifier: .labResultRecord)!,
                            HKObjectType.clinicalType(forIdentifier: .medicationRecord)!,
                            HKObjectType.clinicalType(forIdentifier: .procedureRecord)!,
                            HKObjectType.clinicalType(forIdentifier: .vitalSignRecord)!,
                            HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
                            HKObjectType.categoryType(forIdentifier: .environmentalAudioExposureEvent)!,
                            HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!,
                            HKObjectType.categoryType(forIdentifier: .highHeartRateEvent)!,
                            HKObjectType.categoryType(forIdentifier: .intermenstrualBleeding)!,
                            HKObjectType.categoryType(forIdentifier: .irregularHeartRhythmEvent)!,
                            HKObjectType.categoryType(forIdentifier: .lowHeartRateEvent)!,
                            HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
                            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
                            HKObjectType.categoryType(forIdentifier: .ovulationTestResult)!,
                            HKObjectType.categoryType(forIdentifier: .sexualActivity)!,
                            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                            HKObjectType.categoryType(forIdentifier: .toothbrushingEvent)!,
                            HKObjectType.correlationType(forIdentifier: .bloodPressure)!,
                            HKObjectType.correlationType(forIdentifier: .food)!
        ])
        if #available(iOS 13.6, *) {
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .abdominalCramps)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .acne)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .appetiteChanges)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .abdominalCramps)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .bloating)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .breastPain)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .chestTightnessOrPain)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .chills)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .constipation)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .coughing)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .diarrhea)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .dizziness)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .fainting)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .fatigue)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .fever)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .generalizedBodyAche)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .headache)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .heartburn)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .hotFlashes)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .lossOfSmell)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .lossOfTaste)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .lowerBackPain)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .moodChanges)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .nausea)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .pelvicPain)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .rapidPoundingOrFlutteringHeartbeat)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .runnyNose)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .shortnessOfBreath)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .sinusCongestion)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .skippedHeartbeat)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .sleepChanges)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .soreThroat)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .vomiting)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .wheezing)!)
        }
        if #available(iOS 14.0, *) {
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .bladderIncontinence)!)
            allTypes.insert(HKObjectType.clinicalType(forIdentifier: .coverageRecord)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .drySkin)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .environmentalAudioExposureEvent)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .hairLoss)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .handwashingEvent)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .memoryLapse)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .nightSweats)!)
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .vaginalDryness)!)
            allTypes.insert(HKObjectType.quantityType(forIdentifier: .sixMinuteWalkTestDistance)!)
            allTypes.insert(HKObjectType.quantityType(forIdentifier: .stairAscentSpeed)!)
            allTypes.insert(HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage)!)
            allTypes.insert(HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)!)
            allTypes.insert(HKObjectType.quantityType(forIdentifier: .walkingSpeed)!)
            allTypes.insert(HKObjectType.quantityType(forIdentifier: .walkingStepLength)!)
            allTypes.insert(HKObjectType.electrocardiogramType())
        }
        
        if #available(iOS 14.2, *) {
            allTypes.insert(HKObjectType.categoryType(forIdentifier: .headphoneAudioExposureEvent)!)
        }
    }

    init(
        healthKitClient: HealthKitClient,
        cloudantSampleStore: CloudantSampleStore,
        sampleTypes: Set<HKSampleType>
    ) {
        self.healthKitClient = healthKitClient
        self.cloudantSampleStore = cloudantSampleStore
        self.allTypes = sampleTypes
    }

    /**
    - Description: Call this function whenever we're going to sync data to HealthKitStore for the first time or we want to sync from CloudantStore to HealthKitStore when there's new data arrived from cloudant pull replicator.
    - Parameter direction: This function requires an OTFSyncDirection parameter to sync data.
     */
    public func syncWithHealthKit(direction: OTFSyncDirection) {
        guard healthKitClient.isHealthDataAvailable else { return }
        healthStoreSamples = []
        dataStoreSamples = []
        let dispatchGroup = DispatchGroup()
        for type in allTypes {
            dispatchGroup.enter()
            healthKitClient.fetchSamples(of: type) { [weak self] samples, error in
                guard let self = self else { return }
                self.processQueryResult(samples: samples, error: error)
                dispatchGroup.leave()
            }
        }
        dispatchGroup.enter()
        cloudantSampleStore.fetchSamples { (result: Result<[OTFCloudantSample], OTFCloudantError>) in
            switch result {
            case .success(let samples):
                self.dataStoreSamples = samples
            case .failure(let error):
                OTFLogger.logger().error("Fetching OTFCloudantSamples failed with error: \(error.localizedDescription, privacy: .public)")
            }
            dispatchGroup.leave()
        }
        dispatchGroup.notify(queue: dispatchQueue) {
            self.syncSamples(direction: direction)
        }
    }
    
    public func processQueryResult(samples: [HKSample]?, error: Error?) {
        if let error = error {
            OTFLogger.logger().error("Fetching samples type failed with error: \(error.localizedDescription, privacy: .public)")
        }
        if let samples = samples {
            self.healthStoreSamples.append(contentsOf: samples)
        }
    }
    
    public func storSample(sample: HKSample, cloudantSample: OTFCloudantSample) {
        var isSampleStored = false
        for hkSample in self.healthStoreSamples {
            guard cloudantSample.isEqual(to: hkSample) else {
                continue
            }
            isSampleStored = true
            break
        }
        if !isSampleStored {
            self.healthKitClient.save(sample) { (succeeded, error) in
                if let error = error {
                    OTFLogger.logger().error("Saving sample from OTFCloudantStore failed with error: \(error.localizedDescription, privacy: .public)")
                } else if !succeeded {
                    OTFLogger.logger().error("Saving sample from OTFCloudantStore failed without error")
                    
                }
            }
        } else {
            OTFLogger.logger().error("Sample exists in HealthkitStore")
        }
    }

    private func syncSamples(direction: OTFSyncDirection) {
        if direction != .fromHKToCloudant {
            syncCloudantSamplesToHealthKit()
        }

        if direction != .fromCloudantToHK {
            syncHealthKitSamplesToCloudant()
        }
    }

    private func syncCloudantSamplesToHealthKit() {
        for cloudantSample in dataStoreSamples {
            guard let sample = cloudantSample.toHKSample() else { continue }
            storSample(sample: sample, cloudantSample: cloudantSample)
        }
    }

    private func syncHealthKitSamplesToCloudant() {
        for hkSample in healthStoreSamples {
            if isCloudantSampleStored(for: hkSample) {
                OTFLogger.logger().info("Sample exists in Cloudant")
            } else {
                cloudantSampleStore.addSamples([OTFCloudantSample(sample: hkSample, patientId: "")])
            }
        }
    }

    private func isCloudantSampleStored(for hkSample: HKSample) -> Bool {
        dataStoreSamples.contains { cloudantSample in
            cloudantSample.isEqual(to: hkSample)
        }
    }

    /*
     Call this function whenever we're going to sync data to HealthKitStore for the first time or we want to sync from CloudantStore to HealthKitStore when there's new data arrived from cloudant pull replicator
     */
    /**
     - Description: Call this function whenever we're going to sync data to HealthKitStore for the first time or we want to sync from CloudantStore to HealthKitStore of a particular HKSampleType when there's new data arrived from cloudant pull replicator
     - Parameter direction: This function requires a direction parameter that you can select from the OTFSyncDirection enum.
     - Parameter type: This function requires a sample type that you want to sync. You can choose the type from the HKSampleType enums.
     - Returns completion: This is a blank completion Handler 
     */
    public func syncWithHealthKit(direction: OTFSyncDirection, type: HKSampleType, completion: (() -> Void)?) {
        guard healthKitClient.isHealthDataAvailable else { return }
        healthStoreSamples = []
        dataStoreSamples = []
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        healthKitClient.fetchSamples(of: type) { [weak self] samples, error in
            guard let self = self else { return }
            self.processQueryResult(samples: samples, error: error)
            dispatchGroup.leave()
        }
        dispatchGroup.enter()
        cloudantSampleStore.fetchSamples { (result: Result<[OTFCloudantSample], OTFCloudantError>) in
            switch result {
            case .success(let samples):
                self.dataStoreSamples = samples
            case .failure(let error):
                OTFLogger.logger().error("Fetching OTFCloudantSamples failed with error: \(error.localizedDescription, privacy: .public)")
            }
            dispatchGroup.leave()
        }
        dispatchGroup.notify(queue: dispatchQueue) {
            self.syncSamples(direction: direction)
            completion?()
        }
    }

    /*
     This function is used to observe on the realtime updates of HealthKitStore
     */
    public func observeOnHKStoreRealTimeUpdates() {
        for type in allTypes {
            healthKitClient.observeSamples(
                of: type,
                initialHandler: { samplesOrNil, deletedObjectsOrNil in
                self.handleAnchoredQueryUpdate(
                    type: type,
                    samples: samplesOrNil,
                    deletedObjects: deletedObjectsOrNil,
                    saveSamples: { samples in
                        self.cloudantSampleStore.addSamples(samples)
                    }
                )
            },
                updateHandler: { samplesOrNil, deletedObjectsOrNil in
                self.handleAnchoredQueryUpdate(
                    type: type,
                    samples: samplesOrNil,
                    deletedObjects: deletedObjectsOrNil,
                    saveSamples: { samples in
                        self.cloudantSampleStore.updateSamples(samples)
                    }
                )
            }
            )
        }
    }

    private func handleAnchoredQueryUpdate(
        type: HKSampleType,
        samples: [HKSample]?,
        deletedObjects: [HealthKitDeletedSample]?,
        saveSamples: ([OTFCloudantSample]) -> Void
    ) {
        let samples = samples ?? []
        let deletedObjects = deletedObjects ?? []

        if !samples.isEmpty {
            let cloudantSamples = samples.map { OTFCloudantSample(sample: $0, patientId: "") }
            saveSamples(cloudantSamples)
        }

        deleteCloudantSamples(matching: deletedObjects, healthKitType: type)
    }

    private func deleteCloudantSamples(
        matching deletedObjects: [HealthKitDeletedSample],
        healthKitType: HKSampleType
    ) {
        let sampleType = cloudantSampleType(for: healthKitType)
        for deletedSample in deletedObjects {
            cloudantSampleStore.fetchSamples(
                healthKitSampleType: sampleType,
                uuid: deletedSample.uuid.uuidString
            ) { result in
                    if let samples = try? result.get() {
                        self.cloudantSampleStore.deleteSamples(samples)
                    }
            }
        }
    }

    private func cloudantSampleType(for healthKitType: HKSampleType) -> OTFHealthSampleType {
        if healthKitType is HKCorrelationType {
            return .correlation
        }

        if healthKitType is HKCategoryType {
            return .category
        }

        return .quantity
    }
}
#endif
