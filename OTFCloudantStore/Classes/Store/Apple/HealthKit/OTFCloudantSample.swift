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

/// Types of data used in OTF health sample type.
public enum OTFHealthSampleType: String, Codable {
    case category
    case quantity
    case correlation
}

/**
 A sample represents a piece of data that is associated with a start and end time.
 */
public struct OTFCloudantSample: OTFCloudantHKSampleProtocol {

    /// The unique identifier of the sample.
    public var id: String

    /// The UUID  of the sample.
    public var uuid: UUID?

    /// The revision identifier of the sample.
    public var revId: String?

    /// The patient identifier for the sample.
    public var patientID: String

    /// The sample’s start date.
    public var startDate: Date

    /// The sample’s end date.
    public var endDate: Date

    /// A unique string that identifies a piece of data so it can be updated and synced.
    public var syncIdentifier: String?

    /// The version number for a piece of data, used when updating or syncing.
    public var syncVersion: Int?

    /// The sample type.
    public let type: OTFHealthSampleType

    /// The sample type identifier.
    public let typeIdentifier: String

    /// The sample quantity unit.
    public let unit: String

    /// The sample value.
    public let value: Double

    /// The list of samples.
    public let samples: [OTFCloudantSample]?

    public var metadata: [String: Bool]?

    /**
     - Description: Instantiates and returns a new HKsample.
     - Parameter sample: It requires an HKSample object as parameter.
     - Parameter patientId: It requires an patientId string as parameter.
     */
    public init(sample: HKSample, patientId: String) {
        typeIdentifier = sample.sampleType.identifier
        startDate = sample.startDate
        endDate = sample.endDate
        uuid = sample.uuid
        revId = sample.sourceRevision.version
        patientID = patientId
        syncIdentifier = sample.metadata?[HKMetadataKeySyncIdentifier] as? String
        syncVersion = sample.metadata?[HKMetadataKeySyncVersion] as? Int
        id = (sample.metadata?[HKMetadataKeyExternalUUID] as? String) ?? sample.uuid.uuidString

        if let category = sample as? HKCategorySample {
            value = Double(category.value)
            unit = OTFParsingHelper.preferredUnit(for: category)?.unitString ?? ""
            samples = nil
            type = .category

            if let metadata = sample.metadata as? [String: Bool] {
                self.metadata = metadata
            }
        } else if let quantity = sample as? HKQuantitySample {
            if let preferredUnit = OTFParsingHelper.preferredUnit(for: quantity) {
                unit = preferredUnit.unitString
                value = quantity.quantity.doubleValue(for: preferredUnit)
            } else {
                unit = ""
                value = 0
            }
            samples = nil
            type = .quantity
            self.metadata = nil
        } else if let correlation = sample as? HKCorrelation {
            type = .correlation
            unit = OTFParsingHelper.preferredUnit(for: correlation)?.unitString ?? ""
            value = 0
            var objects = [OTFCloudantSample]()
            for sample in correlation.objects {
                objects.append(OTFCloudantSample(sample: sample, patientId: patientID))
            }
            samples = objects
            self.metadata = nil
        } else {
            type = .category
            unit = ""
            value = 0
            samples = nil
            self.metadata = nil
        }
    }

    /**
    - Description: This function can be used to get the sample type detail of an OTFCloudantSample.
    - Returns: It will return the corresponding optional HKSampleType object that could also be nil.
     */
    public func sampleType() -> HKSampleType? {
        return OTFParsingHelper.getSampleType(for: typeIdentifier)
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: It will return an optional HKSample object, that could also be nil.
     */
    public func toHKSample() -> HKSample? {
        var metadata = [String: Any]()
        metadata[HKMetadataKeySyncIdentifier] = syncIdentifier
        metadata[HKMetadataKeySyncVersion] = syncVersion
        metadata[HKMetadataKeyExternalUUID] = uuid?.uuidString
        switch type {
        case .category:
            guard let type = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: typeIdentifier)) else {
                OTFLog("Unidentify category type's indentifier with identifier: %{public}@", typeIdentifier)
                return nil
            }
            if let originalMetadata = self.metadata {
                metadata = metadata.merging(originalMetadata, uniquingKeysWith: { (first, _) in first })
            }
            return HKCategorySample(type: type, value: Int(value), start: startDate, end: endDate, metadata: metadata)
        case .quantity:
            guard let type = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: typeIdentifier)) else {
                OTFLog("Unidentify category type's indentifier with identifier: %{public}@", typeIdentifier)
                return nil
            }
            guard let unit = OTFParsingHelper.processUnitString(unit) else {
                OTFLog("Unidentify quantity's unit with unit: %{public}@", self.unit)
                return nil
            }

            let quantity = HKQuantity(unit: unit, doubleValue: value)

            return HKQuantitySample(type: type, quantity: quantity, start: startDate, end: endDate, metadata: metadata)
        case .correlation:
            guard let type = HKCorrelationType.correlationType(forIdentifier: HKCorrelationTypeIdentifier(rawValue: typeIdentifier)) else {
                OTFLog("Unidentify correlation type's indentifier with identifier: %{public}@", typeIdentifier)
                return nil
            }
            let objects = samples?.map { $0.toHKSample() }.compactMap { $0 } ?? []
            return HKCorrelation(type: type, start: startDate, end: endDate, objects: Set(objects), metadata: metadata)
        }
    }

    public func isEqual(to sample: HKSample) -> Bool {
        return  id == sample.metadata?[HKMetadataKeyExternalUUID] as? String
    }

}
#endif
