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
 An object that stores a value for a given unit.
 */
public struct OTFCloudantHKQuantity: OTFCloudantRevision, Codable {

    /// The revision identifier of the object.
    public var revId: String?

    /// The value for the quantity.
    public var value: Double?

    /// The unit for the quantity.
    public var unit: OTFCloudantHKUnit?

    /**
     - Description: Instantiates and returns a new HK Quantity.
     - Parameter quantity: This function require a HKQuantity object as parameter in order to initialize.
     */
    public init(quantity: HKQuantity) {
        value = quantity.value(forKey: "value") as? Double
        if let hkUnit = quantity.value(forKey: "unit") as? HKUnit {
            unit = OTFCloudantHKUnit(unit: hkUnit)
        }
    }

    /**
     - Description: Maps the data from the Cloudant's quantity into HK's quantity.
     - Returns: This function will return a HKQuantity object.
     */
    public func toHKQuantity() -> HKQuantity {
        guard let unit = self.unit, let value = self.value else { return HKQuantity.defaultValue() }
        let quantity = HKQuantity(unit: unit.toHKUnit(), doubleValue: value)
        return quantity
    }

}

/**
 A sample that represents a quantity, including the value and the units.
 */
public struct OTFCloudantHKQuantitySample: OTFCloudantHKSampleProtocol {

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

    /// The quantity type for this sample.
    public var quantityType: String?

    /// The quantity for this sample.
    public var quantity: OTFCloudantHKQuantity?

    /// The sample’s start date.
    public var startDate: Date

    /// The sample’s end date.
    public var endDate: Date

    /**
     - Description: Instantiates and returns a quantity sample for the given patient.
     - Parameter quantitySample: This function require a HKQuantitySample object as parameter in order to initialize.
     - Parameter patientId: This function require a patientId of string type in order to initialize.
     */
    public init(quantitySample: HKQuantitySample, patientId: String) {
        quantityType = quantitySample.quantityType.identifier
        id = quantitySample.uuid.uuidString
        uuid = quantitySample.uuid
        quantity = OTFCloudantHKQuantity(quantity: quantitySample.quantity)
        sampleType = OTFCloudantHKSampleType(sampleType: quantitySample.sampleType)
        startDate = quantitySample.startDate
        endDate = quantitySample.endDate
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return an optional HKSample object, that could be nil also.
     */
    public func toHKSample() -> HKSample? {
        guard let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: quantityType ?? "")) else { return nil }
        let sample = HKQuantitySample(type: type, quantity: quantity?.toHKQuantity() ?? .defaultValue(), start: startDate, end: endDate)
        return sample
    }
}

/**
 A sample that represents a cumulative quantity.
 */
public struct OTFCloudantHKCumulativeQuantitySample: OTFCloudantHKSampleProtocol {

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

    /// The quantity type for this sample.
    public var quantityType: String?

    /// The quantity for this sample.
    public var quantity: OTFCloudantHKQuantity?

    /// Returns the sum of all the samples that match the query.
    public var sumQuantity: OTFCloudantHKQuantity?

    /// The sample’s start date.
    public var startDate: Date

    /// The sample’s end date.
    public var endDate: Date

    /**
     - Description: Instantiates and returns a new sample for the given patient.
     - Parameter cumulativeQuantitySample: This function require a HKCumulativeQuantitySample object as parameter in order to initialize.
     - Parameter patientId: This function require a patientId of string type in order to initialize.
     */
    public init(cumulativeQuantitySample: HKCumulativeQuantitySample, patientId: String) {
        id = cumulativeQuantitySample.uuid.uuidString
        uuid = cumulativeQuantitySample.uuid
        sumQuantity = OTFCloudantHKQuantity(quantity: cumulativeQuantitySample.sumQuantity)
        quantityType = cumulativeQuantitySample.quantityType.identifier
        quantity = OTFCloudantHKQuantity(quantity: cumulativeQuantitySample.quantity)
        sampleType = OTFCloudantHKSampleType(sampleType: cumulativeQuantitySample.sampleType)
        startDate = cumulativeQuantitySample.startDate
        endDate = cumulativeQuantitySample.endDate
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return an optional HKSample object, that could be nil also.
     */
    public func toHKSample() -> HKSample? {
        let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: quantityType ?? ""))!
        let sample = HKCumulativeQuantitySample(type: type, quantity: quantity?.toHKQuantity() ?? .defaultValue(), start: startDate, end: endDate)
        return sample
    }
}

