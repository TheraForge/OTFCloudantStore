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

// swiftlint:disable all
class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        requestAllPermissions()
    }

    private let healthStore = HKHealthStore()

    private func requestAllPermissions() {
        guard   let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
                let bloodType = HKObjectType.characteristicType(forIdentifier: .bloodType),
                let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
                let bodyMassIndex = HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
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
        let vitalCapacity = HKObjectType.quantityType(forIdentifier: .forcedVitalCapacity) else {
                return
        }

        var samples: Set<HKObjectType> = [vitaminB6, soarThroat, dietaryFolate, sleepAnalysis, oxygenSaturation, dietaryChloride, sexualActivity, electrodermalActivity, dietaryIron, pelvicPain, acne, coughing, bodyAche, lossOfTaste, diarrhea, pantothenicAcid, sleepChange, dietaryCalcium, nikeFuel, fatigue, headache, menstrualBleeding, allergyRecord, heartRate, dietaryCholesterol, dietarySodium, swimmingStrokeCount, abdominalCramps, peripheralPerfusionIndex, ovulationTestResult, fainting, peakExpirationFlowRate, heartRateVariabilitySDNN, dietaryIodine, runnyNose, vomiting, bodyFatPercantage, dizziness, appleStandTime, lowHeartRate, dietaryPhosphorus, vitalCapacity]

        if #available(iOS 14.2, *) {
            if let audioExposureEvent = HKObjectType.categoryType(forIdentifier: .headphoneAudioExposureEvent),
               let walkingPercentage = HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) {
                samples.insert(audioExposureEvent)
                samples.insert(walkingPercentage)
            }
        } else {
            // Fallback on earlier versions
        }

        let healthKitTypesToWrite: Set<HKSampleType> = [bodyMassIndex,
                                                        activeEnergy,
                                                        HKObjectType.workoutType()]

        let healthKitTypesToRead: Set<HKObjectType> = [dateOfBirth,
                                                       bloodType,
                                                       biologicalSex,
                                                       bodyMassIndex,
                                                       height,
                                                       bodyMass,
                                                       HKObjectType.workoutType()]
        let readSamples = samples.union(healthKitTypesToRead)

        healthStore.requestAuthorization(toShare: healthKitTypesToWrite, read: readSamples) { (success: Bool, error: Error?) in
        }
    }

}
