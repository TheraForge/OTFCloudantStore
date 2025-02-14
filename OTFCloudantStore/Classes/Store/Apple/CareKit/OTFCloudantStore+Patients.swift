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
 Extends OTFCloudantStore to perform actions on the patient.
 */
extension OTFCloudantStore {
    
    /**
      Fetches patients from the store.
     
      - Parameter query: a query that limits which patients the store returns, when you are fetching.
      - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
      - Parameter completion: a callback that fires on a background thread.
     */
    open func fetchPatients(query: OCKPatientQuery = OCKPatientQuery(),
                            callbackQueue: DispatchQueue = .main,
                            completion: @escaping (Result<[OCKPatient], OCKStoreError>) -> Void) {
        let newQuery = OTFCloudantPatientQuery(patientQuery: query)
        fetch(cloudantQuery: newQuery, callbackQueue: callbackQueue, completion: { (result: Result<[OCKPatient], OCKStoreError>) in
            switch result {
            case .success(let patients):
                var tempResult = patients
                for sortDescriptor in query.sortDescriptors {
                    switch sortDescriptor {
                    case .familyName(let ascending):
                        tempResult = tempResult.sorted { ascending ? $0.name.familyName ?? "" < $1.name.familyName ?? "" : $0.name.familyName ?? "" > $1.name.familyName ?? ""}
                    case .givenName(let ascending):
                        tempResult = tempResult.sorted { ascending ? $0.name.givenName ?? "" < $1.name.familyName ?? "" : $0.name.givenName ?? "" > $1.name.givenName ?? ""}
                    case .effectiveDate(ascending: let asc):
                        tempResult = tempResult.sorted {
                            asc ? $0.effectiveDate < $1.effectiveDate : $0.effectiveDate > $1.effectiveDate
                        }
                    case .groupIdentifier(ascending: let asc):
                        tempResult = tempResult.sorted {
                            asc ? $0.groupIdentifier ?? "" < $1.groupIdentifier ?? "" : $0.groupIdentifier ?? "" > $1.groupIdentifier ?? ""
                        }
                    }
                }
                completion(.success(tempResult))
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }

    /**
     Adds the patient asynchronously to the store.
     
     - Parameter patients: the patients you add to the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func addPatients(_ patients: [OCKPatient],
                          callbackQueue: DispatchQueue = .main,
                          completion: ((Result<[OCKPatient], OCKStoreError>) -> Void)? = nil) {
        add(patients, callbackQueue: callbackQueue, completion: { result in
            switch result {
            case .success(let patients):
            self.patientDelegate?.patientStore(self,
                                               didAddPatients: patients)
                completion?(.success(patients))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        })
    }

    /**
     Updates the patient asynchronously in the store.
     
     - Parameter patients: the patients you update in the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func updatePatients(_ patients: [OCKPatient],
                             callbackQueue: DispatchQueue = .main,
                             completion: ((Result<[OCKPatient], OCKStoreError>) -> Void)? = nil) {
        update(patients, callbackQueue: .main) { result in
            switch result {
            case .success(let patients):
                self.patientDelegate?.patientStore(self,
                                                   didUpdatePatients: patients)
                completion?(.success(patients))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }

    /**
     Deletes the patient asynchronously from the store.
     
     - Parameter patients: the patients you delete from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func deletePatients(_ patients: [OCKPatient],
                             callbackQueue: DispatchQueue = .main,
                             completion: ((Result<[OCKPatient], OCKStoreError>) -> Void)? = nil) {
        delete(patients, callbackQueue: callbackQueue) { result in
            switch result {
            case .success(let patients):
                self.patientDelegate?.patientStore(self, didDeletePatients: patients)
                completion?(.success(patients))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }
    
}
#endif