/**
 A sample that represents a discrete quantity.
 */
public struct OTFCloudantHKDiscreteQuantitySample: OTFCloudantHKSampleProtocol {

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

    /// The quantity type for this sample.
    public var quantityType: String?

    /// The quantity for this sample.
    public var quantity: OTFCloudantHKQuantity?

    /// The minimum value contained by the sample.
    public var minimumQuantity: OTFCloudantHKQuantity?

    /// The average of all quantities contained by the sample
    public var averageQuantity: OTFCloudantHKQuantity?

    /// The maximum quantity contained by the sample.
    public var maximumQuantity: OTFCloudantHKQuantity?

    /// The most recent quantity contained by the sample.
    public var mostRecentQuantity: OTFCloudantHKQuantity?

    /// The date interval for the most recent quantity contained by the sample.
    public var mostRecentQuantityDateInterval: DateInterval?

    /**
     - Description: Instantiates and returns a new sample for the given patient.
     - Parameter sample: This function require a HKDiscreteQuantitySample object as parameter in order to initialize.
     - Parameter patientId: This function require a patientId of string type in order to initialize.
     */
    public init(sample: HKDiscreteQuantitySample, patientId: String) {
        id = sample.uuid.uuidString
        uuid = sample.uuid
        minimumQuantity = OTFCloudantHKQuantity(quantity: sample.minimumQuantity)
        averageQuantity = OTFCloudantHKQuantity(quantity: sample.averageQuantity)
        maximumQuantity = OTFCloudantHKQuantity(quantity: sample.maximumQuantity)
        mostRecentQuantity = OTFCloudantHKQuantity(quantity: sample.mostRecentQuantity)
        mostRecentQuantityDateInterval = sample.mostRecentQuantityDateInterval
        quantityType = sample.quantityType.identifier
        quantity = OTFCloudantHKQuantity(quantity: sample.quantity)
        sampleType = OTFCloudantHKSampleType(sampleType: sample.sampleType)
        startDate = sample.startDate
        endDate = sample.endDate
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return an optional HKSample object, that could be nil also.
     */
    public func toHKSample() -> HKSample? {
        let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: quantityType ?? ""))!
        let sample = HKDiscreteQuantitySample(type: type, quantity: quantity?.toHKQuantity() ?? .defaultValue(), start: startDate, end: endDate)
        return sample
    }

}

/**
 A type that identifies samples that store numerical values.
 */
public struct OTFCloudantHKQuantityType: OTFHKSampleType {

    /// The aggregation style for the given quantity type.
    public var aggregationStyle: Int?

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
     - Description: Instantiates and returns a new HK quantity type.
     - Parameter quantityType: This function require a HKQuantityType object as parameter in order to initialize.
     */
    public init(quantityType: HKQuantityType) {
        isMaximumDurationRestricted = quantityType.isMaximumDurationRestricted
        maximumAllowedDuration = quantityType.maximumAllowedDuration
        isMinimumDurationRestricted = quantityType.isMinimumDurationRestricted
        minimumAllowedDuration = quantityType.minimumAllowedDuration
        identifier = quantityType.identifier
        aggregationStyle = quantityType.aggregationStyle.rawValue
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return an optional HKSample object, that could be nil also.
     */
    public func toHKSampleType() -> HKSampleType? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let type = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQuantityType.self, from: data)
            return type
        } catch {
            OTFError("Mapping from Cloudant's QuantityType to HK's QuantityType failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}
#endif
