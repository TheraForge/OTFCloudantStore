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

import UIKit

/**
 OTFCloudantQueryComponents are used to create query with single field or combined query with multiple fields
 */
public enum OTFCloudantConditionSelector: String {
    case lessThan = "$lt"
    case lessThanOrEqual = "$lte"
    case equal = "$eq"
    case greaterThanOrEqual = "$gte"
    case greaterThan = "$gt"
    case notEqualTo = "$ne"
    case regex = "$regex"
    case exists = "$exists"
    case mod = "$mod"
    case size = "$size"
    case `in` = "$in"
    case notIn = "$nin"
}

public enum OTFCloudantCombinationSelector: String {
    case and = "$and"
    case or = "$or"
}

/*
 OTFCloudantQueryComponent is used to create single query from 1 field and It's condition
 Params:
 - fieldValue: The name of the field which is used to query
 - comparingValue: the value which is used for the comparison, It could be Bool, String or Number, etc
 - conditionSelector: the condition of the query
 The OTFCloudantQueryComponent will be translated to:
 get from the store where `fieldValue` `conditionSelector` `comparingValue`
 For example: get from the store where `name` `equal to` `"Name"`
 */
public struct OTFCloudantQueryComponent {
    public var fieldValue: String?
    public var comparingValue: Any?
    public var conditionSelector: OTFCloudantConditionSelector = .equal

    init(field: String, value: Any, comparitionOperator: OTFCloudantConditionSelector = .equal) {
        fieldValue = field
        comparingValue = value
        conditionSelector = comparitionOperator
    }

    public static func simpleComponent(_ field: String, _ comparitionOperator: OTFCloudantConditionSelector = .equal, _ value: Any) -> OTFCloudantQueryComponent {
        return .init(field: field, value: value, comparitionOperator: comparitionOperator)
    }

    public func toQuery() -> [String: Any] {
        guard let field = fieldValue, let comparingValue = comparingValue else { return [:] }
        return [field: [conditionSelector.rawValue: comparingValue]]
    }
}

/*
 OTFCloudantCombinationQueryComponent is used to create combined query from 2 OTFCloudantQueryComponents
 Params:
 - leftComponent: the first single query
 - rightComponent: the second single query
 - combinationSelector: the combination selector for two queries
 The OTFCloudantCombinationQueryComponent will be translated to:
 get from the store where (`leftComponent.fieldValue` `leftComponent.conditionSelector` `leftComponent.comparingValue`) `combinationSelector` (`rightComponent.fieldValue` `rightComponent.conditionSelector` `rightComponent.comparingValue`)
 For example: get from the store where `name` `equal to` `"Name"`
 */
public struct OTFCloudantCombinationQueryComponent {
    public var leftComponent: OTFCloudantQueryComponent?
    public var rightComponent: OTFCloudantQueryComponent?
    public var combinationSelector: OTFCloudantCombinationSelector = .and

    init(leftComponent: OTFCloudantQueryComponent, rightComponent: OTFCloudantQueryComponent, combinationSelector: OTFCloudantCombinationSelector = .and) {
        self.leftComponent = leftComponent
        self.rightComponent = rightComponent
        self.combinationSelector = combinationSelector
    }

    public static func combinedQueryComponent(_ leftComponent: OTFCloudantQueryComponent, _ combinationSelector: OTFCloudantCombinationSelector, _ rightComponent: OTFCloudantQueryComponent) -> OTFCloudantCombinationQueryComponent {
        return .init(leftComponent: leftComponent, rightComponent: rightComponent, combinationSelector: combinationSelector)
    }

    public func toQuery() -> [String: Any] {
        guard let leftComponent = self.leftComponent, let rightComponent = self.rightComponent else { return [:] }
        return [combinationSelector.rawValue: [leftComponent.toQuery(), rightComponent.toQuery()]]
    }
}

public struct OTFCloudantComplexQueryComponent {
    public var leftComponent: OTFCloudantCombinationQueryComponent?
    public var rightComponent: OTFCloudantCombinationQueryComponent?
    public var combinationSelector: OTFCloudantCombinationSelector = .and

    init(leftComponent: OTFCloudantCombinationQueryComponent, rightComponent: OTFCloudantCombinationQueryComponent, combinationSelector: OTFCloudantCombinationSelector = .and) {
        self.leftComponent = leftComponent
        self.rightComponent = rightComponent
        self.combinationSelector = combinationSelector
    }

    public static func complexQueryComponent(_ leftComponent: OTFCloudantCombinationQueryComponent, _ combinationSelector: OTFCloudantCombinationSelector, _ rightComponent: OTFCloudantCombinationQueryComponent) -> OTFCloudantComplexQueryComponent {
        return .init(leftComponent: leftComponent, rightComponent: rightComponent, combinationSelector: combinationSelector)
    }

    public func toQuery() -> [String: Any] {
        guard let leftComponent = self.leftComponent, let rightComponent = self.rightComponent else { return [:] }
        return [combinationSelector.rawValue: [leftComponent.toQuery(), rightComponent.toQuery()]]
    }
}
