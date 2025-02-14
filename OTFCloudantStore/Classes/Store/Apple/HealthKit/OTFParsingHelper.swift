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

// swiftlint:disable all
/*
 OTFParsingHelper provides functionalities to help on mapping entities between OTFCloudantSample and Samples from CareKitStore, HealthKitStore and OTFResearchKit
 */
public class OTFParsingHelper {

    private static let healthStore = HKHealthStore()

    /**
     - Description: Process server response for HKUnit kind.
     - Parameter unit: pass a unit's String in parameter and it will return a corresponding HKUnit.
     - Returns: This function will return an optional HKUnit. It could be nil if it couldn't find the HKUnit for the given unit string.
     */
    public static func processUnitString(_ unit: String) -> HKUnit? {
        switch unit {
        // MASS
        case "g":
            return .gram()
        case "oz":
            return .ounce()
        case "lb":
            return .pound()
        case "st":
            return .stone()
        case "mcg":
            return .gramUnit(with: .micro)
        case "ng":
            return .gramUnit(with: .nano)
        case "pg":
            return .gramUnit(with: .pico)
        case "mg":
            return .gramUnit(with: .milli)
        // LENGTH
        case "m":
            return .meter()
        case "in":
            return .inch()
        case "ft":
            return .foot()
        case "yd":
            return .yard()
        case "mi":
            return .mile()
        // VOLUME
        case "L":
            return .liter()
        case "mL":
            return .literUnit(with: .milli)
        case "fl_oz_us":
            return .fluidOunceUS()
        case "fl_oz_imp":
            return .fluidOunceImperial()
        case "pt_us":
            return .pintUS()
        case "pt_imp":
            return .pintImperial()
        case "cup_us":
            return .cupUS()
        case "cup_imp":
            return .cupImperial()
        // PRESSURE
        case "Pa":
            return .pascal()
        case "mmHg":
            return .millimeterOfMercury()
        case "cmAq":
            return .centimeterOfWater()
        case "atm":
            return .atmosphere()
        case "dBASPL":
            return .decibelAWeightedSoundPressureLevel()
        case "inHg":
            if #available(iOS 14.0, *) {
                return .inchesOfMercury()
            } else {
                return nil
            }
        // TIME
        case "s":
            return .second()
        case "min":
            return .minute()
        case "hr":
            return .hour()
        case "d":
            return .day()
        // Energy
        case "J":
            return .joule()
        case "kcal":
            return .kilocalorie()
        case "cal":
            return .smallCalorie()
        case "Cal":
            return .largeCalorie()
        // TEMPERATURE
        case "degC":
            return .degreeCelsius()
        case "degF":
            return .degreeFahrenheit()
        case "K":
            return .kelvin()
        // ELECTRICAL CONDUCTANCE
        case "S":
            return .siemen()
        // PHARMACOLOGY
        case "IU":
            return .internationalUnit()
        // Scalar
        case "count":
            return .count()
        case "%":
            return .percent()
        // HEARING SENSITIVITY
        case "dBHL":
            return .decibelHearingLevel()
        // FREQUENCY
        case "Hz":
            return .hertz()
        // Electrical Potential Difference
        case "V":
            if #available(iOS 14.0, *) {
                return .volt()
            } else {
                return nil
            }
        case "cm":
            return .meterUnit(with: .centi)
        case "km":
            return .meterUnit(with: .kilo)
        // SPEED
        case "m/min":
            return HKUnit.meter().unitDivided(by: .minute())
        case "m/s":
            return HKUnit.meter().unitDivided(by: HKUnit.second())

