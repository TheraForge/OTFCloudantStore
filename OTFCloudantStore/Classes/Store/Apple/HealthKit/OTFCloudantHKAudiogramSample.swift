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
 A sample that stores an audiogram.
 */
public struct OTFCloudantHKAudiogramSample: OTFCloudantHKSampleProtocol {

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

    /// An array of sensitivity point objects.
    public var sensitivityPoints: [OTFCloudantHKAudiogramSensitivityPoint]?

    /**
     - Description: Instantiates and returns a new HK audiogram.
     - Parameter audiogramSample: This function require a HKAudiogramSample object in order to initialize.
     - Parameter patientId: This function require a patientId of string type in order to initialize.
     */
    public init(audiogramSample: HKAudiogramSample, patientId: String) {
        id = audiogramSample.uuid.uuidString
        uuid = audiogramSample.uuid
        sampleType = OTFCloudantHKSampleType(sampleType: audiogramSample.sampleType)
        startDate = audiogramSample.startDate
        endDate = audiogramSample.endDate
        sensitivityPoints = audiogramSample.sensitivityPoints.map { OTFCloudantHKAudiogramSensitivityPoint(audiogramSensitivityPoint: $0) }
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return an optional HKSample object, that could be null also.
     */
    public func toHKSample() -> HKSample? {
        let audiogram = HKAudiogramSample(sensitivityPoints: sensitivityPoints?.map { ($0.toHKAudiogramSensitivityPoint()) }.compactMap { $0 } ?? [], start: startDate, end: endDate, metadata: nil)
        return audiogram
    }
}

/**
 A sample types that stores an audiogram.
 */
public struct OTFCloudantHKAudiogramSampleType: OTFHKSampleType {

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
     - Parameter sampleType: This function require a HKSampleType object in order to initialize.
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
     - Returns: This function will return an optional HKSampleType object, that could be null also.
     */
    public func toHKSampleType() -> HKSampleType? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let sampleType = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKAudiogramSampleType.self, from: data)
            return sampleType
        } catch {
            OTFError("Mapping from Cloudant's AudiogramSampleType to HK's AudiogramSampleType failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}

/**
 A hearing sensitivity reading associated with a hearing test.
 */
public struct OTFCloudantHKAudiogramSensitivityPoint: Codable {

    /// The frequency tested in the hearing test.
    public var frequency: OTFCloudantHKQuantity?

    /// The sensitivity of the left ear.
    public var leftEarSensitivity: OTFCloudantHKQuantity?

    /// The sensitivity of the right ear.
    public var rightEarSensitivity: OTFCloudantHKQuantity?

    /**
     - Description: Creates a new sensitivity point.
     - Parameter audiogramSensitivityPoint: This function require a HKAudiogramSensitivityPoint object in order to initialize.
     */
    public init(audiogramSensitivityPoint: HKAudiogramSensitivityPoint) {
        frequency = OTFCloudantHKQuantity(quantity: audiogramSensitivityPoint.frequency)
        if let leftEar = audiogramSensitivityPoint.leftEarSensitivity {
            leftEarSensitivity = OTFCloudantHKQuantity(quantity: leftEar)
        }
        if let rightEar = audiogramSensitivityPoint.rightEarSensitivity {
            rightEarSensitivity = OTFCloudantHKQuantity(quantity: rightEar)
        }
    }

    /**
     - Description: Returns from the Cloudant's  sensitivity point into HK's  sensitivity point.
     - Returns: This function will return an optional HKAudiogramSensitivityPoint object, that could be null also.
     */
    // swiftlint:disable line_length
    public func toHKAudiogramSensitivityPoint() -> HKAudiogramSensitivityPoint? {
        let audigram = try? HKAudiogramSensitivityPoint(frequency: frequency?.toHKQuantity() ?? .defaultValue(), leftEarSensitivity: leftEarSensitivity?.toHKQuantity(), rightEarSensitivity: rightEarSensitivity?.toHKQuantity())
        return audigram
    }

}
#endif
