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
import SwiftUI

struct CloudantStoreKey: EnvironmentKey {
    typealias Value = OTFCloudantStore?

    private enum DefaultValueCache {
        case unresolved
        case resolved(OTFCloudantStore?)
    }

    private static let defaultValueLock = NSLock()
    private static var defaultValueCache = DefaultValueCache.unresolved

    static var defaultValueProvider: () -> OTFCloudantStore? = productionDefaultValue {
        didSet {
            resetDefaultValueCache()
        }
    }

    static var defaultValue: OTFCloudantStore? {
        defaultValueLock.lock()
        defer { defaultValueLock.unlock() }

        switch defaultValueCache {
        case .resolved(let store):
            return store
        case .unresolved:
            let store = defaultValueProvider()
            defaultValueCache = .resolved(store)
            return store
        }
    }

    static func resetDefaultValueProvider() {
        defaultValueProvider = productionDefaultValue
    }

    private static func resetDefaultValueCache() {
        defaultValueLock.lock()
        defaultValueCache = .unresolved
        defaultValueLock.unlock()
    }

    private static func productionDefaultValue() -> OTFCloudantStore? {
        do {
            let store = try StoreService.shared.currentStore(peer: OTFWatchConnectivityPeer())
            return store
        } catch {
            return nil
        }
    }
}

extension EnvironmentValues {
    var store: OTFCloudantStore? {
        get { self[CloudantStoreKey.self] }
        set { self[CloudantStoreKey.self] = newValue }
    }
}
