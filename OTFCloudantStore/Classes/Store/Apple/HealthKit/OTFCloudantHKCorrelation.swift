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

#if HEALTH
import HealthKit

/**
 A sample that groups multiple related samples into a single entry.
 */
public struct OTFCloudantHKCorrelation: OTFCloudantHKSampleProtocol {

    /// The unique identifiers for the sample.
    public var id: String

    /// The UUID for the sample.
    public var uuid: UUID?

    /// The revision id for the sample.
    public var revId: String?

    /// The cloudant sample types.
    public var sampleType: OTFCloudantHKSampleType?

    /// The start date for the sample.
    public var startDate: Date

    /// The end date for the sample.
    public var endDate: Date

    /// The type for this correlation.
    public var correlationType: OTFCloudantHKCorrelationType?

    /// A set of HKSample objects. 
    public var objects: [OTFCloudantHKSample]?

    /// The patient identifier for the workout.
    public var patientID: String

    /**
     - Description: Instantiates and returns a new correlation instance.
     - Parameter correlation: This function requires a HKCorrelation object as parameter.
     - Parameter patientId: This function requires a patientId of String type as parameter.
     */
    public init(correlation: HKCorrelation, patientId: String) {
        id = correlation.uuid.uuidString
        uuid = correlation.uuid
        correlationType = OTFCloudantHKCorrelationType(sampleType: correlation.correlationType)
        sampleType = OTFCloudantHKSampleType(sampleType: correlation.sampleType)
        startDate = correlation.startDate
        endDate = correlation.endDate
        objects = correlation.objects.map { OTFCloudantHKSample(sample: $0, patientId: patientId) }
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's sample to HK's samples.
     - Returns: This function will return an optional HKSample object. That could be nil also.
     */
    public func toHKSample() -> HKSample? {
        guard let type = correlationType?.toHKSampleType() as? HKCorrelationType else { return nil }
        let correlation = HKCorrelation(type: type, start: startDate, end: endDate, objects: Set(objects?.map { $0.toHKSample() }.compactMap { $0 } ?? [] ))
        return correlation
    }

}

/**
 A type that identifies samples that group multiple subsamples.
 */
public struct OTFCloudantHKCorrelationType: OTFHKSampleType {

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
     - Description: Instantiates and returns a new HK document type.
     - Parameter sampleType: This function requires a HKSampleType object as parameter.
     */
    public init(sampleType: HKSampleType) {
        isMaximumDurationRestricted = sampleType.isMaximumDurationRestricted
        maximumAllowedDuration = sampleType.maximumAllowedDuration
        isMinimumDurationRestricted = sampleType.isMinimumDurationRestricted
        minimumAllowedDuration = sampleType.minimumAllowedDuration
        identifier = sampleType.identifier
    }

    /**
     - Description: Maps the data from the Cloudant's SeriesSample into HK's SeriesSample.
     - Returns: This function will return an optional HKSampleType object, that could be nil also.
     */
    public func toHKSampleType() -> HKSampleType? {
        return HKObjectType.correlationType(forIdentifier: HKCorrelationTypeIdentifier(rawValue: identifier ?? ""))
    }

}
#endif
