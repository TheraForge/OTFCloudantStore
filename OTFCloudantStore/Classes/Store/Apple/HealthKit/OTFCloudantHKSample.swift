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

public protocol OTFCloudantHKSampleProtocol: Codable, OTFCloudantRevision, Identifiable {

    /// The unique identifier of the sample.
    var id: String { get set }

    /// The UUID  of the sample.
    var uuid: UUID? { get set }

    /// The revision identifier of the sample.
    var revId: String? { get set }

    /// The patient identifier for the sample.
    var patientID: String { get set }

    /// The sample’s start date.
    var startDate: Date { get set }

    /// The sample’s end date.
    var endDate: Date { get set }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return an optional HKSample, that could be nil also.
     */
    func toHKSample() -> HKSample?
}

public struct OTFCloudantHKSample: OTFCloudantHKSampleProtocol {

    /// The unique identifier of the sample.
    public var id: String

    /// The UUID  of the sample.
    public var uuid: UUID?

    /// The revision identifier of the sample.
    public var revId: String?

    /// The patient identifier for the sample.
    public var patientID: String

    /// The sample type.
    public var sampleType: OTFCloudantHKSampleType?

    /// The sample’s start date.
    public var startDate: Date

    /// The sample’s end date.
    public var endDate: Date

    /**
     - Description: Instantiates and returns a new sample for the given patient.
     - Parameter sample: This function requires an HKSample object as parameter.
     - Parameter patientId: This function requires a PatientId of String type as parameter.
     */
    init(sample: HKSample, patientId: String) {
        id = sample.uuid.uuidString
        uuid = sample.uuid
        sampleType = OTFCloudantHKSampleType(sampleType: sample.sampleType)
        startDate = sample.startDate
        endDate = sample.endDate
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return a optional HKSample object, that could be nil also.
     */
    public func toHKSample() -> HKSample? {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            let sample = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKSample.self, from: data)
            return sample
        } catch {
            OTFError("Mapping from OTF's HKSample to HK's HKSample failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}

public protocol OTFHKSampleType: Codable {
    /// A Boolean value that indicates whether samples of this type have a maximum time interval between the start and end dates.
    var isMaximumDurationRestricted: Bool? { get set }

    /// The maximum duration if the sample type has a restricted duration.
    var maximumAllowedDuration: TimeInterval? { get set }

    /// A Boolean value that indicates whether samples of this type have a minimum time interval between the start and end dates.
    var isMinimumDurationRestricted: Bool? { get set }

    /// The minimum duration if the sample type has a restricted duration.
    var minimumAllowedDuration: TimeInterval? { get set }

    /// A unique string identifying the HealthKit object type.
    var identifier: String? { get set }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return a optional HKSample object, that could be nil also.
     */
    func toHKSampleType() -> HKSampleType?
}

/**
 An object that identify a specific type of sample when working with the HealthKit store.
 */
public struct OTFCloudantHKSampleType: OTFHKSampleType {

    /// A Boolean value that indicates whether samples of this type have a maximum time interval between the start and end dates.
    public var isMaximumDurationRestricted: Bool?

    /// The maximum duration if the sample type has a restricted duration.
    public var maximumAllowedDuration: TimeInterval?

    /// A Boolean value that indicates whether samples of this type have a minimum time interval between the start and end dates.
    public var isMinimumDurationRestricted: Bool?

    /// The minimum duration if the sample type has a restricted duration.
    public var minimumAllowedDuration: TimeInterval?

    /// A unique string identifying the HealthKit object type.
    public var identifier: String?

    /**
     - Description: Instantiates and returns a new HK sample type.
     - Parameter sampleType: This function requires a HKSampleType object to get initialized.
     */
    public init(sampleType: HKSampleType) {
        isMaximumDurationRestricted = sampleType.isMaximumDurationRestricted
        maximumAllowedDuration = sampleType.maximumAllowedDuration
        isMinimumDurationRestricted = sampleType.isMinimumDurationRestricted
        minimumAllowedDuration = sampleType.minimumAllowedDuration
        identifier = sampleType.identifier
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return an optional HKSampleType object, that could be nil also.
     */
    public func toHKSampleType() -> HKSampleType? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let sampleType = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKSampleType.self, from: data)
            return sampleType
        } catch {
            OTFError("Mapping from Cloudant's sample type to HK's sample type failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}
#endif
