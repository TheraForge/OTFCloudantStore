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
import OTFCDTDatastore
import OTFCareKitStore

/**
 Extends OTFCloudantStore to perform actions on the contacts.
 */
extension OTFCloudantStore {

    /**
      Fetches contacts from the store.
     
      - Parameter query: a query that limits which contact your fetch returns.
      - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
      - Parameter completion: a callback that fires on a background thread.
    */
    open func fetchContacts(query: OCKContactQuery = OCKContactQuery(),
                            callbackQueue: DispatchQueue = .main,
                            completion: @escaping (Result<[OCKContact], OCKStoreError>) -> Void) {
        let newQuery = OTFCloudantContactQuery(contactQuery: query)
        fetch(cloudantQuery: newQuery, callbackQueue: callbackQueue, completion: { (result: Result<[OCKContact], OCKStoreError>) in
            if query.sortDescriptors.isEmpty {
                completion(result)
            } else {
                switch result {
                case .success(let contacts):
                    var finalResult = contacts
                    for sortDescriptor in query.sortDescriptors {
                        switch sortDescriptor {
                        case .familyName(let ascending):
                            if ascending {
                                finalResult = finalResult.sorted { $0.name.familyName?.lowercased() ?? "" < $1.name.familyName?.lowercased() ?? "" }
                            } else {
                                finalResult = finalResult.sorted { $0.name.familyName?.lowercased() ?? "" > $1.name.familyName?.lowercased() ?? "" }
                            }
                        case .givenName(let ascending):
                            if ascending {
                                finalResult = finalResult.sorted { $0.name.givenName?.lowercased() ?? "" < $1.name.givenName?.lowercased() ?? "" }
                            } else {
                                finalResult = finalResult.sorted { $0.name.givenName?.lowercased() ?? "" > $1.name.givenName?.lowercased() ?? "" }
                            }
                        case .effectiveDate(ascending: let asc):
                            if asc {
                                finalResult = finalResult.sorted {
                                    $0.effectiveDate < $1.effectiveDate
                                }
                            } else {
                                finalResult = finalResult.sorted {
                                    $0.effectiveDate > $1.effectiveDate
                                }
                            }
                        }
                    }
                    completion(.success(finalResult))
                default:
                    completion(result)
                }
            }
        })
    }

    // swiftlint:disable trailing_closure
    /**
     Adds a contacts asynchronously to the store.
     
     - Parameter contacts: the contacts you add to the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func addContacts(_ contacts: [OCKContact],
                          callbackQueue: DispatchQueue = .main,
                          completion: ((Result<[OCKContact], OCKStoreError>) -> Void)? = nil) {
        add(contacts, callbackQueue: callbackQueue, completion: { result in
            switch result {
            case .success(let contacts):
                self.contactDelegate?.contactStore(self,
                                                   didAddContacts: contacts)
                completion?(.success(contacts))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        })
    }

    /**
     Updates the contacts asynchronously to the store.
     
     - Parameter contacts: the contacts you update to the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    open func updateContacts(_ contacts: [OCKContact],
                             callbackQueue: DispatchQueue = .main,
                             completion: OCKResultClosure<[OCKContact]>? = nil) {
        update(contacts, callbackQueue: .main) { result in
            switch result {
            case .success(let contacts):
                self.contactDelegate?.contactStore(self,
                                                   didUpdateContacts: contacts)
                completion?(.success(contacts))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }

    /**
     Deletes the contacts asynchronously from the store.
     
     - Parameter contacts: the contacts you delete from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     
     */
    open func deleteContacts(_ contacts: [OCKContact],
                             callbackQueue: DispatchQueue = .main,
                             completion: ((Result<[OCKContact], OCKStoreError>) -> Void)? = nil) {
        delete(contacts, callbackQueue: callbackQueue) { result in
            switch result {
            case .success(let plans):
                self.contactDelegate?.contactStore(self, didDeleteContacts: contacts)
                completion?(.success(plans))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }
}
#endif
