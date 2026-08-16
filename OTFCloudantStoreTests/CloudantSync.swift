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
import OTFCloudantStore
import OTFCDTDatastore
import OTFCloudClientAPI
import OTFUtilities

class CloudantSync: NSObject {
    static let shared = CloudantSync()
    override private init() {}

    enum Environment: String {
        case theraforge
    }

    struct Configuration {
        let targetURL: URL
        let username: String
        let password: String
        let apiKey: String
    }

    enum ConfigurationError: LocalizedError {
        case missingEnvironmentValue(String)
        case invalidURL(String)

        var errorDescription: String? {
            switch self {
            case .missingEnvironmentValue(let name):
                return "Missing required environment value: \(name)"
            case .invalidURL(let value):
                return "Invalid OTFCLOUDANT_SYNC_TARGET_URL: \(value)"
            }
        }
    }

    enum ReplicationDirection: String {
        case push, pull
    }

    enum DBEndPoints {
        case local
        case bulkDoc
        case revsDiff
        case bulkGet
    }

    private func configuration(environment: Environment) throws -> Configuration {
        switch environment {
        case .theraforge:
            let targetURL = try requiredEnvironmentValue("OTFCLOUDANT_SYNC_TARGET_URL")
            let username = try requiredEnvironmentValue("OTFCLOUDANT_SYNC_USERNAME")
            let password = try requiredEnvironmentValue("OTFCLOUDANT_SYNC_PASSWORD")
            let apiKey = try requiredEnvironmentValue("OTFCLOUDANT_SYNC_API_KEY")

            guard let remote = URL(string: targetURL) else {
                throw ConfigurationError.invalidURL(targetURL)
            }

            return Configuration(targetURL: remote,
                                 username: username,
                                 password: password,
                                 apiKey: apiKey)
        }
    }

    private func requiredEnvironmentValue(_ name: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
            throw ConfigurationError.missingEnvironmentValue(name)
        }

        return value
    }

    func replicate(direction: ReplicationDirection, environment: Environment, completionBlock: ((Error?) -> Void)? = nil) throws {

        let store = try StoreService.shared.currentStore(peer: OTFWatchConnectivityPeer())
        let datastoreManager = store.datastoreManager
        let factory = CDTReplicatorFactory(datastoreManager: datastoreManager)

        let configuration = try self.configuration(environment: environment)

        let replication: CDTAbstractReplication
        switch direction {
        case .push:
            replication = CDTPushReplication(source: store.dataStore,
                                             target: configuration.targetURL,
                                             username: configuration.username,
                                             password: configuration.password)
        case .pull:
            replication = CDTPullReplication(source: configuration.targetURL,
                                             target: store.dataStore,
                                             username: configuration.username,
                                             password: configuration.password)
        }

        switch environment {
        case .theraforge:
            replication.add(TheraForgeHTTPInterceptor(apiKey: configuration.apiKey))
        default:
            break
        }

        let replicator = try factory.oneWay(replication)
        let dataStore = store.dataStore
        
        switch environment {
        case .theraforge:
            replicator.sessionConfigDelegate = TheraForgeNetwork.shared
            dataStore.sessionConfigDelegate = TheraForgeNetwork.shared
        default:
            break
        }

        switch direction {
        case .push:
            dataStore.push(to: configuration.targetURL, replicator: replicator, username: configuration.username, password: configuration.password) { (error: Error?) in
                if let error = error {
                    OTFLogger.logger().error("Push failed: \(error.localizedDescription, privacy: .public)")
                    completionBlock?(error)
                } else {
                    OTFLogger.logger().info("Push succeeded")
                    completionBlock?(nil)
                }
            }
        case .pull:
            dataStore.pull(from: configuration.targetURL, replicator: replicator, username: configuration.username, password: configuration.password) { error in
                if let error {
                    OTFLogger.logger().error("Pull failed: \(error.localizedDescription, privacy: .public)")
                }
                completionBlock?(error)
            }
        }
    }

    func dbProxy(endPoint: DBEndPoints, direction: ReplicationDirection, environment: Environment, requestBody: [AnyHashable: Any]? = nil, completionHandler: @escaping ((Any?, Error?) -> Void)) throws {
        let store = try StoreService.shared.currentStore(peer: OTFWatchConnectivityPeer())
        let datastoreManager = store.datastoreManager
        let factory = CDTReplicatorFactory(datastoreManager: datastoreManager)

        let configuration = try self.configuration(environment: environment)
        let replication: CDTAbstractReplication
        switch direction {
        case .push:
            replication = CDTPushReplication(source: store.dataStore,
                                             target: configuration.targetURL,
                                             username: configuration.username,
                                             password: configuration.password)
        case .pull:
            replication = CDTPullReplication(source: configuration.targetURL,
                                             target: store.dataStore,
                                             username: configuration.username,
                                             password: configuration.password)
        }

        switch environment {
        case .theraforge:
            replication.add(TheraForgeHTTPInterceptor(apiKey: configuration.apiKey))
        default:
            break
        }

        let replicator = try factory.oneWay(replication)

        switch environment {
        case .theraforge:
            replicator.sessionConfigDelegate = TheraForgeNetwork.shared
        default:
            break
        }

        switch  endPoint {
        case .local: replicator.testEndPointLocal(completionHandler)
        case .revsDiff: replicator.testRevsDiff(completionHandler)
        case .bulkDoc: replicator.testUploadBulkDocs(completionHandler)
        case .bulkGet: replicator.testBulkGet(requestBody, handler: completionHandler)
        }
    }
}

class TheraForgeHTTPInterceptor: NSObject, CDTHTTPInterceptor {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    func interceptRequest(in context: CDTHTTPInterceptorContext) -> CDTHTTPInterceptorContext? {
        if let currentAuth = TheraForgeNetwork.shared.currentAuth {
            context.request.setValue("\(TheraForgeNetwork.shared.identifierForVendor)", forHTTPHeaderField: "Client")
            context.request.setValue("Bearer \(currentAuth.token)", forHTTPHeaderField: "Authorization")
            context.request.addValue(apiKey, forHTTPHeaderField: "API-KEY")
        }
        return context
    }

    func interceptResponse(in context: CDTHTTPInterceptorContext) -> CDTHTTPInterceptorContext? {
        NSLog("TheraForgeHTTPInterceptor: \n\n\((context.request as URLRequest).cURL)")
        NSLog("TheraForgeHTTPInterceptor: \n\n\(context.request)\n\n\(context.response!)\n\ndata: \(String(data: context.responseData!, encoding: .utf8)!)")
        return context
    }

}
