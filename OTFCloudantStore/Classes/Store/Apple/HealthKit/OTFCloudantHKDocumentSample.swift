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
 An abstract class that represents a health document.
 */
public struct OTFCloudantHKDocumentSample: OTFCloudantHKSampleProtocol {

    /// The revision identifier of the sample.
    public var revId: String?

    /// The unique identifier of the sample.
    public var id: String

    /// The UUID  of the sample.
    public var uuid: UUID?

    /// The sample type.
    public var sampleType: OTFCloudantHKSampleType?

    /// The sample’s start date.
    public var startDate: Date

    /// The sample’s end date.
    public var endDate: Date

    /// The type of document represented by the sample.
    public var documentType: OTFCloudantHKDocumentType?

    /// The patient identifier for the sample.
    public var patientID: String

    /**
     - Description: Instantiates and returns a new document sample for the given patient.
     */
    public init(documentSample: HKDocumentSample, patientId: String) {
        id = documentSample.uuid.uuidString
        uuid = documentSample.uuid
        sampleType = OTFCloudantHKSampleType(sampleType: documentSample.sampleType)
        startDate = documentSample.startDate
        endDate = documentSample.endDate
        documentType = OTFCloudantHKDocumentType(sampleType: documentSample.documentType)
        patientID = patientId
    }

    /**
     - Description: Maps the data from the Cloudant's SeriesSample into HK's SeriesSample.
     - Returns: It will return an optional HKSample object.
     */
    public func toHKSample() -> HKSample? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let sample = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKDocumentSample.self, from: data)
            return sample
        } catch {
            OTFError("Mapping from Cloudant's SeriesSample into HK's SeriesSample failed with error: %{public}@", error.localizedDescription)
            return nil
        }
    }
}

/**
 An object that identify a specific type of sample when working with the HealthKit store.
 */
public struct OTFCloudantHKDocumentType: OTFHKSampleType {

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
     - Parameter sampleType:
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
     */
    public func toHKSampleType() -> HKSampleType? {
        return HKObjectType.documentType(forIdentifier: HKDocumentTypeIdentifier(rawValue: identifier ?? ""))
    }
}

/**
 A Clinical Document Architecture (CDA) sample that stores a single document.
 */
public struct OTFCloudantHKCDADocumentSample: OTFCloudantHKSampleProtocol {

    /// The unique identifier of the sample.
    public var id: String

    /// The UUID  of the sample.
    public var uuid: UUID?

    /// The patient identifier for the sample.
    public var patientID: String

    /// The document represented by the sample.
    public var document: OTFCloudantHKCDADocument?

    /// The revision identifier of the sample.
    public var revId: String?

    /// The sample type.
    public var sampleType: OTFCloudantHKSampleType?

    /// The sample’s start date.
    public var startDate: Date

    /// The sample’s end date.
    public var endDate: Date

    /// The type of document represented by the sample.
    public var documentType: OTFCloudantHKDocumentType?

    /**
     - Description: Instantiates and returns a new Clinical Document Architecture (CDA) sample for the given patient.
     - Parameter documentSample: It requires a HKCDADocumentSample as parameter.
     - Parameter patientId: It requires a patientId in string format.
     */
    public init(documentSample: HKCDADocumentSample, patientId: String) {
        id = documentSample.uuid.uuidString
        uuid = documentSample.uuid
        patientID = patientId
        if let cdaDocument = documentSample.document {
            self.document = OTFCloudantHKCDADocument(document: cdaDocument)
        }
        sampleType = OTFCloudantHKSampleType(sampleType: documentSample.sampleType)
        startDate = documentSample.startDate
        endDate = documentSample.endDate
        documentType = OTFCloudantHKDocumentType(sampleType: documentSample.documentType)
    }

    /**
     - Description: Maps the data from the Cloudant's SeriesSample into HK's SeriesSample.
     */
    public func toHKSample() -> HKSample? {
        let sample = try? HKCDADocumentSample(data: document?.documentData ?? Data(), start: startDate, end: endDate, metadata: nil)
        return sample
    }
}

/**
 An object representing a Clinical Document Architecture (CDA) document in HealthKit.
 */
public struct OTFCloudantHKCDADocument: Codable {

    /// The CDA document stored as XML data.
    public var documentData: Data?

    /// The document’s title.
    public var title: String?

    /// The patient’s name.
    public var patientName: String?

    /// The document’s author.
    public var authorName: String?

    /// The name of the organization responsible for the document.
    public var custodianName: String?
    /**
     - Description: create a new HKCDADocumentSample.
     - Parameter document: It requires a HKCDADocument object as parameter.
     */
    public init(document: HKCDADocument) {
        documentData = document.documentData
        title = document.title
        patientName = document.patientName
        authorName = document.authorName
        custodianName = document.custodianName
    }

}
#endif
