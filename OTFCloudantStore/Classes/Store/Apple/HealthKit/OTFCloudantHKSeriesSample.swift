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
 An abstract class that defines samples that contain a series of items.
 */
public struct OTFCloudantHKSeriesSample: OTFCloudantHKSampleProtocol {

    /// The unique identifier of the sample.
    public var id: String

    /// The UUID  of the sample.
    public var uuid: UUID?

    /// The revision identifier of the sample.
    public var revId: String?

    /// The sample type.
    public var sampleType: OTFCloudantHKSampleType?

    /// The sample’s start date.
    public var startDate: Date

    /// The sample’s end date.
    public var endDate: Date

    /// The number of items in the series.
    public var count: Int?

    /// The patient identifier for the sample.
    public var patientID: String

    /**
     - Description: Instantiates and returns a new sample for the given patient.
     - Parameter sample: This function requires a HKSeriesSample object as parameter in order to initialize.
     - Parameter patientId: This function requires a patientId of string type in order to initialize.
     */
    public init(sample: HKSeriesSample, patientId: String) {
        id = sample.uuid.uuidString
        uuid = sample.uuid
        count = sample.count
        sampleType = OTFCloudantHKSampleType(sampleType: sample.sampleType)
        startDate = sample.startDate
        endDate = sample.endDate
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's SeriesSample into HK's SeriesSample.
     - Returns: This function will return an optional HKSample object, that could be nil also.
     */
    public func toHKSample() -> HKSample? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let sample = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKSeriesSample.self, from: data)
            return sample
        } catch {
            OTFError("Mapping from Cloudant's SeriesSample into HK's SeriesSample failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}

/**
 A sample that represents a series of heartbeats.
 */
public struct OTFCloudantHKHeartbeatSeriesSample: OTFCloudantHKSampleProtocol {

    /// The unique identifier of the sample.
    public var id: String

    /// The UUID  of the sample.
    public var uuid: UUID?

    /// The revision identifier of the sample.
    public var revId: String?

    /// The sample type.
    public var sampleType: OTFCloudantHKSampleType?

    /// The sample’s start date.
    public var startDate: Date

    /// The sample’s end date.
    public var endDate: Date

    /// The number of items in the series.
    public var count: Int?

    /// The patient identifier for the sample.
    public var patientID: String

    /**
     - Description: Instantiates and returns a new  series of heartbeats for the given patient.
     - Parameter sample: This function requires a HKHeartbeatSeriesSample in order to initialize.
     - Parameter patientId: This function requires a patientId of string type in order to initialize.
     */
    public init(sample: HKHeartbeatSeriesSample, patientId: String) {
        id = sample.uuid.uuidString
        uuid = sample.uuid
        count = sample.count
        sampleType = OTFCloudantHKSampleType(sampleType: sample.sampleType)
        startDate = sample.startDate
        endDate = sample.endDate
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's HeartbeatSeriesSample into HK's HeartbeatSeriesSample.
     - Returns: This function will return an optional HKSample object, That could be nil also.
     */
    public func toHKSample() -> HKSample? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let sample = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKHeartbeatSeriesSample.self, from: data)
            return sample
        } catch {
            OTFError("Mapping from Cloudant's HeartbeatSeriesSample to HK's HeartbeatSeriesSample failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}
#endif