        // HEART RATE
        case "count/min":
            return HKUnit.count().unitDivided(by: .minute())
        case "ms":
            return .secondUnit(with: .milli)
        case "mmol/L":
            let mass = HKUnitMolarMassBloodGlucose
            return HKUnit.moleUnit(with: .milli, molarMass: mass).unitDivided(by: .liter())
        //FLOW RATE
        case "L/min":
            return HKUnit.liter().unitDivided(by: .minute())
        default:
            return nil
        }
    }

    /**
     - Description: Returns the appropriate unit to use with an identifier corresponding to a HealthKit data type.
     - Parameter sample: Provide a HKSample in parameter to get it's preferred HKUnit
     - Returns: This function will return an optional HKUnit object, it could be nil if it couldn't find the HKUnit for the given sample.
     */
    public static func preferredUnit(for sample: HKSample) -> HKUnit? {
        let unit = preferredUnit(for: sample.sampleType.identifier, sampleType: sample.sampleType)
        
        if let quantitySample = sample as? HKQuantitySample, let unit = unit {
            assert(quantitySample.quantity.is(compatibleWith: unit),
                   "The preferred unit is not compatiable with this sample.")
        }
        
        return unit
    }

    /**
     - Description: Returns the appropriate unit to use with an identifier corresponding to a HealthKit data type.
     - Parameter sampleIdentifier: Provide a string of sampleIdentifier in parameter to get it's preferred HKUnit
     - Returns: This function will return an optional HKUnit, it could be nil if it couldn't find the HKUnit for the given sampleIdentifier
     */
    public static func preferredUnit(for sampleIdentifier: String) -> HKUnit? {
        return preferredUnit(for: sampleIdentifier, sampleType: nil)
    }
    
    private static func preferredUnit(for identifier: String, sampleType: HKSampleType? = nil) -> HKUnit? {
        var unit: HKUnit?
        let sampleType = sampleType ?? getSampleType(for: identifier)

        if sampleType is HKQuantityType {
            let quantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: identifier)

            if #available(iOS 14.0, *) {
                switch quantityTypeIdentifier {
                case .stepCount:
                    unit = .count()
                case .distanceWalkingRunning:
                    unit = .meter()
                case .activeEnergyBurned, .basalEnergyBurned:
                    unit = .kilocalorie()
                case .appleExerciseTime, .appleStandTime:
                    unit = .minute()
                case .basalBodyTemperature:
                    unit = .degreeFahrenheit()
                case .bloodAlcoholContent:
                    unit = .percent()
                case .bloodGlucose:
                    let mass = HKUnitMolarMassBloodGlucose
                    let mmolPerLiter = HKUnit.moleUnit(with: .milli, molarMass: mass).unitDivided(by: .liter())
                    unit = mmolPerLiter
                case .bloodPressureDiastolic:
                    unit = .millimeterOfMercury()
                case .bloodPressureSystolic:
                    unit = .millimeterOfMercury()
                case .bodyFatPercentage:
                    unit = .percent()
                case .bodyMass:
                    unit = .gram()
                case .bodyMassIndex:
                    unit = .count()
                case .bodyTemperature:
                    unit = .degreeFahrenheit()
                case .dietaryBiotin:
                    unit = .none // Need to confirm its unit
                case .dietaryCaffeine:
                    unit = HKUnit.gramUnit(with: .milli)
                case .dietaryCalcium:
                    unit = HKUnit.gramUnit(with: .milli)
                case .dietaryCarbohydrates:
                    unit = .gram()
                case .dietaryChloride:
                    unit = .gramUnit(with: .milli)
                case .dietaryCholesterol:
                    unit = .gramUnit(with: .milli)
                case .dietaryChromium:
                    unit = .gramUnit(with: .milli)
                case .dietaryCopper:
                    unit = .gramUnit(with: .micro)
                case .dietaryEnergyConsumed:
                    unit = .kilocalorie()
                case .dietaryFatTotal:
                    unit = .gram()
                case .dietaryFatPolyunsaturated:
                    unit = .gram()
                case .dietaryFatMonounsaturated:
                    unit = .gram()
                case .dietaryFatSaturated:
                    unit = .gram()
                case .dietaryFiber:
                    unit = .gram()
                case .dietaryFolate:
                    unit = .gram()
                case .dietaryIodine:
                    unit = .gramUnit(with: .micro)
                case .dietaryIron:
                    unit = .gramUnit(with: .milli)
                case .dietaryMagnesium:
                    unit = .gram()
                case .dietaryManganese:
                    unit = .gramUnit(with: .milli)
                case .dietaryMolybdenum:
                    unit = .gramUnit(with: .micro)
                case .dietaryNiacin:
                    unit = .gramUnit(with: .milli)
                case .dietaryPantothenicAcid:
                    unit = .gramUnit(with: .milli)
                case .dietaryPhosphorus:
                    unit = .gramUnit(with: .milli)
                case .dietaryPotassium:
                    unit = .gramUnit(with: .milli)
                case .dietaryProtein:
                    unit = .gram()
                case .dietaryRiboflavin:
                    unit = .gramUnit(with: .milli)
                case .dietarySelenium:
                    unit = .gramUnit(with: .micro)
                case .dietarySodium:
                    unit = .gram()
                case .dietarySugar:
                    unit = .gram()
                case .dietaryThiamin:
                    unit = HKUnit.gramUnit(with: .micro)
                case .dietaryVitaminA:
                    unit = .gramUnit(with: .micro)
                case .dietaryVitaminB12:
                    unit = HKUnit.gramUnit(with: .pico)
                case .dietaryVitaminB6:
                    unit = HKUnit.gramUnit(with: .nano)
                case .dietaryVitaminC:
                    unit = .gramUnit(with: .micro)
                case .dietaryVitaminD:
                    unit = .gramUnit(with: .micro)
                case .dietaryVitaminE:
                    unit = .gramUnit(with: .micro)
                case .dietaryVitaminK:
                    unit = .gramUnit(with: .micro)
                case .dietaryWater:
                    unit = .literUnit(with: .milli)
                case .dietaryZinc:
                    unit = .gramUnit(with: .milli)
                case .distanceCycling:
                    unit = .mile()
                case .distanceDownhillSnowSports:
                    unit = .mile()
                case .distanceSwimming:
                    unit = .mile()
                case .distanceWalkingRunning:
                    unit = .mile()
                case .distanceWheelchair:
                    unit = .mile()
                case .electrodermalActivity:
                    unit = .siemen()
                case .environmentalAudioExposure:
                    unit = .decibelAWeightedSoundPressureLevel()
                case .flightsClimbed:
                    unit = .count()
                case .forcedExpiratoryVolume1:
                    unit = .liter()
                case .forcedVitalCapacity:
                    unit = .liter()
                case .headphoneAudioExposure:
                    unit = .decibelAWeightedSoundPressureLevel()
                case .heartRate:
                    unit = HKUnit.count().unitDivided(by: .minute())
                case .heartRateVariabilitySDNN:
                    unit = .secondUnit(with: .milli)
                case .height:
                    unit = .inch()
                case .inhalerUsage:
                    unit = .count()
                case .insulinDelivery:
                    unit = .internationalUnit()
                case .leanBodyMass:
                    unit = .pound()
                case .nikeFuel:
                    unit = .count()
                case .numberOfTimesFallen:
                    unit = .count()
                case .oxygenSaturation:
                    unit = .percent()
                case .peakExpiratoryFlowRate:
                    unit = HKUnit.liter().unitDivided(by: .minute())
                case .peripheralPerfusionIndex:
                    unit = .percent()
                case .pushCount:
                    unit = .count()
                case .respiratoryRate:
                    unit = HKUnit.count().unitDivided(by: .minute())
                case .restingHeartRate:
                    unit = HKUnit.count().unitDivided(by: .minute())
                case .sixMinuteWalkTestDistance:
                    unit = .meter()
                case .stairAscentSpeed:
                    unit = HKUnit.meter().unitDivided(by: HKUnit.second())
                case .stairDescentSpeed:
                    unit = HKUnit.meter().unitDivided(by: HKUnit.second())
                case .stepCount:
                    unit = .count()
                case .swimmingStrokeCount:
                    unit = .count()
                case .uvExposure:
                    unit = .count()
                case .vo2Max:
                    let kgmin = HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute())
                    let mL = HKUnit.literUnit(with: .milli)
                    unit = mL.unitDivided(by: kgmin)
                case .waistCircumference:
                    unit = .meter()
                case .walkingAsymmetryPercentage:
                    unit = .percent()
                case .walkingDoubleSupportPercentage:
                    unit = .percent()
                case .walkingHeartRateAverage:
                    unit = HKUnit.count().unitDivided(by: .minute())
                case .walkingSpeed:
                    unit = HKUnit.meter().unitDivided(by: .minute())
                case .walkingStepLength:
                    unit = .meter()
                default:
                    break
                }
            } else {
                switch quantityTypeIdentifier {
                case .stepCount:
                    unit = .count()
                case .distanceWalkingRunning:
                    unit = .meter()
                case .activeEnergyBurned, .basalEnergyBurned:
                    unit = .kilocalorie()
                case .appleExerciseTime, .appleStandTime:
                    unit = .minute()
                case .basalBodyTemperature:
                    unit = .degreeFahrenheit()
                case .bloodAlcoholContent:
                    unit = .percent()
                case .bloodGlucose:
                    let mass = HKUnitMolarMassBloodGlucose
                    let mmolPerLiter = HKUnit.moleUnit(with: .milli, molarMass: mass).unitDivided(by: .liter())
                    unit = mmolPerLiter
                case .bloodPressureDiastolic:
                    unit = .millimeterOfMercury()
                case .bloodPressureSystolic:
                    unit = .millimeterOfMercury()
                case .bodyFatPercentage:
                    unit = .percent()
                case .bodyMass:
                    unit = .gramUnit(with: .kilo)
                case .bodyMassIndex:
                    unit = .count()
                case .bodyTemperature:
                    unit = .degreeFahrenheit()
                case .dietaryBiotin:
                    unit = .none // Need to confirm its unit
                case .dietaryCaffeine:
                    unit = HKUnit.gramUnit(with: .milli)
                case .dietaryCalcium:
                    unit = HKUnit.gramUnit(with: .milli)
                case .dietaryCarbohydrates:
                    unit = .gram()
                case .dietaryChloride:
                    unit = .gramUnit(with: .milli)
                case .dietaryCholesterol:
                    unit = .gramUnit(with: .milli)
                case .dietaryChromium:
                    unit = .gramUnit(with: .milli)
                case .dietaryCopper:
                    unit = .gramUnit(with: .micro)
                case .dietaryEnergyConsumed:
                    unit = .kilocalorie()
                case .dietaryFatTotal:
                    unit = .gram()
                case .dietaryFatPolyunsaturated:
                    unit = .gram()
                case .dietaryFatMonounsaturated:
                    unit = .gram()
                case .dietaryFatSaturated:
                    unit = .gram()
                case .dietaryFiber:
                    unit = .gram()
                case .dietaryFolate:
                    unit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .milli))
                case .dietaryIodine:
                    unit = .gramUnit(with: .micro)
                case .dietaryIron:
                    unit = .gramUnit(with: .milli)
                case .dietaryMagnesium:
                    unit = .gram()
                case .dietaryManganese:
                    unit = .gramUnit(with: .milli)
                case .dietaryMolybdenum:
                    unit = .gramUnit(with: .micro)
                case .dietaryNiacin:
                    unit = .gramUnit(with: .milli)
                case .dietaryPantothenicAcid:
                    unit = .gramUnit(with: .milli)
                case .dietaryPhosphorus:
                    unit = .gramUnit(with: .milli)
                case .dietaryPotassium:
                    unit = .gramUnit(with: .milli)
                case .dietaryProtein:
                    unit = .gram()
                case .dietaryRiboflavin:
                    unit = .gramUnit(with: .milli)
                case .dietarySelenium:
                    unit = .gramUnit(with: .micro)
                case .dietarySodium:
                    unit = .gram()
                case .dietarySugar:
                    unit = .gram()
                case .dietaryThiamin:
                    unit = HKUnit.gramUnit(with: .micro)
                case .dietaryVitaminA:
                    unit = .gramUnit(with: .micro)
                case .dietaryVitaminB12:
                    unit = HKUnit.gramUnit(with: .pico)
                case .dietaryVitaminB6:
                    unit = HKUnit.gramUnit(with: .nano)
                case .dietaryVitaminC:
                    unit = .gramUnit(with: .micro)
                case .dietaryVitaminD:
                    unit = .gramUnit(with: .micro)
                case .dietaryVitaminE:
                    unit = .gramUnit(with: .micro)
                case .dietaryVitaminK:
                    unit = .gramUnit(with: .micro)
                case .dietaryWater:
                    unit = .literUnit(with: .milli)
                case .dietaryZinc:
                    unit = .gramUnit(with: .milli)
                case .distanceCycling:
                    unit = .mile()
                case .distanceDownhillSnowSports:
                    unit = .mile()
                case .distanceSwimming:
                    unit = .mile()
                case .distanceWalkingRunning:
                    unit = .mile()
                case .distanceWheelchair:
                    unit = .mile()
                case .electrodermalActivity:
                    unit = .siemen()
                case .environmentalAudioExposure:
                    unit = .decibelAWeightedSoundPressureLevel()
                case .flightsClimbed:
                    unit = .count()
                case .forcedExpiratoryVolume1:
                    unit = .liter()
                case .forcedVitalCapacity:
                    unit = .liter()
                case .headphoneAudioExposure:
                    unit = .decibelAWeightedSoundPressureLevel()
                case .heartRate:
                    unit = HKUnit.count().unitDivided(by: .minute())
                case .heartRateVariabilitySDNN:
                    unit = .secondUnit(with: .milli)
                case .height:
                    unit = .inch()
                case .inhalerUsage:
                    unit = .count()
                case .insulinDelivery:
                    unit = .internationalUnit()
                case .leanBodyMass:
                    unit = .pound()
                case .nikeFuel:
                    unit = .count()
                case .numberOfTimesFallen:
                    unit = .count()
                case .oxygenSaturation:
                    unit = .percent()
                case .peakExpiratoryFlowRate:
                    unit = HKUnit.liter().unitDivided(by: .minute())
                case .peripheralPerfusionIndex:
                    unit = .percent()
                case .pushCount:
                    unit = .count()
                case .respiratoryRate:
                    unit = HKUnit.count().unitDivided(by: .minute())
                case .restingHeartRate:
                    unit = HKUnit.count().unitDivided(by: .minute())
                case .stepCount:
                    unit = .count()
                case .swimmingStrokeCount:
                    unit = .count()
                case .uvExposure:
                    unit = .count()
                case .vo2Max:
                    let kgmin = HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute())
                    let mL = HKUnit.literUnit(with: .milli)
                    unit = mL.unitDivided(by: kgmin)
                case .waistCircumference:
                    unit = .meter()
                case .walkingHeartRateAverage:
                    unit = HKUnit.count().unitDivided(by: .minute())
                default:
                    break
                }
            }
        }
        
        return unit
    }
    
    /**
     - Description: Return an HKSampleType based on the input identifier that corresponds to an HKQuantityTypeIdentifier, HKCategoryTypeIdentifier or other valid HealthKit identifier. Returns nil otherwise.
     - Parameter identifier: Identifier string to get it's corresponding HKSampletype
     - Returns: It will return an HKSampleType object, which is an optional value and could be nil.
     */
    public static func getSampleType(for identifier: String) -> HKSampleType? {
        if let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier)) {
            return quantityType
        }
        
        if let categoryType = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: identifier)) {
            return categoryType
        }
        
        if let correlationType = HKCorrelationType.correlationType(forIdentifier: HKCorrelationTypeIdentifier(rawValue: identifier)) {
            return correlationType
        }
        
        return nil
    }
    
    // MARK: - Query Support

    /**
     - Description: Return an anchor date for a statistics collection query.
     - Returns: This function will return an Date object
     */
    public static func createAnchorDate() -> Date {
        // Set the arbitrary anchor date to Monday at 3:00 a.m.
        let calendar: Calendar = .current
        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())
        let offset = (7 + (anchorComponents.weekday ?? 0) - 2) % 7
        
        anchorComponents.day! -= offset
        anchorComponents.hour = 3
        
        let anchorDate = calendar.date(from: anchorComponents)!
        
        return anchorDate
    }

    /**
     - Description: This is commonly used for date intervals so that we get the last seven days worth of data, Because we assume today (`Date()`) is providing data as well.
     - Parameter date: Provide a date for which you want the last date of the week. By default is current Date if not provided in the parameter.
     - Returns: This function will return a Date object.
     */
    public static func getLastWeekStartDate(from date: Date = Date()) -> Date {
        return Calendar.current.date(byAdding: .day, value: -6, to: date)!
    }

    /**
     - Description: This will create a last week predicate from the given endDate.
     - Parameter endDate: Provide a date for which you want the last week predicate. By default is current date if not provided in the parameter.
     - Returns: It will return a NDPredicate object.
     */
    public static func createLastWeekPredicate(from endDate: Date = Date()) -> NSPredicate {
        let startDate = getLastWeekStartDate(from: endDate)
        return HKQuery.predicateForSamples(withStart: startDate, end: endDate)
    }

    /**
     - Description: Return the most preferred `HKStatisticsOptions` for a data type identifier. Default to `.discreteAverage`.
     - Parameter dataTypeIdentifier: Provide a dataTypeIdentifier as parameter to get HKStatisticsOptions.
     - Returns: It will return an HKStatisticsOptions.
     */
    public static func getStatisticsOptions(for dataTypeIdentifier: String) -> HKStatisticsOptions {
        var options: HKStatisticsOptions = .discreteAverage
        let sampleType = getSampleType(for: dataTypeIdentifier)
        
        if sampleType is HKQuantityType {
            let quantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: dataTypeIdentifier)
            
            if #available(iOS 14.0, *) {
                switch quantityTypeIdentifier {
                case .stepCount, .distanceWalkingRunning:
                    options = .cumulativeSum
                case .sixMinuteWalkTestDistance:
                    options = .discreteAverage
                default:
                    break
                }
            } else {
                switch quantityTypeIdentifier {
                case .stepCount, .distanceWalkingRunning:
                    options = .cumulativeSum
                default:
                    break
                }
            }
        }
        
        return options
    }

    /**
     - Description: Returns the statistics value in `statistics` based on the desired `statisticsOption`
     - Parameter statistics: This function requires HKStatistics as parameter.
     - Parameter statisticsOptions: This function also required a HKStatisticsOptions as parameter.
     - Returns: This function will return a optional HKQuantity object.
     */
    public static func getStatisticsQuantity(for statistics: HKStatistics, with statisticsOptions: HKStatisticsOptions) -> HKQuantity? {
        var statisticsQuantity: HKQuantity?
        
        switch statisticsOptions {
        case .cumulativeSum:
            statisticsQuantity = statistics.sumQuantity()
        case .discreteAverage:
            statisticsQuantity = statistics.averageQuantity()
        default:
            break
        }
        
        return statisticsQuantity
    }

}
#endif
