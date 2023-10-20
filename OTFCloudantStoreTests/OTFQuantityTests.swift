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
import OTFCloudantStore
import HealthKit
import XCTest
import OTFUtilities

class OTFQuantityTests: OTFCloudantTests {
    #if HEALTH
    // swiftlint:disable line_length
    private let quantityIdentifiers: [HKQuantityTypeIdentifier] = [.bodyMassIndex, .bodyFatPercentage, .leanBodyMass, .waistCircumference, .activeEnergyBurned, .distanceWalkingRunning, .bodyMassIndex, .stepCount, .height, .bodyMass, .distanceCycling, .distanceWheelchair, .basalEnergyBurned, .activeEnergyBurned, .flightsClimbed, .pushCount, .distanceSwimming, .swimmingStrokeCount, .distanceDownhillSnowSports, .walkingSpeed, .walkingDoubleSupportPercentage, .walkingStepLength, .sixMinuteWalkTestDistance, .stairAscentSpeed, .stairDescentSpeed, .heartRate, .bodyTemperature, .basalBodyTemperature, .bloodPressureSystolic, .bloodPressureDiastolic, .respiratoryRate, .restingHeartRate, .heartRateVariabilitySDNN, .oxygenSaturation, .peripheralPerfusionIndex, .numberOfTimesFallen, .electrodermalActivity, .inhalerUsage, .bloodAlcoholContent, .forcedVitalCapacity, .forcedExpiratoryVolume1, .peakExpiratoryFlowRate, .environmentalAudioExposure, .headphoneAudioExposure, .dietaryFatTotal, .dietaryFatPolyunsaturated, .dietaryFatMonounsaturated, .dietaryFatSaturated, .dietaryCholesterol, .dietarySodium, .dietaryCarbohydrates, .dietaryFiber, .dietarySugar, .dietaryEnergyConsumed, .dietaryProtein, .dietaryVitaminA, .dietaryVitaminB6, .dietaryVitaminB12, .dietaryVitaminC, .dietaryVitaminD, .dietaryVitaminE, .dietaryVitaminK, .dietaryCalcium, .dietaryIron, .dietaryThiamin, .dietaryRiboflavin, .dietaryNiacin, .dietaryFolate, .dietaryPantothenicAcid, .dietaryPhosphorus, .dietaryIodine, .dietaryMagnesium, .dietaryZinc, .dietarySelenium, .dietaryCopper, .dietaryManganese, .dietaryChromium, .dietaryMolybdenum, .dietaryChloride, .dietaryPotassium, .dietaryCaffeine, .dietaryWater, .uvExposure]

    override func setUp() {
        super.setUp()
    }

    func testQuantitySamples() {
        let semaphor = DispatchSemaphore(value: 0)

        let expect = expectation(description: "Wait until user give permissions.")

        var readPermissions: Set<HKObjectType> = []
        var writePermission: Set<HKSampleType> = []

        for identifier in quantityIdentifiers {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
                OTFLog("This identifier no longer available in HealthKit: %{public}@", identifier)
                break
            }
            if self.healthStore.authorizationStatus(for: quantityType) != .sharingAuthorized {
                if let object = HKObjectType.quantityType(forIdentifier: identifier) {
                    readPermissions.insert(object)
                    writePermission.insert(object)
                }
            }
        }

        if !readPermissions.isEmpty || !writePermission.isEmpty {
            self.healthKitAuthrization(read: readPermissions, write: writePermission) { (status, error) in
                expect.fulfill()
                if let error = error {
                    XCTFail(error.localizedDescription)
                } else if !status {
                    XCTFail("Unable to get the permission from the user.")
                }
            }
        } else {
            expect.fulfill()
        }

        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }

        for identifier in quantityIdentifiers {
            saveQuantitySamples(identifier: identifier) {
                semaphor.signal()
            }
            semaphor.wait()
        }
    }

    func saveQuantitySamples(identifier: HKQuantityTypeIdentifier, completion: @escaping (() -> Void) ) {
        let expect = expectation(description: "It should wait until saving finishes.")
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            fatalError("\(identifier) is no longer available in HealthKit")
        }

        guard let unit = OTFParsingHelper.preferredUnit(for: identifier.rawValue) else {
            XCTFail("Can't find unit for \(identifier.rawValue)")
            return
        }

        let quantity = HKQuantity(unit: unit,
                                           doubleValue: stepCountsValue)
        let startDate = Date()
        let endDate = Date().addMinute(10) ?? Date()
        let quantitySample = HKQuantitySample(type: quantityType,
                                                    quantity: quantity,
                                                    start: startDate,
                                                    end: endDate)
        healthStore.save(quantitySample) { (_, error) in
            if let error = error {
                XCTFail("Error Saving \(identifier) Sample: \(error.localizedDescription)")
            } else {
                self.synchronizer.syncWithHealthKit(direction: .fromHKToCloudant, type: quantityType) {
                    DispatchQueue.main.async {
                        self.findInCloudant(uuid: quantitySample.uuid, in: .quantity) { sample in
                            if let qSample = sample as? HKQuantitySample {
                                OTFLog("Test succeded for - %{public}@", identifier.rawValue)
                                XCTAssertEqual(qSample.quantity, quantity)
                            } else {
                                OTFLog("Nil quantity type - %{public}@", identifier.rawValue)
                                XCTFail("Can't find \(identifier.rawValue)")
                            }
                            expect.fulfill()
                            completion()
                        }
                    }
                }
            }
        }

        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }
    #endif
}
