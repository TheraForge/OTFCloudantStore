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

#if CARE
import OTFCareKitStore
#endif

let revisionIDKey = "revId"

public protocol OTFCloudantRevision {
    var revId: String? { get set }
}

#if CARE
extension OCKContact: OTFCloudantRevision {
    public var revId: String? {
        get {
            return userInfo?[revisionIDKey]
        }
        set {
            if userInfo == nil {
                userInfo = [String: String]()
            }
            userInfo?[revisionIDKey] = newValue
        }
    }

    static let typeKey = "type"
    public var type: String? {
        get {
            return userInfo?[OCKContact.typeKey]
        }
        set {
            if userInfo == nil {
                userInfo = [String: String]()
            }
            userInfo?[OCKContact.typeKey] = newValue
        }
    }

    public func displayName() -> String? {
        let nameFormatter = PersonNameComponentsFormatter()
        nameFormatter.style = .long
        return nameFormatter.string(from: name)
    }
}

extension OCKTask: OTFCloudantRevision {
    public var revId: String? {
        get {
            return userInfo?[revisionIDKey]
        }
        set {
            if userInfo == nil {
                userInfo = [String: String]()
            }
            userInfo?[revisionIDKey] = newValue
        }
    }
}

extension OCKPatient: OTFCloudantRevision {
    public var revId: String? {
        get {
            return userInfo?[revisionIDKey]
        }
        set {
            if userInfo == nil {
                userInfo = [String: String]()
            }
            userInfo?[revisionIDKey] = newValue
        }
    }
}

extension OCKOutcome: OTFCloudantRevision {
    public var revId: String? {
        get {
            return userInfo?[revisionIDKey]
        }
        set {
            if userInfo == nil {
                userInfo = [String: String]()
            }
            userInfo?[revisionIDKey] = newValue
        }
    }
}

extension OCKCarePlan: OTFCloudantRevision {
    public var revId: String? {
        get {
            return userInfo?[revisionIDKey]
        }
        set {
            if userInfo == nil {
                userInfo = [String: String]()
            }
            userInfo?[revisionIDKey] = newValue
        }
    }
}
#endif
