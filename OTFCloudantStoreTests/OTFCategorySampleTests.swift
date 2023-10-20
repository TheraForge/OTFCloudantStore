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

import XCTest
import OTFCloudantStore
import HealthKit
import OTFUtilities

class OTFCategorySampleTests: OTFCloudantTests {
    #if HEALTH
    // swiftlint:disable line_length
    private let identifiers: [HKCategoryTypeIdentifier] = [.abdominalCramps, .sleepAnalysis, .sleepChanges, .acne, .appetiteChanges, .bladderIncontinence, .bloating, .breastPain, .cervicalMucusQuality, .chestTightnessOrPain, .chills, .constipation, .contraceptive, .coughing, .diarrhea, .dizziness, .drySkin, .fainting, .fatigue, .fever, .generalizedBodyAche, .hairLoss, .handwashingEvent, .headache, .heartburn, .hotFlashes, .intermenstrualBleeding, .lactation, .lossOfSmell, .lossOfTaste, .lowerBackPain, .memoryLapse, .menstrualFlow, .mindfulSession, .moodChanges, .nausea, .nightSweats, .ovulationTestResult, .pelvicPain, .pregnancy, .rapidPoundingOrFlutteringHeartbeat, .runnyNose, .sexualActivity, .shortnessOfBreath, .sinusCongestion, .skippedHeartbeat, .soreThroat, .toothbrushingEvent, .vaginalDryness, .vomiting, .wheezing]

    override func setUp() {
        super.setUp()
    }

