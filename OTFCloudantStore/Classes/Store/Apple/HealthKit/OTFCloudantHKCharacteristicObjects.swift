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

/// This class acts as a wrapper for the HKBiologicalSex enumeration.
public struct OTFCloudantHKBiologicalSexObject: Codable {

    /// The biological sex.
    public var biologicalSex: Int?

    /**
     - Description: Instantiates and returns a new HK biological sex object.
     - Parameter sexObject: This function requires a HKBiologicalSexObject as parameter to initialize the struct.
     */
    public init(sexObject: HKBiologicalSexObject) {
        biologicalSex = sexObject.biologicalSex.rawValue
    }
}

/// This class acts as a wrapper for the HKBloodType enumeration.
public struct OTFCloudantHKBloodTypeObject: Codable {

    /// The blood type.
    public var bloodType: Int?

    /**
     - Description: Instantiates and returns a new HK  blood type object.
     - Parameter bloodTypeObject: This function requires a HKBloodTypeObject as parameter  to initialize the struct.
     */
    public init(bloodTypeObject: HKBloodTypeObject) {
        bloodType = bloodTypeObject.bloodType.rawValue
    }
}

/// This class acts as a wrapper for the HKFitzpatrick skin type enumeration.
public struct OTFCloudantHKFitzpatrickSkinTypeObject: Codable {

    /// The skin type.
    public var skinType: Int?

    /**
     - Description: Instantiates and returns a new HKFitzpatrick skin type object.
     - Parameter skinTypeObject: This function requires a HKFitzpatrickSkinTypeObject as parameter  to initialize the struct.
     */
    public init(skinTypeObject: HKFitzpatrickSkinTypeObject) {
        skinType = skinTypeObject.skinType.rawValue
    }
}

/// This class acts as a wrapper for the HKWheelchair use object enumeration.
public struct OTFCloudantHKWheelchairUseObject: Codable {

    /// The wheel chair type.
    public var wheelchairUse: Int?

    /**
     - Description: Instantiates and returns a new HKWheelchair use object.
     - Parameter skinTypeObject: This function requires a HKWheelchairUseObject as parameter to initialize the struct.
     */
    public init(wheelchairUseObject: HKWheelchairUseObject) {
        wheelchairUse = wheelchairUseObject.wheelchairUse.rawValue
    }
}
#endif
