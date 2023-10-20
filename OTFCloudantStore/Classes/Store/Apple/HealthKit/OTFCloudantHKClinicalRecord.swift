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
@available(iOS 14.0, *)

/**
 A sample that stores a clinical record.
 */
public struct OTFCloudantHKClinicalRecord: OTFCloudantHKSampleProtocol {

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

    /// An identifier that indicates the type of record, such as an allergic reaction, a lab result, or a medical procedure.
    public var clinicalType: OTFCloudantHKClinicalType?

    /// The primary display name as shown in the Health app.
    public var displayName: String?

    /// The Fast Healthcare Interoperability Resources (FHIR) data for this record.
    public var fhirResource: OTFCloudantHKFHIRResource?

    /**
     - Description: Instantiates and returns a new HK clinical record.
     - Parameter record: This function required a HKClinicalRecord object as parameter in order to initialize.
     - Parameter patientId: This function required a patientId of string type as parameter in order to initialize.
     */
    public init(record: HKClinicalRecord, patientId: String) {
        id = record.uuid.uuidString
        uuid = record.uuid
        patientID = patientId
        clinicalType = OTFCloudantHKClinicalType(sampleType: record.clinicalType)
        displayName = record.displayName
        if let hkFHIRResource = record.fhirResource {
            fhirResource = OTFCloudantHKFHIRResource(fhirResource: hkFHIRResource)
        }
        sampleType = OTFCloudantHKSampleType(sampleType: record.sampleType)
        startDate = record.startDate
        endDate = record.endDate
    }

    /**
     - Description: Maps the data from the Cloudant's sample into HK's sample.
     - Returns: This function will return an optional HKSample object, that could be nil also.
     */
    public func toHKSample() -> HKSample? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let clinicalRecord = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKClinicalRecord.self, from: data)
            return clinicalRecord
        } catch {
            OTFError("Mapping from Cloudant's ClinicalRecord to HK's ClinicalRecord failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}

public struct OTFCloudantHKClinicalType: OTFHKSampleType {

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
     - Returns: This function will return an optional HKSampleType object, that could be nil also.
     */
    public func toHKSampleType() -> HKSampleType? {
        return HKObjectType.clinicalType(forIdentifier: HKClinicalTypeIdentifier(rawValue: identifier ?? ""))
    }
}

@available(iOS 14.0, *)

/**
 An object containing Fast Healthcare Interoperability Resources (FHIR) data.
 */
public struct OTFCloudantHKFHIRResource: Codable {

    /// The Fast Healthcare Interoperability Resources (FHIR) data for this record.
    public var fhirVersion: OTFCloudantHKFHIRVersion?

    /// The value from the FHIR resource’s resourceType field.
    public var resourceType: String?

    /// The value from the FHIR resource’s id field.
    public var identifier: String?

    /// The JSON representation of the FHIR resource.
    public var data: Data?

    /// The full URL for the source of the FHIR resource.
    public var sourceURL: URL?

    /**
     - Description: Instantiates and returns a new HK FHIR resource.
     - Parameter fhirResource: This function require a HKFHIRResource as parameter in order to initialize.
     */
    init(fhirResource: HKFHIRResource) {
        fhirVersion = OTFCloudantHKFHIRVersion(fhirVersion: fhirResource.fhirVersion)
        resourceType = fhirResource.resourceType.rawValue
        identifier = fhirResource.identifier
        data = fhirResource.data
        sourceURL = fhirResource.sourceURL
    }
}

@available(iOS 14.0, *)
/**
 The FHIR version.
 */
public struct OTFCloudantHKFHIRVersion: Codable {

    /// The standard’s major version number.
    public var majorVersion: Int?

    /// The standard’s minor version number.
    public var minorVersion: Int?

    /// The standard’s patch version number.
    public var patchVersion: Int?

    /// A string representation of the version.
    public var stringRepresentation: String?

    /**
     - Description: Instantiates and returns a new HK FHIR version.
     - Parameter fhirVersion: This function require a HKFHIRVersion object as parameter in order to initialize.
     */
    init(fhirVersion: HKFHIRVersion) {
        majorVersion = fhirVersion.majorVersion
        minorVersion = fhirVersion.minorVersion
        patchVersion = fhirVersion.patchVersion
        stringRepresentation = fhirVersion.stringRepresentation
    }

    /**
     - Description: Data from the Cloudant's FHIR version sent into HK's  FHIR version.
     - Returns: This function will return an optional HKFHIRVersion object, that could be nil also.
     */
    func toHKFHIRVersion() -> HKFHIRVersion? {
        guard let stringRepresentation = stringRepresentation else { return nil }
        let version = try? HKFHIRVersion(fromVersionString: stringRepresentation)
        return version
    }
}
#endif
