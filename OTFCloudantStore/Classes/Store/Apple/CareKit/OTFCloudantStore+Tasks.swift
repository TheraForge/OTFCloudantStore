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

extension OCKTask: Identifiable {
    public var id: String {
        return uuid.uuidString
    }
}

/**
 Extends OTFCloudantStore to perform actions on the tasks.
 */

extension OTFCloudantStore {

    /**
      Fetches tasks from the store.
     
     - Parameter query: a query that limits which tasks your fetch returns.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func fetchTasks(query: OCKTaskQuery = OCKTaskQuery(), callbackQueue: DispatchQueue = .main,completion: @escaping (Result<[OCKTask], OCKStoreError>) -> Void) {
        let cloudantQuery = OTFCloudantTaskQuery(taskQuery: query)
        fetch(cloudantQuery: cloudantQuery, callbackQueue: callbackQueue, completion: completion)
    }

    /**
      This method adds, upadates or deletes a task from the store.
     
     - Parameter addOrUpdate: a tasks you add or update to the store.
     - Parameter delete: a tasks you delete from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func addUpdateOrDeleteTasks(addOrUpdate tasks: [OCKTask],
                                       delete deleteTasks: [OCKTask],
                                       callbackQueue: DispatchQueue,
                                       completion: ((Result<([OCKTask], [OCKTask], [OCKTask]), OCKStoreError>) -> Void)?) {
        self.fetchTasks { (result: Result<[OCKTask], OCKStoreError>) in
            switch result {
            case .success(let existingTasks):
                let existingTaskIDs = existingTasks.map { $0.id }
                let tasksToBeAdded = tasks.filter { !existingTaskIDs.contains($0.id) }
                let tasksToBeUpdated = tasks.filter { existingTaskIDs.contains($0.id) }

                var errors = [OCKStoreError]()
                var addedTasks = [OCKTask]()
                var updatedTasks = [OCKTask]()
                var deletedTasks = [OCKTask]()

                let group = DispatchGroup()

                if !tasksToBeAdded.isEmpty {
                    group.enter()
                    self.addTasks(tasksToBeAdded, callbackQueue: callbackQueue) { (result: Result<[OCKTask], OCKStoreError>) in
                        switch result {
                        case .success(let array):
                            addedTasks = array
                        case .failure(let error):
                            errors.append(error)
                        }
                        group.leave()
                    }
                }
                if !tasksToBeUpdated.isEmpty {
                    group.enter()
                    self.updateTasks(tasksToBeUpdated, callbackQueue: callbackQueue) { (result: Result<[OCKTask], OCKStoreError>) in
                        switch result {
                        case .success(let array):
                            updatedTasks = array
                        case .failure(let error):
                            errors.append(error)
                        }
                        group.leave()
                    }
                }
                if !deleteTasks.isEmpty {
                    group.enter()
                    self.deleteTasks(deleteTasks, callbackQueue: callbackQueue) { (result: Result<[OCKTask], OCKStoreError>) in
                        switch result {
                        case .success(let array):
                            deletedTasks = array
                        case .failure(let error):
                            errors.append(error)
                        }
                        group.leave()
                    }
                }

                group.notify(queue: callbackQueue) {
                    if addedTasks.isEmpty && updatedTasks.isEmpty && deletedTasks.isEmpty && !errors.isEmpty {
                        completion?(.failure(errors[0]))
                    } else {
                        completion?(.success((addedTasks, updatedTasks, deletedTasks)))
                    }
                }

            case .failure(let error):
                completion?(.failure(error))
            }
        }

    }

    /**
     Adds a task asynchronously to the store.
     
     - Parameter tasks: a task you add to the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func addTasks(_ tasks: [OCKTask], callbackQueue: DispatchQueue = .main,
                         completion: ((Result<[OCKTask], OCKStoreError>) -> Void)? = nil) {
        add(tasks, callbackQueue: callbackQueue, completion: { result in
            switch result {
            case .success(let tasks):
                self.taskDelegate?.taskStore(self,
                                             didUpdateTasks: tasks)
                completion?(.success(tasks))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        })
    }

    /**
     Updates a task asynchronously to the store.
     
     - Parameter tasks: a task you update from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func updateTasks(_ tasks: [OCKTask], callbackQueue: DispatchQueue = .main,
                            completion: ((Result<[OCKTask], OCKStoreError>) -> Void)? = nil) {
        update(tasks, callbackQueue: .main) { result in
            switch result {
            case .success(let tasks):
                self.taskDelegate?.taskStore(self,
                                             didUpdateTasks: tasks)
                completion?(.success(tasks))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }

    /**
     Deletes a task asynchronously from the store.
     
     - Parameter tasks: a task you delete from the store.
     - Parameter callbackQueue: the queue on which your app calls the completion closure. In most cases this will be the main queue.
     - Parameter completion: a callback that fires on a background thread.
     */
    public func deleteTasks(_ tasks: [OCKTask], callbackQueue: DispatchQueue = .main,
                            completion: ((Result<[OCKTask], OCKStoreError>) -> Void)? = nil) {
        delete(tasks, callbackQueue: callbackQueue) { result in
            switch result {
            case .success(let tasks):
                self.taskDelegate?.taskStore(self, didDeleteTasks: tasks)
                completion?(.success(tasks))
            case .failure:
                completion?(result.mapError { $0.toOCKStoreError() })
            }
        }
    }

}

/**
 Extends OTFCloudantError to return the errors when there is problem during a transaction.
 */
extension OTFCloudantError {

    /**
     - Description: Return the errors the store emits when there is problem during a transaction.
     - Returns: It will return an OCKStoreError object
     */
    func toOCKStoreError() -> OCKStoreError {
        switch self {
        case .addFailed(let reason):
            return .addFailed(reason: reason)
        case .deleteFailed(let reason):
            return .deleteFailed(reason: reason)
        case .fetchFailed(let reason):
            return .fetchFailed(reason: reason)
        case .invalidValue(let reason):
            return .invalidValue(reason: reason)
        case .remoteSynchronizationFailed(let reason):
            return .remoteSynchronizationFailed(reason: reason)
        case .timedOut(let reason):
            return .timedOut(reason: reason)
        case .updateFailed(let reason):
            return .updateFailed(reason: reason)
        }
    }

}
#endif
