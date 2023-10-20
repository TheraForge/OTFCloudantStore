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

import Foundation
import OTFCDTDatastore
#if CARE
import OTFCareKitStore
#endif

extension Encodable {
    func toDictionary() -> [String: Any] {
        do {
            let enCoder = CloudantEncoder()
            let dic = try enCoder.encode(self) as [String: Any]
            return dic
        } catch {
            fatalError()
        }
    }
}

#if CARE
public extension CDTDocumentRevision {
    static func encodedDictionary<Entity: Encodable & Identifiable>(fromEntity item: Entity) -> [String: Any] where Entity.ID == String {
        var dic = item.toDictionary()
        dic["entityType"] = "\(Entity.self)"
        var additionalInfoDict = [String: Any]()
        let additionalInfo = OTFAdditionalInfo(id: item.id)
        additionalInfoDict = additionalInfo.toDictionary()
        if var newDict = dic.copyValue(from: additionalInfoDict) {
            if let outcome = item as? OCKOutcome {
                if !outcome.values.isEmpty {
                    newDict["values"] = outcome.values.map { $0.updatedDictionary() }
                }
            }
            return newDict
        }
        return dic
    }

    static func revision<Entity: Encodable & Identifiable & OTFCloudantRevision>(fromEntity item: Entity) -> CDTDocumentRevision where Entity.ID == String {
        let dic = CDTDocumentRevision.encodedDictionary(fromEntity: item)
        let revision = dic.toDocumentRevision(revId: item.revId)
        revision.body = NSMutableDictionary(dictionary: dic)
        return revision
    }
}
#endif

// this class is used to fill info of OTFObjectCompatible into the model if they're missing
public protocol OTFObjectCompatibleInfo: Codable {
    var id: String? { get set }
    /// A universally unique identifer for this object.
    var uuid: UUID? { get set }

    /// The date at which the object was first persisted to the database.
    /// It will be nil for unpersisted values and objects.
    var createdDate: Date? { get set }

    /// The last date at which the object was updated.
    /// It will be nil for unpersisted values and objects.
    var updatedDate: Date? { get set }
}

private struct OTFAdditionalInfo: OTFObjectCompatibleInfo {
    var id: String?

    var uuid: UUID?

    var createdDate: Date?

    var updatedDate: Date?

    var type: String?

    init(id: String?) {
        self.id = id
        uuid = UUID()
        createdDate = Date()
        updatedDate = Date()
    }
}

#if CARE
private struct OTFOutcomeCompatibleInfo: OTFObjectCompatibleInfo {
    var id: String?
    var uuid: UUID?
    var createdDate: Date?
    var updatedDate: Date?

    init(outcome: OCKOutcome) {
        self.id = outcome.id
        self.uuid = outcome.uuid
        self.createdDate = outcome.createdDate ?? Date()
        self.updatedDate = outcome.updatedDate ?? Date()
    }
}

extension OCKOutcomeValue {
    func updatedDictionary() -> [String: Any] {
        let dict = toDictionary()
        let additionalInfo = OTFAdditionalInfo(id: nil)
        if let copiedDict = dict.copyValue(from: additionalInfo.toDictionary()) {
            return copiedDict
        }
        return dict
    }
}
#endif

extension Dictionary {
    func copyValue(from dict: [String: Any]) -> [String: Any]? {
        if var newDic = self as? [String: Any] {
            for (key, value) in dict {
                if newDic[key] == nil || newDic[key] is NSNull {
                    newDic[key] = value
                }
            }
            return newDic
        }
        return nil
    }
}
