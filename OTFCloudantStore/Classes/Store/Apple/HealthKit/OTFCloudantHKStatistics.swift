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

#if HEALTH
import HealthKit
import OTFUtilities
/**
 An object that represents the result of calculating the minimum, maximum, average, or sum over a set of samples from the HealthKit store.
 */
public struct OTFCloudantHKStatistics: Codable {

    /// The quantity type of the samples used to calculate these statistics.
    public var quantityType: OTFCloudantHKQuantityType?

    /// The start of the time period included in these statistics.
    public var startDate: Date?

    /// The end of the time period included in these statistics.
    public var endDate: Date?

    /// An array containing all the sources contributing to these statistics.
    public var sources: [OTFCloudantHKSource]?

    /**
     - Description: Instantiates and returns a new HK statistics.
     - Parameter statistics: It requires a HKStatistics object as parameter.
     */
    public init(statistics: HKStatistics) {
        quantityType = OTFCloudantHKQuantityType(quantityType: statistics.quantityType)
        startDate = statistics.startDate
        endDate = statistics.endDate
        let temp = statistics.sources.map { $0.map { OTFCloudantHKSource(source: $0) } }
        sources = temp
    }

    /**
     - Description: Maps the data from the Cloudant's Statistics to HK's Statistics.
     - Returns: It will return a optional HKStatistics object, that could be nil also.
     */
    public func toHKStatistics() -> HKStatistics? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let statistics = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKStatistics.self, from: data)
            return statistics
        } catch {
            OTFError("Mapping from Cloudant's SeriesSample into HK's SeriesSample failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}
#endif
