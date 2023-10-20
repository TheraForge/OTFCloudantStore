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

/**
 The synchronisation between HealthKitStore and CloudantStore.
 */
// swiftlint:disable all
public class OTFHealthKitSynchronizer {
    
    /// An interface between Carekit, HealthKit and CDTDatastore.
    private let dataStore: OTFCloudantStore!
    
    /// An interface for accessing and storing the user's health data.
    private let healthStore: HKHealthStore!
    
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
        self.dataStore = dataStore
        self.healthStore = healthStore
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
                            HKObjectType.categoryType(forIdentifier: .audioExposureEvent)!,
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

    /**
    - Description: Call this function whenever we're going to sync data to HealthKitStore for the first time or we want to sync from CloudantStore to HealthKitStore when there's new data arrived from cloudant pull replicator.
    - Parameter direction: This function requires an OTFSyncDirection parameter to sync data.
     */
    public func syncWithHealthKit(direction: OTFSyncDirection) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let dispatchGroup = DispatchGroup()
        for type in allTypes {
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self](_, samples, error) in
                guard let self = self else { return }
                if let error = error {
                    OTFError("Fetching samples type failed with error: %{public}@", error.localizedDescription)
                }
                if let samples = samples {
                    self.healthStoreSamples.append(contentsOf: samples)
                }
                dispatchGroup.leave()
            }
            dispatchGroup.enter()
            healthStore.execute(query)
        }
        dispatchGroup.enter()
        dataStore.collection(className: "OTFCloudantSample").get { (result: Result<[OTFCloudantSample], OTFCloudantError>) in
            switch result {
            case .success(let samples):
                self.dataStoreSamples = samples
            case .failure(let error):
                OTFError("Fetching OTFCloudantSamples failed with error: %{public}@", error.localizedDescription)
            }
            dispatchGroup.leave()
        }
        dispatchGroup.notify(queue: dispatchQueue) {
            // Sync from Cloudant to HealthKitStore
            if direction != .fromHKToCloudant {
                for cloudantSample in self.dataStoreSamples {
                    guard let sample = cloudantSample.toHKSample() else { continue }
                    var isSampleStored = false
                    for hkSample in self.healthStoreSamples {
                        if cloudantSample.isEqual(to: hkSample) {
                            isSampleStored = true
                            break
                        }
                    }
                    if !isSampleStored {
                        self.healthStore.save(sample) { (succeeded, error) in
                            if let error = error {
                                OTFError("Saving sample from OTFCloudantStore failed with error: %{public}@", error.localizedDescription)
                            } else if !succeeded {
                                OTFError("Saving sample from OTFCloudantStore failed without error", "")
                                
                            }
                        }
                    } else {
                        OTFError("Sample exists in HealthkitStore", "")
                    }
                }
            }

            // Sync from HealthKitStore to Cloudant
            if direction != .fromCloudantToHK {
                for hkSample in self.healthStoreSamples {
                    var isSampleStored = false
                    for cloudantSample in self.dataStoreSamples {
                        if cloudantSample.isEqual(to: hkSample) {
                            isSampleStored = true
                            break
                        }
                    }
                    if !isSampleStored {
                        self.dataStore.add([OTFCloudantSample(sample: hkSample, patientId: "")])
                    } else {
                        OTFLog("Sample exists in Cloudant", "succeeded")
                    }
                }
            }
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
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self](_, samples, error) in
            guard let self = self else { return }
            if let error = error {
                OTFError("Fetching samples type failed with error: %{public}@", error.localizedDescription)
            }
            if let samples = samples, !samples.isEmpty {
                self.healthStoreSamples.append(contentsOf: samples)
            }
            dispatchGroup.leave()
        }
        healthStore.execute(query)
        dispatchGroup.enter()
        dataStore.collection(className: "OTFCloudantSample").get { (result: Result<[OTFCloudantSample], OTFCloudantError>) in
            switch result {
            case .success(let samples):
                self.dataStoreSamples = samples
            case .failure(let error):
                OTFError("Fetching OTFCloudantSamples failed with error: %{public}@", error.localizedDescription)
            }
            dispatchGroup.leave()
        }
        dispatchGroup.notify(queue: dispatchQueue) {
            // Sync from Cloudant to HealthKitStore
            if direction != .fromHKToCloudant {
                for cloudantSample in self.dataStoreSamples {
                    guard let sample = cloudantSample.toHKSample() else { continue }
                    var isSampleStored = false
                    for hkSample in self.healthStoreSamples {
                        if cloudantSample.isEqual(to: hkSample) {
                            isSampleStored = true
                            break
                        }
                    }
                    if !isSampleStored {
                        self.healthStore.save(sample) { (succeeded, error) in
                            if let error = error {
                                OTFError("Saving sample from OTFCloudantStore failed with error: %{public}@", error.localizedDescription)
                            } else if !succeeded {
                                OTFLog("Saving sample from OTFCloudantStore failed without error", "Not succeeded")
                            }
                        }
                    } else {
                        OTFLog("Sample exists in HealthkitStore", "succeeded")
                    }
                }
            }
            // Sync from HealthKitStore to Cloudant
            if direction != .fromCloudantToHK {
                for hkSample in self.healthStoreSamples {
                    var isSampleStored = false
                    for cloudantSample in self.dataStoreSamples{
                        if cloudantSample.isEqual(to: hkSample) {
                            isSampleStored = true
                            break
                        }
                    }
                    if !isSampleStored {
                        self.dataStore.add([OTFCloudantSample(sample: hkSample, patientId: "")])
                    } else {
                        OTFLog("Sample exists in Cloudant", "succeeded")
                    }
                }
            }

            completion?()
        }
    }

    /*
     This function is used to observe on the realtime updates of HealthKitStore
     */
    public func observeOnHKStoreRealTimeUpdates() {
        for type in allTypes {
            let query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { (anchoredQuery, samplesOrNil, deletedObjectsOrNil, queryAnchor, error) in
                guard let samples = samplesOrNil, let deletedObjects = deletedObjectsOrNil else {
                    // Properly handle the error.
                    return
                }
                // add new samples to CloudantStore
                let cloudantSamples = samples.map { OTFCloudantSample(sample: $0, patientId: "") }
                self.dataStore.add(cloudantSamples)
                // delete samples from CloudantStore
                for deletedSample in deletedObjects {
                    var sampleType: OTFHealthSampleType = .quantity
                    if type is HKCorrelationType {
                        sampleType = .correlation
                    } else if type is HKCategoryType{
                        sampleType = .category
                    }
                    self.dataStore.collection(healthKitSampleType: sampleType).where("uuid", isEqualTo: deletedSample.uuid.uuidString).getCloudantSamples { (result) in
                        if let samples = try? result.get() {
                            self.dataStore.delete(samples)
                        }
                    }
                }
            }
            query.updateHandler = { (query, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil) in
                guard let samples = samplesOrNil, let deletedObjects = deletedObjectsOrNil else {
                    // Properly handle the error.
                    return
                }
                // add new samples to CloudantStore
                let cloudantSamples = samples.map { OTFCloudantSample(sample: $0, patientId: "") }
                self.dataStore.update(cloudantSamples)
                // delete samples from CloudantStore
                for deletedSample in deletedObjects {
                    var sampleType: OTFHealthSampleType = .quantity
                    if type is HKCorrelationType {
                        sampleType = .correlation
                    } else if type is HKCategoryType {
                        sampleType = .category
                    }
                    self.dataStore.collection(healthKitSampleType: sampleType).where("uuid", isEqualTo: deletedSample.uuid.uuidString).getCloudantSamples { (result) in
                        if let samples = try? result.get() {
                            self.dataStore.delete(samples)
                        }
                    }
                }
            }
            healthStore.execute(query)
        }
    }
}
#endif
