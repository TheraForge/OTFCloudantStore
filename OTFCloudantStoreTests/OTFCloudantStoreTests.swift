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
import HealthKit
import XCTest
import OTFCloudantStore
import OTFUtilities

class OTFCloudantStoreTests: OTFCloudantTests {
    #if HEALTH && CARE
    var sampleTypes: Set<HKObjectType>!

    override func setUp() {
        super.setUp()
        promptForPermissions()
    }

    private func promptForPermissions() {
        if isHealthKitAvailable() {

            guard   let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
                    let walkingRunning = HKWorkoutType.quantityType(forIdentifier: .distanceWalkingRunning),
                    let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
                    let bodyMassIndex = HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
                    let stepsCount = HKObjectType.quantityType(forIdentifier: .stepCount),
                    let height = HKObjectType.quantityType(forIdentifier: .height),
                    let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
                    let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
                    let vitaminB6 = HKObjectType.quantityType(forIdentifier: .dietaryVitaminB6),
                    let soarThroat = HKObjectType.categoryType(forIdentifier: .soreThroat),
                    let dietaryFolate = HKObjectType.quantityType(forIdentifier: .dietaryFolate),
                    let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
                    let oxygenSaturation = HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
                    let dietaryChloride = HKObjectType.quantityType(forIdentifier: .dietaryChloride),
                    let sexualActivity = HKObjectType.categoryType(forIdentifier: .sexualActivity),
                    let electrodermalActivity = HKObjectType.quantityType(forIdentifier: .electrodermalActivity),
                    let dietaryIron = HKObjectType.quantityType(forIdentifier: .dietaryIron),
                    let pelvicPain = HKObjectType.categoryType(forIdentifier: .pelvicPain),
                    let acne = HKObjectType.categoryType(forIdentifier: .acne),
                    let coughing = HKObjectType.categoryType(forIdentifier: .coughing),
                    let bodyAche = HKObjectType.categoryType(forIdentifier: .generalizedBodyAche),
                    let lossOfTaste = HKObjectType.categoryType(forIdentifier: .lossOfTaste),
                    let audioExposureEvent = HKObjectType.categoryType(forIdentifier: .headphoneAudioExposureEvent),
                    let diarrhea = HKObjectType.categoryType(forIdentifier: .diarrhea),
                    let pantothenicAcid = HKObjectType.quantityType(forIdentifier: .dietaryPantothenicAcid),
                    let sleepChange = HKObjectType.categoryType(forIdentifier: .sleepChanges),
                    let dietaryCalcium = HKObjectType.quantityType(forIdentifier: .dietaryCalcium),
                    let nikeFuel = HKObjectType.quantityType(forIdentifier: .nikeFuel),
                    let fatigue = HKObjectType.categoryType(forIdentifier: .fatigue),
                    let headache = HKObjectType.categoryType(forIdentifier: .headache),
                    let menstrualBleeding = HKObjectType.categoryType(forIdentifier: .intermenstrualBleeding),
                    let allergyRecord = HKObjectType.clinicalType(forIdentifier: .allergyRecord),
                    let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
                    let dietaryCholesterol = HKObjectType.quantityType(forIdentifier: .dietaryCholesterol),
                    let dietarySodium = HKObjectType.quantityType(forIdentifier: .dietarySodium),
                    let walkingPercentage = HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage),
                    let swimmingStrokeCount = HKObjectType.quantityType(forIdentifier: .swimmingStrokeCount),
                    let abdominalCramps = HKObjectType.categoryType(forIdentifier: .abdominalCramps),
                    let peripheralPerfusionIndex = HKObjectType.quantityType(forIdentifier: .peripheralPerfusionIndex),
                    let ovulationTestResult = HKObjectType.categoryType(forIdentifier: .ovulationTestResult),
                    let fainting = HKObjectType.categoryType(forIdentifier: .fainting),
                    let peakExpirationFlowRate = HKObjectType.quantityType(forIdentifier: .peakExpiratoryFlowRate),
                    let heartRateVariabilitySDNN = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                    let dietaryIodine = HKObjectType.quantityType(forIdentifier: .dietaryIodine),
                    let runnyNose = HKObjectType.categoryType(forIdentifier: .runnyNose),
                    let vomiting = HKObjectType.categoryType(forIdentifier: .vomiting),
                    let bodyFatPercantage = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
                    let dizziness = HKObjectType.categoryType(forIdentifier: .dizziness),
                    let appleStandTime = HKObjectType.quantityType(forIdentifier: .appleStandTime),
                    let lowHeartRate = HKObjectType.categoryType(forIdentifier: .lowHeartRateEvent),
                    let dietaryPhosphorus = HKObjectType.quantityType(forIdentifier: .dietaryPhosphorus),
                    let vitalCapacity = HKObjectType.quantityType(forIdentifier: .forcedVitalCapacity),
                    let dietaryThiamin = HKObjectType.quantityType(forIdentifier: .dietaryThiamin),
                    let immunizationRecord = HKObjectType.clinicalType(forIdentifier: .immunizationRecord),
                    let enviromentalAudioExposure = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure),
                    let timeFallen = HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen),
                    let appetiteChanges = HKObjectType.categoryType(forIdentifier: .appetiteChanges),
                    let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
                    let menstrualFlow = HKObjectType.categoryType(forIdentifier: .menstrualFlow),
                    let dietaryMagnesium = HKObjectType.quantityType(forIdentifier: .dietaryMagnesium),
                    let walkingAsymmetryPercentage = HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage),
                    let leanBodyMass = HKObjectType.quantityType(forIdentifier: .leanBodyMass),
                    let dietaryFiber = HKObjectType.quantityType(forIdentifier: .dietaryFiber),
                    let walkingSpeed = HKObjectType.quantityType(forIdentifier: .walkingSpeed),
                    let dietoryRiboFlavin = HKObjectType.quantityType(forIdentifier: .dietaryRiboflavin),
                    let dietarySelenium = HKObjectType.quantityType(forIdentifier: .dietarySelenium),
                    let labResultRecord = HKObjectType.clinicalType(forIdentifier: .labResultRecord),
                    let rapidPoundingOrFlutterringHeartbeat = HKObjectType.categoryType(forIdentifier: .rapidPoundingOrFlutteringHeartbeat),
                    let fever = HKObjectType.categoryType(forIdentifier: .fever),
                    let constipation = HKObjectType.categoryType(forIdentifier: .constipation),
                    let appleExerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
                return
            }

            // swiftlint:disable line_length
            sampleTypes = [walkingRunning, vitaminB6, stepsCount, soarThroat, dietaryFolate, sleepAnalysis, oxygenSaturation, dietaryChloride, sexualActivity, electrodermalActivity, dietaryIron, pelvicPain, acne, coughing, bodyAche, lossOfTaste, audioExposureEvent, diarrhea, pantothenicAcid, sleepChange, dietaryCalcium, nikeFuel, fatigue, headache, menstrualBleeding, allergyRecord, heartRate, dietaryCholesterol, dietarySodium, walkingPercentage, swimmingStrokeCount, abdominalCramps, peripheralPerfusionIndex, ovulationTestResult, fainting, peakExpirationFlowRate, heartRateVariabilitySDNN, dietaryIodine, runnyNose, vomiting, bodyFatPercantage, dizziness, appleStandTime, lowHeartRate, dietaryPhosphorus, vitalCapacity, dietaryThiamin, immunizationRecord, enviromentalAudioExposure, timeFallen, appetiteChanges, restingHeartRate, menstrualFlow, dietaryMagnesium, walkingAsymmetryPercentage, leanBodyMass, dietaryFiber, walkingSpeed, dietoryRiboFlavin, dietarySelenium, labResultRecord, rapidPoundingOrFlutterringHeartbeat, fever, constipation, appleExerciseTime, dateOfBirth, dateOfBirth, biologicalSex, bodyMassIndex, height, bodyMass, HKObjectType.workoutType()]

            let healthKitTypesToWrite: Set<HKSampleType> = [walkingRunning, bodyMassIndex,
                                                            activeEnergy,
                                                            stepsCount,
                                                            bodyMass,
                                                            HKObjectType.workoutType()]

            let authorizationExpectation = expectation(description: "Wait for authorization. Need to do manual authorize on first launch.")
            self.healthKitAuthrization(read: sampleTypes, write: healthKitTypesToWrite) { (status, error) in
                authorizationExpectation.fulfill()
                if let error = error {
                    XCTFail(error.localizedDescription)
                } else if !status {
                    XCTFail("Unable to get the permission from the user.")
                }
            }

            waitForExpectations(timeout: 30) { error in
                if let error = error {
                    XCTFail(error.localizedDescription)
                }
            }

        } else {
            XCTFail("HealthKit is not available.")
        }
    }

    // MARK: - Test syncing from HealthKit to OCKCloudantStore 'HKQuantityType'
    func testHealthKitToCloudantSync() {
        let timeout: TimeInterval = 20
        guard let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            fatalError("step count type is no longer available in HealthKit")
        }

        guard self.healthStore.authorizationStatus(for: stepCount) == .sharingAuthorized else {
            XCTFail("Permission not granted to access step counts")
            return
        }

        // 2. Use the Count HKUnit to create a step count quantity
        let stepCountQuantity = HKQuantity(unit: .count(),
                                          doubleValue: stepCountsValue)

        let stepCountQuantitySample = HKQuantitySample(type: stepCount,
                                                   quantity: stepCountQuantity,
                                                   start: Date(),
                                                   end: Date())

        let saveExpectation = expectation(description: "This is expected to save Step Count data in healthKit with in \(timeout) seconds.")
        // 3. Save the same to HealthKit
        healthStore.save(stepCountQuantitySample) { (_, error) in
            if let error = error {
                XCTFail("Error Saving Step Count Sample: \(error.localizedDescription)")
            } else {
                OTFLog("Successfully saved STEPS COUNT Sample", "successed")
                self.synchronizer.syncWithHealthKit(direction: .fromHKToCloudant, type: stepCount) {
                    self.cloudantSyncWithHealthKit { hkSample in
                        if let sample = hkSample {
                            OTFLog("*** Sample quantity *** %{public}@", sample.quantity)
                            XCTAssertEqual(sample.quantity, stepCountQuantity)
                        } else {
                            XCTFail("Can't find the data into Cloudant store")
                        }
                        saveExpectation.fulfill()
                    }
                }
            }
        }

        waitForExpectations(timeout: timeout) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    // MARK: - Test syncing from OCKCloudantStore to HealthKit
    func testCloudantStoreToHealthKitSync() {
        guard let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            fatalError("Step count Type is no longer available in HealthKit")
        }

        guard self.healthStore.authorizationStatus(for: stepCount) == .sharingAuthorized else {
            XCTFail("Permission not granted to access step counts")
            return
        }

        // 2. Use the Count HKUnit to create a step count quantity
        let stepCountQuantity = HKQuantity(unit: .count(),
                                          doubleValue: stepCountsValue)

        let stepCountIndexSample = HKQuantitySample(type: stepCount,
                                                   quantity: stepCountQuantity,
                                                   start: Date(),
                                                   end: Date())
        self.cloudantStore.add([OTFCloudantSample(sample: stepCountIndexSample, patientId: "")])

        self.synchronizer.syncWithHealthKit(direction: .fromCloudantToHK, type: stepCount) {
            DispatchQueue.main.async {
                self.readDataFromHealthKit()
            }
        }
    }

    func readDataFromHealthKit() {
        guard let stepCountType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        let expect = expectation(description: "We're waiting for 10 seconds till healthkit read data and returns to completion handler block.")
        let mostRecentPredicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: [])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let limit = 1

        let sampleQuery = HKSampleQuery(sampleType: stepCountType,
                                        predicate: mostRecentPredicate,
                                        limit: limit,
                                        sortDescriptors: [sortDescriptor]) { (_, samples, _) in
                guard let sample = samples, let mostRecentSample = sample.first as? HKQuantitySample else {
                    XCTFail("sample is missing....")
                    return
                }
            OTFLog("*** MOST RECENT SAMPLE - \n %{public}@", mostRecentSample.quantity)
                XCTAssertEqual(mostRecentSample.quantity, HKQuantity(unit: .count(), doubleValue: self.stepCountsValue))
                expect.fulfill()
        }

        healthStore.execute(sampleQuery)

        waitForExpectations(timeout: 20) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testWorkoutSyncHealthKitToCloudant() {
        guard let distanceRunning = HKWorkoutType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            fatalError("Distance walking running type is no longer available in HealthKit")
        }

        guard self.healthStore.authorizationStatus(for: distanceRunning) == .sharingAuthorized else {
            XCTFail("Permission not granted to access distance walking running")
            return
        }

        let expect = expectation(description: "We will wait for 10 second to save workwout data.")

        let startDate = Date()
        let finishDate = Date().addingTimeInterval(100)

        let totalDistance = HKQuantity(unit: .meter(), doubleValue: 800)

        let workout = HKWorkout(activityType: .running, start: startDate, end: finishDate, workoutEvents: nil, totalEnergyBurned: nil, totalDistance: totalDistance, device: nil, metadata: nil)

        healthStore.save(workout) { (status, error) in
            if let error = error {
                XCTFail(error.localizedDescription)
            } else if !status {
                XCTFail("Failed to save workout")
            } else {
                OTFLog("**** Saved WorkoutSync ****", "")
                self.synchronizer.syncWithHealthKit(direction: .fromHKToCloudant, type: distanceRunning) {

                    let sampleType: OTFHealthSampleType = .quantity
                    self.cloudantStore.collection(healthKitSampleType: sampleType).getCloudantSamples { (result) in
                        switch result {
                        case .success(let samples):
                            OTFLog("samples: %{public}@", samples.rawValue)
                        case .failure(let error):
                            XCTFail(error.localizedDescription)
                        }
                        expect.fulfill()
                    }

                }
            }
        }

        waitForExpectations(timeout: 300) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }
    #endif
}
