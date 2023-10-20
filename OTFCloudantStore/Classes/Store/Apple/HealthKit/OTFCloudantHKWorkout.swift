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
 An object representing an important event during a workout.
 */
public struct OTFCloudantHKWorkoutEvent: Codable {

    /// The type of workout event.
    public var type: Int?

    /// The time when the transition occurred.
    public var date: Date?

    /// The time and duration of the event.
    public var dateInterval: DateInterval?

    /// The metadata associated with the workout event.
    public var metadata: [String: Any]?

    /// Types that can be used as a key for encoding and decoding.
    private enum CodingKeys: CodingKey {
        case type
        case date
        case dateInterval
        case metadata
    }

    /**
     - Description: Instantiates and returns a new workout event with the specified type, data interval, and metadata.
     - Parameter workoutEvent: It requires a HKWorkoutEvent object to initialize.
     */
    public init(workoutEvent: HKWorkoutEvent) {
        type = workoutEvent.type.rawValue
        dateInterval = workoutEvent.dateInterval
        metadata = workoutEvent.metadata
        if #available(iOS 11, *) {
            // date is deprecated
        } else {
            date = workoutEvent.date
        }
    }

    /**
     - Description: Encodes the workout event with its type, date interval, and metadata.
     */
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(date, forKey: .date)
        try container.encode(dateInterval, forKey: .dateInterval)
        if let dict = metadata, !dict.isEmpty {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed)
            try container.encode(jsonData, forKey: .metadata)
        }
    }

    /**
     - Description: Decodes the workout event with its type, date interval, and metadata.
     */
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(Int.self, forKey: .type)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        dateInterval = try container.decodeIfPresent(DateInterval.self, forKey: .dateInterval)
        if let data = try container.decodeIfPresent(Data.self, forKey: .metadata) {
            metadata = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        }
    }
}

/**
 A builder object that incrementally constructs a workout.
 */
public struct OTFCloudantHKWorkoutBuilder: Codable {
    /// The workout’s start date and time.
    public var startDate: Date?

    /// The workout’s end date and time.
    public var endDate: Date?

    /// The configuration information for the workout.
    public var workoutConfiguration: OTFCloudantHKWorkoutConfiguration?

    /// The list of events added to the workout.
    public var workoutEvents: [OTFCloudantHKWorkoutEvent]?

    /**
     - Description: Instantiates and returns a new workout builder with the start date and end date.
     - Parameter workoutBuilder: This initializer requires a HKWorkoutBuilder object.
     */
    public init(workoutBuilder: HKWorkoutBuilder) {
        startDate = workoutBuilder.startDate
        endDate = workoutBuilder.endDate
    }
}

/**
 An object that contains configuration information about a workout session.
 */
public struct OTFCloudantHKWorkoutConfiguration: Codable {

    /// The workout session’s activity type.
    public var activityType: UInt?

    /// The workout session’s location.
    public var locationType: Int?

    /// The workout session’s swimming location.
    public var swimmingLocationType: Int?

    /// The length of the lap for a workout session.
    public var lapLength: OTFCloudantHKQuantity?

    /**
     - Description: Instantiates and returns a new workout configuration.
     */
    public init(configuration: HKWorkoutConfiguration) {
        activityType = configuration.activityType.rawValue
        locationType = configuration.locationType.rawValue
        swimmingLocationType = configuration.swimmingLocationType.rawValue
        if let length = configuration.lapLength {
            lapLength = OTFCloudantHKQuantity(quantity: length)
        }
    }
}

/**
 A sample that contains a workout’s route data.
 */
public class OTFCloudantHKWorkoutRoute: OTFCloudantHKSampleProtocol {

    /// The unique identifiers that belong to the entities that match the workout.
    public var id: String

    /// The UUID for the entities that match the workout.
    public var uuid: UUID?

    /// The revision id for the entities that match the workout.
    public var revId: String?

    /// The cloudant sample types.
    public var sampleType: OTFCloudantHKSampleType?

    /// The workout’s start date and time.
    public var startDate: Date

    /// The workout’s end date and time.
    public var endDate: Date

    /// The number of items in the series.
    public var count: Int?

    /// The patient identifier for the workout.
    public var patientID: String

    /**
    - Description: Instantiates and returns a new workout route for the patient.
    - Parameter sample: This function requires a HKWorkoutRoute object as parameter.
    - Parameter patientId: This function requires a patientId of string type.
     */
    public init(sample: HKWorkoutRoute, patientId: String) {
        id = sample.uuid.uuidString
        uuid = sample.uuid
        count = sample.count
        sampleType = OTFCloudantHKSampleType(sampleType: sample.sampleType)
        startDate = sample.startDate
        endDate = sample.endDate
        patientID = patientId
    }

     /**
     - Description: Maps the data from Cloudant's SeriesSample into HK's SeriesSample.
     - Returns: It will return an optional HKSample type object.
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
#endif
