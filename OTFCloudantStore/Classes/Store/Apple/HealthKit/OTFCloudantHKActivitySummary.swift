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
 An object that contains the move, exercise, and stand data for a given day.
 */
public struct OTFCloudantHKActivitySummary: Codable, OTFCloudantRevision, Identifiable {

    /// The unique identifier of the sample.
    public var id: String?

    /// The revision identifier of the sample.
    public var revId: String?

    /// Constants that specify the value measured by the Move ring on the user’s device.
    public var activityMoveMode: Int?

    /// The amount of active energy that the user has burned during the specified day.
    public var activeEnergyBurned: OTFCloudantHKQuantity?

    /// The amount of time that the user has spent performing activities that involve full-body movements during the specified day.
    public var appleMoveTime: OTFCloudantHKQuantity?

    /// The amount of time that the user has spent exercising during the specified day.
    public var appleExerciseTime: OTFCloudantHKQuantity?

    /// The number hours in the specified day during which the user has stood and moved for at least a minute per hour.
    public var appleStandHours: OTFCloudantHKQuantity?

    /// The user’s daily goal for active energy burned.
    public var activeEnergyBurnedGoal: OTFCloudantHKQuantity?

    /// The user’s daily goal for move time.
    public var appleMoveTimeGoal: OTFCloudantHKQuantity?

    /// The user’s daily exercise goal.
    public var appleExerciseTimeGoal: OTFCloudantHKQuantity?

    /**
     - Description: Instantiates and returns a new HK Activity.
     - Parameter activitySummary: This function require a HKActivitySummary object as parameter in order to initialize.
     */
    public init(activitySummary: HKActivitySummary) {
        if #available(iOS 14.0, *) {
            activityMoveMode = activitySummary.activityMoveMode.rawValue
            appleMoveTime = OTFCloudantHKQuantity(quantity: activitySummary.appleMoveTime)
            appleMoveTimeGoal = OTFCloudantHKQuantity(quantity: activitySummary.appleMoveTimeGoal)
        }
        activeEnergyBurned = OTFCloudantHKQuantity(quantity: activitySummary.activeEnergyBurned)
        appleExerciseTime = OTFCloudantHKQuantity(quantity: activitySummary.appleExerciseTime)
        appleStandHours = OTFCloudantHKQuantity(quantity: activitySummary.appleStandHours)
        activeEnergyBurnedGoal = OTFCloudantHKQuantity(quantity: activitySummary.activeEnergyBurnedGoal)
        appleExerciseTimeGoal = OTFCloudantHKQuantity(quantity: activitySummary.appleExerciseTimeGoal)
    }

    /**
     - Description: Maps the data from the Cloudant's activity summary into HK's activity summary.
     - Returns: This function will return a HKActivitySummary object.
     */
    public func toHKActivitySummary() -> HKActivitySummary {
        let summary = HKActivitySummary()
        if #available(iOS 14.0, *) {
            summary.activityMoveMode = HKActivityMoveMode(rawValue: activityMoveMode ?? 0) ?? .activeEnergy
            summary.appleMoveTime = appleMoveTime?.toHKQuantity() ?? .defaultValue()
            summary.appleMoveTimeGoal = appleMoveTimeGoal?.toHKQuantity() ?? .defaultValue()
        }
        summary.activeEnergyBurned = activeEnergyBurned?.toHKQuantity() ?? .defaultValue()
        summary.appleExerciseTime = appleExerciseTime?.toHKQuantity() ?? .defaultValue()
        summary.appleStandHours = appleStandHours?.toHKQuantity() ?? .defaultValue()
        summary.activeEnergyBurnedGoal = activeEnergyBurnedGoal?.toHKQuantity() ?? .defaultValue()
        summary.appleExerciseTimeGoal = appleExerciseTimeGoal?.toHKQuantity() ?? .defaultValue()
        return summary
    }
}

/**
 Extends HKQuantity to return default value.
 */
extension HKQuantity {

    /**
     - Description: Default value '0' is set for the HK quantity.
     - Returns: It will return HKQuantity object.
     */
    public static func defaultValue() -> HKQuantity {
        return HKQuantity(unit: HKUnit(from: ""), doubleValue: 0)
    }

}

public class OTFCloudantHKActivitySummaryType: OTFCloudantHKObjectType {

}
#endif
