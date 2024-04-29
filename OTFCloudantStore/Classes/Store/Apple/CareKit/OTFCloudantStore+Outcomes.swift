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
import Foundation
import OTFCareKitStore

/**
 Extends OTFCloudantStore to perform actions on the result of an event.
 */
extension OTFCloudantStore {

    /**
      Fetches outcomes from the store.
     
     - Parameter query: a query that limits which outcomes the store returns, when you are fetching.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func fetchOutcomes(query: OCKOutcomeQuery = OCKOutcomeQuery(), callbackQueue: DispatchQueue = .main,
                            completion: @escaping (Result<[OCKOutcome], OCKStoreError>) -> Void) {
        let newQuery = OTFCloudantOutcomeQuery(outcomeQuery: query)
        fetch(cloudantQuery: newQuery, callbackQueue: callbackQueue, filter: { outcome -> Bool in
            guard let interval = query.dateInterval, let createdAt = outcome.createdDate else {
                return true
            }

            let includeOutcome = interval.contains(createdAt)
            return includeOutcome
        }, completion: completion)
    }

    /**
     Adds the outcomes asynchronously to the store.
     
     - Parameter outcomes: the outcomes you add to the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func addOutcomes(_ outcomes: [OCKOutcome], callbackQueue: DispatchQueue = .main,
                          completion: ((Result<[OCKOutcome], OCKStoreError>) -> Void)? = nil) {
        add(outcomes, callbackQueue: callbackQueue, completion: { result in
            switch result {
            case .success(let outcomes):
                self.outcomeDelegate?.outcomeStore(self,
                                               didAddOutcomes: outcomes)
                completion?(.success(outcomes))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        })
    }

    /**
     Updates the outcomes asynchronously in the store.
     
     - Parameter outcomes: the outcomes you update in the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func updateOutcomes(_ outcomes: [OCKOutcome], callbackQueue: DispatchQueue = .main,
                             completion: ((Result<[OCKOutcome], OCKStoreError>) -> Void)? = nil) {
        update(outcomes, callbackQueue: .main) { result in
            switch result {
            case .success(let outcomes):
                self.outcomeDelegate?.outcomeStore(self,
                                                   didUpdateOutcomes: outcomes)
                completion?(.success(outcomes))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }

    /**
     Deletes the outcomes asynchronously from the store.
     
     - Parameter outcomes: the outcomes you delete from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func deleteOutcomes(_ outcomes: [OCKOutcome], callbackQueue: DispatchQueue = .main,
                             completion: ((Result<[OCKOutcome], OCKStoreError>) -> Void)? = nil) {
        delete(outcomes, callbackQueue: callbackQueue) { result in
            switch result {
            case .success(let outcomes):
                self.outcomeDelegate?.outcomeStore(self, didDeleteOutcomes: outcomes)
                completion?(.success(outcomes))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }

}
#endif
