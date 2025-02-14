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
import Foundation
import OTFCareKitStore

/**
 Extends OTFCloudantStore to perform actions on the care plans.
 */
extension OTFCloudantStore {
    
    /// Determines whether or not this store is intended to handle adding, updating, and deleting a certain care plan.
    /// - Parameter plan: The care plan that is about to be modified.
    /// - Note: `OTFStore` returns true for all care plans.
    open func shouldHandleCarePlan(_ plan: OCKAnyCarePlan) -> Bool { true }

    /// Determines whether or not this store is intended to handle fetching for a certain query.
    /// - Parameter query: The query that will be performed.
    /// - Note: `OTFStore` returns true for all cases.
    open func shouldHandleCarePlanQuery(query: OCKCarePlanQuery) -> Bool { true }

    /**
      Fetches care plans from the store.
     
      - Parameter query: a query that limits which care plan your function returns.
      - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
      - Parameter completion: a callback that fires on a background thread.
     */
    open func fetchCarePlans(query: OCKCarePlanQuery = OCKCarePlanQuery(),
                             callbackQueue: DispatchQueue = .main,
                             completion: @escaping (Result<[OCKCarePlan], OCKStoreError>) -> Void) {
        let cloudantQuery = OTFCloudantCarePlanQuery(carePlanQuery: query)
        fetch(cloudantQuery: cloudantQuery, callbackQueue: callbackQueue, completion: { (result: Result<[OCKCarePlan], OCKStoreError>) in
            switch result {
            case .success(let careplans):
                var tempResult = careplans
                for sortDescriptor in query.sortDescriptors {
                    switch sortDescriptor {
                    case .title(let ascending):
                        tempResult = tempResult.sorted { ascending ? $0.title > $1.title : $0.title < $1.title }
                    case .effectiveDate(ascending: let asc):
                        tempResult = tempResult.sorted { asc ? $0.effectiveDate > $1.effectiveDate : $0.effectiveDate < $1.effectiveDate }
                    }
                }
                completion(.success(tempResult))
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }

    /**
     Adds the care plan asynchronously to the store.
     
     - Parameter plans: the care plan you add to the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func addCarePlans(_ plans: [OCKCarePlan], callbackQueue: DispatchQueue = .main,
                           completion: ((Result<[OCKCarePlan], OCKStoreError>) -> Void)? = nil) {
        add(plans, callbackQueue: callbackQueue, completion: { result in
            switch result {
            case .success(let plans):
                self.carePlanDelegate?.carePlanStore(self,
                                                 didAddCarePlans: plans)
                completion?(.success(plans))
            case .failure:
                completion?(result.mapError{ $0.toOCKStoreError() })
            }
        })
    }

    /**
     Update the care plan asynchronously in the store.
     
     - Parameter plans: the care plan you update in the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func updateCarePlans(_ plans: [OCKCarePlan], callbackQueue: DispatchQueue = .main,
                              completion: ((Result<[OCKCarePlan], OCKStoreError>) -> Void)? = nil) {
        update(plans, callbackQueue: callbackQueue) { result in
            switch result {
            case .success(let plans):
                callbackQueue.async {
                    self.carePlanDelegate?.carePlanStore(self,
                                                       didUpdateCarePlans: plans)
                    completion?(.success(plans))
                }
            case .failure:
                completion?(result.mapError{ $0.toOCKStoreError() })
            }
        }
    }

    /**
     Deletes the care plan asynchronously from the store.
     
     - Parameter plans: the care plan you delete from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func deleteCarePlans(_ plans: [OCKCarePlan], callbackQueue: DispatchQueue = .main,
                              completion: ((Result<[OCKCarePlan], OCKStoreError>) -> Void)? = nil) {
        delete(plans, callbackQueue: callbackQueue) { result in
            switch result {
            case .success(let plans):
                callbackQueue.async {
                    self.carePlanDelegate?.carePlanStore(self, didDeleteCarePlans: plans)
                    completion?(.success(plans))
                }
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }
    
}
#endif
