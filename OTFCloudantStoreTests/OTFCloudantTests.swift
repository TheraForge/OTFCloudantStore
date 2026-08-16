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
import XCTest
import OTFCloudantStore
import HealthKit
import OTFUtilities

class OTFCloudantTests: XCTestCase {
    #if HEALTH
    private static let integrationEnvironmentKey = "OTFCLOUDANTSTORE_RUN_HEALTHKIT_INTEGRATION_TESTS"

    private static var shouldRunHealthKitIntegrationTests: Bool {
        ProcessInfo.processInfo.environment[integrationEnvironmentKey] == "1"
    }

    var healthStore: HKHealthStore!
    let stepCountsValue: Double = 20
    private(set) var storeName: String!
    var cloudantStore: OTFCloudantStore!
    var synchronizer: OTFHealthKitSynchronizer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(
            Self.shouldRunHealthKitIntegrationTests,
            "Set \(Self.integrationEnvironmentKey)=1 to run HealthKit integration tests."
        )

        healthStore = HKHealthStore()
        storeName = Self.uniqueStoreName()
        cloudantStore = try OTFCloudantStore(storeName: storeName)
        synchronizer = OTFHealthKitSynchronizer(dataStore: cloudantStore, healthStore: healthStore)

        let expectat = expectation(description: "Wait for authorization. Need to do manual authorize on first launch.")

        deleteOldData {
            expectat.fulfill()
        }

        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    override func tearDownWithError() throws {
        if let cloudantStore, let storeName {
            try? cloudantStore.datastoreManager.deleteDatastoreNamed(storeName)
        }
        synchronizer = nil
        cloudantStore = nil
        healthStore = nil
        storeName = nil
        try super.tearDownWithError()
    }

    private static func uniqueStoreName() -> String {
        let suffix = UUID().uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return "healthkit_integration_\(suffix)"
    }

    func deleteOldData(completion: @escaping ( () -> Void)) {

        let sampleTypes: [OTFHealthSampleType] = [.quantity, .category, .correlation]
        let group = DispatchGroup()

        for type in sampleTypes {
            group.enter()
            OTFLogger.logger().info("Deleting old data for \(String(describing: type), privacy: .public)")
            cloudantStore.collection(healthKitSampleType: type).getSamples { result in
                switch result {
                case .success(let samples):
                    self.cloudantStore.deleteSamples(samples: samples)
                    self.healthStore.delete(samples) { _, _ in
                        OTFLogger.logger().info("Old data deleted successfully: \(String(describing: samples), privacy: .public)")
                        group.leave()
                    }
                case .failure:
                    OTFLogger.logger().error("No data found")
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
                    OTFLogger.logger().info("No data found for uuid: \(uuid.uuidString, privacy: .public)")
                    samples.forEach {
                        OTFLogger.logger().info("Found sample uuid: \($0.uuid.uuidString, privacy: .public)")
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
                    OTFLogger.logger().info("No supported OTFHealthSampleType found")
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
                    OTFLogger.logger().info("typeIdentifier: \(sample.typeIdentifier, privacy: .public)")
                    OTFLogger.logger().info("unit: \(sample.unit, privacy: .public)")
                    
                }
                if let sample = samples.first, let hkSample = sample.toHKSample(), let quantitySample = hkSample as? HKQuantitySample {
                    OTFLogger.logger().info("Type - unit - quantity: \(sample.typeIdentifier, privacy: .public)")
                    completion?(quantitySample)
                }
            case .failure:
                completion?(nil)
            }
        }
    }
}
#endif