    func testCategorySamples() {
        let semaphor = DispatchSemaphore(value: 0)

        let expect = expectation(description: "Wait until user give permissions.")

        var readPermissions: Set<HKObjectType> = []
        var writePermission: Set<HKSampleType> = []

        for identifier in identifiers {
            guard let categoryType = HKObjectType.categoryType(forIdentifier: identifier) else {
                OTFLog("This identifier no longer available in HealthKit", identifier)
                break
            }
            if self.healthStore.authorizationStatus(for: categoryType) != .sharingAuthorized {
                if let object = HKObjectType.categoryType(forIdentifier: identifier) {
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

        for identifier in identifiers {
            saveCategorySample(identifier: identifier) {
                semaphor.signal()
            }
            semaphor.wait()
        }
    }

    // swiftlint:disable trailing_closure
    func saveCategorySample(identifier: HKCategoryTypeIdentifier, completion: @escaping (() -> Void)) {
        let expect = expectation(description: "It should wait until saving finishes.")

        if let categoryType = HKObjectType.categoryType(forIdentifier: identifier), let endDate = Date().addMinute(20) {
            let value = identifier.valueForIdentifier
            OTFLog("Identifier %{public}@", identifier)
            let metadata = identifier.metadata
            let categorySample = HKCategorySample(type: categoryType, value: value, start: Date(), end: endDate, metadata: metadata)

            healthStore.save(categorySample, withCompletion: { (success, error) -> Void in

                if let error = error {
                    XCTFail(error.localizedDescription)
                    completion()
                }

                if success {
                    OTFLog("My new data was saved in Healthkit", success)
                    self.synchronizer.syncWithHealthKit(direction: .fromHKToCloudant, type: categoryType) {
                        OTFLog("Sync done", categoryType)
                        DispatchQueue.main.async {
                            self.findInCloudant(uuid: categorySample.uuid, in: .category) { sample in
                                if let qSample = sample as? HKCategorySample {
                                    OTFLog("Test succeded for - %{public}@", identifier.rawValue)
                                    XCTAssertEqual(qSample.value, categorySample.value)
                                } else {
                                    OTFLog("Nil quantity type - %{public}@", identifier.rawValue)
                                    XCTFail("Can't find \(identifier.rawValue)")
                                }
                                expect.fulfill()
                                completion()
                            }
                        }
                    }
                } else {
                    // It was an error again
                    XCTFail("error has been occured....")
                    completion()
                }
            })
        }

        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }
    #endif
}

extension HKCategoryTypeIdentifier {

    var metadata: [String: Bool]? {
        switch self {
        case .menstrualFlow:
            return [HKMetadataKeyMenstrualCycleStart: true]
        default:
            return nil
        }
    }

    var valueForIdentifier: Int {
        switch self {
        case .abdominalCramps:
            return HKCategoryValueSeverity.mild.rawValue
        case .sleepAnalysis:
            return  HKCategoryValueSleepAnalysis.inBed.rawValue
        case .sleepChanges:
            return HKCategoryValuePresence.present.rawValue
        case .acne:
            return HKCategoryValueSeverity.moderate.rawValue
        case .appetiteChanges:
            return HKCategoryValueAppetiteChanges.increased.rawValue
        case .bladderIncontinence:
            return HKCategoryValueSeverity.mild.rawValue
        case .bloating:
            return HKCategoryValueSeverity.mild.rawValue
        case .breastPain:
            return HKCategoryValueSeverity.mild.rawValue
        case .cervicalMucusQuality:
            return HKCategoryValueCervicalMucusQuality.dry.rawValue
        case .chestTightnessOrPain:
            return HKCategoryValueSeverity.moderate.rawValue
        case .chills:
            return HKCategoryValueSeverity.moderate.rawValue
        case .constipation:
            return HKCategoryValueSeverity.moderate.rawValue
        case .contraceptive:
            return HKCategoryValueContraceptive.injection.rawValue
        case .coughing:
            return HKCategoryValueSeverity.mild.rawValue
        case .diarrhea:
            return HKCategoryValueSeverity.mild.rawValue
        case .dizziness:
            return HKCategoryValueSeverity.mild.rawValue
        case .drySkin:
            return HKCategoryValueSeverity.mild.rawValue
        case .fainting:
            return HKCategoryValueSeverity.mild.rawValue
        case .fatigue:
            return HKCategoryValueSeverity.mild.rawValue
        case .fever:
            return HKCategoryValueSeverity.mild.rawValue
        case .generalizedBodyAche:
            return HKCategoryValueSeverity.mild.rawValue
        case .hairLoss:
            return HKCategoryValueSeverity.mild.rawValue
        case .handwashingEvent:
            return HKCategoryValue.notApplicable.rawValue
        case .headache:
            return HKCategoryValueSeverity.mild.rawValue
        case .heartburn:
            return HKCategoryValueSeverity.mild.rawValue
        case .hotFlashes:
            return HKCategoryValueSeverity.mild.rawValue
        case .intermenstrualBleeding:
            return HKCategoryValue.notApplicable.rawValue
        case .lactation:
            return HKCategoryValue.notApplicable.rawValue
        case .lossOfSmell:
            return HKCategoryValueSeverity.mild.rawValue
        case .lossOfTaste:
            return HKCategoryValueSeverity.mild.rawValue
        case .lowerBackPain:
            return HKCategoryValueSeverity.mild.rawValue
        case .memoryLapse:
            return HKCategoryValueSeverity.mild.rawValue
        case .menstrualFlow:
            return HKCategoryValueMenstrualFlow.light.rawValue
        case .mindfulSession:
            return HKCategoryValue.notApplicable.rawValue
        case .moodChanges:
            return HKCategoryValuePresence.notPresent.rawValue
        case .nausea:
            return HKCategoryValueSeverity.mild.rawValue
        case .nightSweats:
            return HKCategoryValueSeverity.mild.rawValue
        case .ovulationTestResult:
            return HKCategoryValueOvulationTestResult.indeterminate.rawValue
        case .pelvicPain:
            return HKCategoryValueSeverity.mild.rawValue
        case .pregnancy:
            return HKCategoryValue.notApplicable.rawValue
        case .rapidPoundingOrFlutteringHeartbeat:
            return HKCategoryValueSeverity.mild.rawValue
        case .runnyNose:
            return HKCategoryValueSeverity.mild.rawValue
        case .sexualActivity:
            return HKCategoryValue.notApplicable.rawValue
        case .shortnessOfBreath:
            return HKCategoryValueSeverity.mild.rawValue
        case .sinusCongestion:
            return HKCategoryValueSeverity.mild.rawValue
        case .skippedHeartbeat:
            return HKCategoryValueSeverity.mild.rawValue
        case .soreThroat:
            return HKCategoryValueSeverity.mild.rawValue
        case .toothbrushingEvent:
            return HKCategoryValue.notApplicable.rawValue
        case .vaginalDryness:
            return HKCategoryValueSeverity.mild.rawValue
        case .vomiting:
            return HKCategoryValueSeverity.mild.rawValue
        case .wheezing:
            return HKCategoryValueSeverity.mild.rawValue

        default:
            fatalError("Case not implemented yet.... \(self)")
        }
    }
}
