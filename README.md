# OTFCloudantStore

TheraForge's OTFCloudantStore uses OTFCDTDatastore to store, index and query local JSON data. Synchronisation is under
the control of the application. OTFCloudantStore manages and resolves the conflicts locally on the device or on the remote database.
OTFCloudantStore is an interface between the OTFCarekit, HealthKit and OTFCDTDatastore frameworks.

## TheraForge Frameworks
* [OTFToolBox](../../../OTFToolBox)
* [OTFTemplateBox](../../../OTFTemplateBox)
* [OTFCareKit](../../../OTFCareKit)
* [OTFCDTDatastore](../../../OTFCDTDatastore)
* [OTFCloudClientAPI](../../../OTFCloudClientAPI)

## Change Log
<details open>
  <summary>Release 1.0.3-beta</summary>
  <ul>
    <li>Added Watch OS support</li>
  </ul>
</details>

<details>
<summary>Release 1.0.1-beta</summary>
<ul>
<li>Removed various warnings. Filter outcome result set based on the date interval.</li>
</ul>
</details>

<details>
<summary>Release 1.0.0-beta</summary>
<ul>
<li>First beta release of the framework</li>
</ul>
</details>


## Table of contents
* [Requirements](#Requirements)
* [Installation](#Installation)
* [Usage](#Usage)
* [Overview of the Library](#Overview-of-the-library)
  * [OTFCloudantRevision](#OTFCloudantRevision)
  * [OTFCloudantQuery](#OTFCloudantQuery)
  * [OTFCloudantQueryComponents](#OTFCloudantQueryComponents)
* [Healthkit Integration](#Healthkit-Integration)
* [CareKit Integration](#CareKit-Integration)
* [License](#License)


## Requirements <a name="Requirements"></a>
The OTFCloudantStore framework codebase supports iOS and requires Xcode 12.0 or newer.

## Installation <a name="Installation"></a>
OTFCloudantStore is available through [CocoaPods](http://cocoapods.org).  In your Xcode project folder open the Podfile and write the below line under target.

```ruby
pod "OTFCloudantStore"
```
With this pod installation you get CDTDDataStore and OTFCareKit as a dependency.

## Usage <a name="Usage"></a>

```swift
import OTFCloudantStore
let store = OTFCloudantStore(storeName: “your store name”)
```

## Overview of the Library <a name="Overview-of-the-library"></a>

### OTFCloudantRevision <a name="OTFCloudantRevision"></a>

In an application when you use distributed databases, copies of your data might be stored in multiple locations. The copies of a data might have different updates because of which "Conflicts" occur and IBM Cloud can't determine which copy is the correct one.
Keeping this data in sync is important that is where  `OTFCloudantRevision`  solves this problem of confilicts. The `OTFCloudantRevision` make sure that every Entity has revision id in order to serve the [MVCC](https://en.wikipedia.org/wiki/Multiversion_concurrency_control).

Use the following add, update, delete, and get data functions to modify your data into the store, your class must conform to the `Codable`, `Identifiable` and `OTFCloudantRevision`.

```swift
add<Entity: Codable & Identifiable & OTFCloudantRevision>(_ items: [Entity], callbackQueue: DispatchQueue = .main, completion: ((Result<[Entity], OTFCloudantError>) -> Void)?)
```
```swift
get<Entity: Codable & Identifier & OTFCloudantRevision>(callbackQueue: DispatchQueue = .main, completion: @escaping (Result<[Entity], OTFCloudantError>) -> Void)
``` 
```swift
update<Entity: Codable & Identifiable & OTFCloudantRevision>(_ items: [Entity], callbackQueue: DispatchQueue = .main, completion: ((Result<[Entity], OTFCloudantError>) -> Void)?)
```
```swift
delete<Entity: Codable & Identifiable & OTFCloudantRevision>(_ items: [Entity], callbackQueue: DispatchQueue = .main, completion: ((Result<[Entity], OTFCloudantError>) -> Void)?)
```
### OTFCloudantQuery <a name="OTFCloudantQuery"></a>
IBM® [Cloudant®](https://cloudant.com) for IBM Cloud Query is a declarative JSON querying syntax for IBM Cloudant databases. IBM Cloudant Query uses two types of indexes: json and text.
If you know exactly what data you want to look for, or you want to keep storage and processing requirements to a minimum, you can specify how the index is created by making it of type json.
But for maximum flexibility when you search for data, you typically create an index of type text. Indexes of type text have a simple mechanism for automatically indexing all the fields in the documents.
OTFCloudantQuery filters and sorts the data, It can be used to order a collection of data by some fields which are indexes, if the field is not index, the result will be empty array.

```swift
let query = store.collection(className, fields: [String]?) -> OTFCloudantQuery 
```

```swift
query.where(propertyName: propertyName, value: theFilter) -> OTFCloudantQuery
```

#### Sorting

Theraforge OTFCloudantStore provides sorting fucntionality for the given property. To sort any property ensure that the following are true:
- At least one of the sort field is included in the selector.
- An index is already defined, with all the sort fields in the same order.
- Each object in the sort array has a single key.

```swift
Ascending: query.sort(ascending: propertyName) -> OTFCloudantQuery
Descending: query.sort(descending: propertyName) -> OTFCloudantQuery
```
```
Note: the propertyName should be an index, if not, the result will be an empty array.
```

### OTFCloudantQueryComponents <a name="OTFCloudantQueryComponents"></a>

The OTFCloudantQueryComponents are used to query with single field or combined query with multiple fields to get the compared result from the store. 
 
```swift
Example
    The query: where the title is equal to “Family Practice Doctor” will be translated into OTFCloudantQueryComponent like:
    let query = OTFCloudantQueryComponent.simpleComponent(field: “title”, comparisionOperator: .equal, value: “Family Practice Doctor”, )
    The query: where the age is less than 20 will be translated into OTFCloudantQueryComponent like
    let query = OTFCloudantQueryComponent.simpleComponent(field: “age”, value: 20, comparisionOperator: .lessThan)
    The query: where the age is in [15,20,30] will be translated into OTFCloudantQueryComponent like
    let query = OTFCloudantQueryComponent.simpleComponent(field: “age”, comparisionOperator: .in, value: [15,20,30])
```
`field`: the name of the field which is used to query.

`comparisionOperator`:  the operator which is used for condition check.

`value`: the value which is used to filter - type Any.

##### OTFCloudantCombinationQueryComponent
This query component builds a combined query from two  `OTFCloudantQueryComponents`. 

```swift
Example
    The query: where the title is equal to “Family Practice Doctor” and age is in [15,20,30] will be translated to:
    let leftComponent = OTFCloudantQueryComponent.simpleComponent(field: “title”, comparisionOperator: .equal, value: “Family Practice Doctor”)
    let rightComponent = OTFCloudantQueryComponent.simpleComponent(field: “age”, comparisionOperator: .in, value: [15,20,30])
    let combinedQuery = OTFCloudantCombinationQueryComponent.combinedQueryComponent(leftComponent: leftComponent, combinationSelector: .and, rightComponent: rightComponent)
```
`leftComponent`: type OTFCloudantQueryComponent, which is presenting for the first condition check.

`rightComponent`: type OTFCloudantQueryComponent, which is presenting for the second condition check.

`combinationSelector`: type OTFCloudantCombinationSelector which is use to combine two queries (and / or).

##### OTFCloudantComplexQueryComponent
This query component builds a complex query from two  `OTFCloudantCombinationQueryComponents`. 

```swift
Example
    The query: where the title is equal to “Family Practice Doctor” and age is in [15,20,30] or title is equal to “Test” and age is less than 30 will be translated to:
    let leftComponentFirstQuery = OTFCloudantQueryComponent.simpleComponent(field: “title”, comparisionOperator: .equal, value: “Family Practice Doctor”)
    let rightComponentFirstQuery = OTFCloudantQueryComponent.simpleComponent(field: “age”, comparisionOperator: .in, value: [15,20,30])
    let firstCombinedQuery = OTFCloudantCombinationQueryComponent.combinedQueryComponent(leftComponent: leftComponentFirstQuery, combinationSelector: .and, rightComponent: rightComponentFirstQuery)
    let leftComponentSecondQuery = OTFCloudantQueryComponent.simpleComponent(field: “title”, comparisionOperator: .equal, value: “Test”)
    let rightComponentSecondQuery = OTFCloudantQueryComponent.simpleComponent(field: “age”, comparisionOperator: .lessThan, value: 30)
    let secondCombinedQuery = OTFCloudantCombinationQueryComponent.combinedQueryComponent(leftComponent: leftComponentSecondQuery, combinationSelector: .or, rightComponent: rightComponentSecondQuery)
    let complexQuery = OTFCloudantComplexQueryComponent.complexQueryComponent(leftComponent: leftComponentSecondQuery, combinationSelector: .or, rightComponent: rightComponentSecondQuery)
```
`leftComponent`: OTFCloudantCombinationQueryComponent which is created by combining 2 OTFCloudantQueryComponents.

`rightComponent`: OTFCloudantCombinationQueryComponent which is created by combining 2 OTFCloudantQueryComponents.

`combinationSelector`: type OTFCloudantCombinationSelector which is used to combine two combined queries, which is or by default.

**Short Query**
```swift
Example:
    dataStore.collection(name: “OCKContact”).where(.simpleComponent(“title”, .equal, “Family Practice Doctor”), .and, .simpleComponent(“effectiveDate”, .greaterThan, “2020-11-27T23:00:00Z”)).get{}
```


## Healthkit Integration <a name="Healthkit-Integration"></a>
The TheraForge OTFCloudantStore supports to save and distribute most health and fitness data from Apple [HealthKit](https://developer.apple.com/documentation/healthkit).
The OTFCloudantStore provides `OTFCloudantSample` which will map the data from HealthKit’s entities and also helps on parsing data back to HealthKit’s entities.

The OTFCloudantStore stores following different types of data:
+ HKCategorySample
+ HKQuantitySample 
+ HKCorrelation
+ HKCDADocumentSample
+ HKWorkoutRoute
+ HKWorkout

* Get samples from OTFCloudantStore
- When will we do it?
     When we want to sync data from CloudantStore to new devices
- How do we do it?
 Query samples from OTFCloudantStore based on the sample’s type (OTFHealthSampleType), use built-in query:
 + Use function to create query
```swift
public func collection(healthKitSampleType: OTFHealthSampleType, fields: [String]? = nil) -> OTFCloudantQuery
```
+ Then query data from the cloudantStore using 
```swift
public func getSamples(callbackQueue: DispatchQueue = .main, completion: @escaping (Result<[HKSample], OTFCloudantError>) -> Void)
```
+ Call save function of HealthKitStore to add those samples into OTFCloudantStore 
- Example
```swift
Future<[HKSample], Never> { promise in
    cloudantStore.collection(healthKitSampleType: .quantity).getSamples { result in
        promise(.success((try? result.get()) ?? []))
    }
}
```
#### Syncing data bidirectionally
- When do we use it?
When we want to sync data from cloudantStore to new devices which may or may not have had samples stored in HealthKitStore already
- How do we use it?
We provide OTFHealthKitSynchronizer which is used to sync data between OTFCloudantStore and HealthKitStore
The init function of OTFHealthKitSynchronizer accept two parameters: instance of OTFCloudantStore and instance of HKHealthStore
In order to start to sync data between HealthKitStore and CloudantStore, we just need to call function:
```swift
public func syncWithHealthKit()
```

#### OTFCloudantError
OTFCloudantError can be thrown in CRDU and synchronization when a failure occurs while performing the actions. 
```swift
public enum OTFCloudantError: LocalizedError {
    /// Occurs when a fetch fails.
    case fetchFailed(reason: String)

    /// Occurs when adding an entity fails.
    case addFailed(reason: String)

    /// Occurs when an update to an existing entity fails.
    case updateFailed(reason: String)

    /// Occurs when deleting an existing entity fails.
    case deleteFailed(reason: String)

    /// Occurs when synchronization with a remote server fails.
    case remoteSynchronizationFailed(reason: String)

    /// Occurs when an invalid value is provided.
    case invalidValue(reason: String)

    /// Occurs when an asynchronous action takes too long.
    /// - Note: This is intended for use by remote databases.
    case timedOut(reason: String)
}
```

## CareKit Integration <a name="CareKit-Integration"></a>
The Theraforge OTFCloudantStore supports to save and distribute data from Apple [CareKit](https://developer.apple.com/documentation/carekit).
The OTFCloudantStore performs Add, update, delete, and fetch data from the store for the various CareKit data models. 

The OTFCloudantStore provides integration support for following set of data models:
+ OCKTask
+ OCKContact 
+ OCKCarePlan
+ OCKPatient 
+ OCKOutcome


## Swift Compilation Flags
As of Xcode 8, we have the new SWIFT_ACTIVE_COMPILATION_CONDITIONS build setting which allows us to degine our flags without the need to prefix them. Under the hood, each element is passed to 'swiftc' prefixed with -D ! This matches the behaviour we had with Objective-C and Preprocessor.

In OTFCloudantStore we've provided some custom flags that users can use to decide which frameworks he/she want's to use in their projects. They can decide between below given custom build configurations - 



**CloudantOnly** - This is the most basic configuration that user can use in their project. It will install only few framework dependencies and they are only allowed to use them through OTFCloudantStore framework. You need to install this cocoapod by defining - `'pod OTFCloudantStore/CloudantOnly'` in their podfile. It will install 'OTFCloudClientAPI', 'OTFCDTDatastore' external dependencies along with OTFCloudantStore.

**CloudantCare** - If user want to use the OTFCareKit framework and it's related functions and operations in OTFCloudantStore, User need to use `'pod OTFCloudantStore/CloudantCare'` in their podfile. It will install 'OTFCareKit (without HealthKit support)', 'OTFCDTDatastore', 'OTFResearchKit (without HealthKit support)', 'OTFCloudClientAPI' external dependencies along with OTFCloudantStore.

**CloudantCareHealth** - If user wants to use the OTFCareKit and HealthKit framework and their related functions, operations in OTFCloudantStore, then user need to use `'pod OTFCloudantStore/CloudantCareHealth'` in their podfile. It will install 'OTFCareKit (with HealthKit support)', 'OTFCDTDatastore', 'OTFResearchKit (with HealthKit support)' and 'OTFCloudClientAPI' external dependencies along with OTFCloudantStore.

**CloudantHealth** - If user wants to use the HealthKit framework and it's related functions and operations only in OTFCloudantStore. Then user need to use `'pod OTFCloudantStore/CloudantHealth'` in their podfile. It will install 'OTFCDTDatastore' and 'OTFCloudClientAPI' external dependencies as well along with OTFCloudantStore.

 
 By using these pods user can have a control over the frameworks that he/she wants to install according to their need. He don't have to specify these flags anywhere as everything is done already in the code. He/she just need to figure out which framework configuration (from the above 4 configurations) best suites to his requirement and simply install it in his project. 
 For example - If user want's to use OTFCareKit framework in his project but he don't wants to use HealthKit as it may cause a rejection on Appstore if he is not actually using any HealthKit related code but still importing HealthKit. So he can use `pod OTFCloudantStore/CloudantCare`. It will not allow app to import HealthKit or use it's code.
 
 
 ## License <a name="License"></a>

This project is made available under the terms of a modified BSD license. See the [LICENSE](LICENSE.md) file.
