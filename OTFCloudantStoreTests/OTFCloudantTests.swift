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

class OTFCloudantTests: XCTestCase {
    #if HEALTH
    let healthStore = HKHealthStore()
    let stepCountsValue: Double = 20
    let storeName = "test_store"
    var cloudantStore: OTFCloudantStore!
    var synchronizer: OTFHealthKitSynchronizer!

    override func setUp() {
        super.setUp()
        let expectat = expectation(description: "Wait for authorization. Need to do manual authorize on first launch.")
        do {
            self.cloudantStore = try OTFCloudantStore(storeName: storeName)
            self.synchronizer = OTFHealthKitSynchronizer(dataStore: self.cloudantStore, healthStore: self.healthStore)
            self.deleteOldData {
                expectat.fulfill()
            }
        } catch {
            XCTFail(error.localizedDescription)
        }

        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func deleteOldData(completion: @escaping ( () -> Void)) {

        let sampleTypes: [OTFHealthSampleType] = [.quantity, .category, .correlation]
        let group = DispatchGroup()

        for type in sampleTypes {
            group.enter()
            OTFLog("Deleting Old data for......%{public}@ ", type)
            cloudantStore.collection(healthKitSampleType: type).getSamples { result in
                switch result {
                case .success(let samples):
                    self.cloudantStore.deleteSamples(samples: samples)
                    self.healthStore.delete(samples) { _, _ in
                        OTFLog("Old Data deleted successfully.....", samples)
                        group.leave()
                    }
                case .failure:
                    OTFError("No data found...", "failure")
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    func healthKitAuthrization(read: Set<HKObjectType>?, write: Set<HKSampleType>?, completionHandler: @escaping (Bool, Error?) -> Void) {
        healthStore.requestAuthorization(toShare: write, read: read, completion: completionHandler)
    }
    #endif
}

#if HEALTH
extension OTFCloudantTests {
    func findInCloudant(uuid: UUID, in sampleType: OTFHealthSampleType, completion: @escaping ((HKSample?) -> Void)) {

        cloudantStore.collection(healthKitSampleType: sampleType).where("uuid", isEqualTo: uuid.uuidString).getSamples { result in
            switch result {
            case .success(let samples):
                guard let sample = samples.first else {
                    OTFLog("No data found... %{public}@", uuid.uuidString)
                    samples.forEach {
                        OTFLog("uuid... %{public}@", $0.uuid)
                    }
                    completion(nil)
                    return
                }

                switch sampleType {
                case .quantity:
                    if let quantitySample = sample as? HKQuantitySample {
                        completion(quantitySample)
                    }
                case .category:
                    if let categorySample = sample as? HKCategorySample {
                        completion(categorySample)
                    }
                default:
                    OTFLog("No supported OTFHealthSampleType found. returing from line 242", "")
                    completion(nil)
                }
            case .failure:
                completion(nil)
            }
        }
    }

    func cloudantSyncWithHealthKit(completion: ((HKQuantitySample?) -> Void)?) {
        let sampleType: OTFHealthSampleType = .quantity
        cloudantStore.collection(healthKitSampleType: sampleType).getCloudantSamples { (result) in
            switch result {
            case .success(let samples):
                for sample in samples {
                    OTFLog("typeIdentifier:- %{public}@", sample.typeIdentifier)
                    OTFLog("unit:- %{public}@", sample.unit)
                    
                }
                if let sample = samples.first, let hkSample = sample.toHKSample(), let quantitySample = hkSample as? HKQuantitySample {
                    OTFLog("Type - unit - Quantity - %{public}@", sample.typeIdentifier)
                    completion?(quantitySample)
                }
            case .failure:
                completion?(nil)
            }
        }
    }
}
#endif
