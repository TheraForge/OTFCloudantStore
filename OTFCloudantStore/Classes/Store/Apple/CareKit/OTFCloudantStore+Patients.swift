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

  /// Extends OTFCloudantStore to perform actions on the patient.
  extension OTFCloudantStore {

    /**
      Fetches patients from the store.

      - Parameter query: a query that limits which patients the store returns, when you are fetching.
      - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
      - Parameter completion: a callback that fires on a background thread.
     */
    public func fetchPatients(
      query: OCKPatientQuery = OCKPatientQuery(),
      callbackQueue: DispatchQueue = .main,
      completion: @escaping (Result<[OCKPatient], OCKStoreError>) -> Void
    ) {
      let newQuery = OTFCloudantPatientQuery(patientQuery: query)
      let sortsLocally = !query.sortDescriptors.isEmpty
      if sortsLocally {
        newQuery.limit = nil
        newQuery.offset = 0
      }
      fetch(
        cloudantQuery: newQuery, callbackQueue: callbackQueue,
        completion: { (result: Result<[OCKPatient], OCKStoreError>) in
          switch result {
          case .success(let patients):
            let tempResult = self.sortPatients(patients, using: query.sortDescriptors)
            completion(.success(sortsLocally ? self.paginate(tempResult, offset: query.offset, limit: query.limit) : tempResult))
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
    public func addPatients(
      _ patients: [OCKPatient],
      callbackQueue: DispatchQueue = .main,
      completion: ((Result<[OCKPatient], OCKStoreError>) -> Void)? = nil
    ) {
      add(
        patients, callbackQueue: callbackQueue,
        completion: { result in
          switch result {
          case .success(let patients):
            self.patientDelegate?.patientStore(
              self,
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
    public func updatePatients(
      _ patients: [OCKPatient],
      callbackQueue: DispatchQueue = .main,
      completion: ((Result<[OCKPatient], OCKStoreError>) -> Void)? = nil
    ) {
      update(patients, callbackQueue: callbackQueue) { result in
        switch result {
        case .success(let patients):
          self.patientDelegate?.patientStore(
            self,
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
    public func deletePatients(
      _ patients: [OCKPatient],
      callbackQueue: DispatchQueue = .main,
      completion: ((Result<[OCKPatient], OCKStoreError>) -> Void)? = nil
    ) {
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

    private func sortPatients(
      _ patients: [OCKPatient],
      using sortDescriptors: [OCKPatientQuery.SortDescriptor]
    ) -> [OCKPatient] {
      guard !sortDescriptors.isEmpty else {
        return patients
      }

      return patients.enumerated().sorted { lhs, rhs in
        for sortDescriptor in sortDescriptors {
          switch sortDescriptor {
          case .familyName(let ascending):
            let lhsValue = lhs.element.name.familyName ?? ""
            let rhsValue = rhs.element.name.familyName ?? ""
            if lhsValue != rhsValue {
              return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
            }
          case .givenName(let ascending):
            let lhsValue = lhs.element.name.givenName ?? ""
            let rhsValue = rhs.element.name.givenName ?? ""
            if lhsValue != rhsValue {
              return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
            }
          case .effectiveDate(ascending: let ascending):
            if lhs.element.effectiveDate != rhs.element.effectiveDate {
              return ascending
                ? lhs.element.effectiveDate < rhs.element.effectiveDate
                : lhs.element.effectiveDate > rhs.element.effectiveDate
            }
          case .groupIdentifier(ascending: let ascending):
            let lhsValue = lhs.element.groupIdentifier ?? ""
            let rhsValue = rhs.element.groupIdentifier ?? ""
            if lhsValue != rhsValue {
              return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
            }
          }
        }
        return lhs.offset < rhs.offset
      }.map { $0.element }
    }

    private func paginate<Entity>(_ items: [Entity], offset: Int, limit: Int?) -> [Entity] {
      let startIndex = min(max(offset, 0), items.count)
      let remainingItems = items.dropFirst(startIndex)
      guard let limit = limit else {
        return Array(remainingItems)
      }
      return Array(remainingItems.prefix(max(limit, 0)))
    }

  }
#endif
