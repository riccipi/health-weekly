//
//  HealthKitManager.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//
import HealthKit

let AGE = 29
let HR_MAX = 220.0 - Double(AGE)
let HR_THRESHOLD = HR_MAX * 0.85

final class HealthKitManager {
    let store = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false); return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]

        store.requestAuthorization(toShare: [], read: readTypes) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
    
    func fetchRestingHRThisWeek(
        start: Date,
        end: Date,
        completion: @escaping (Double?) -> Void
    ) {

        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in

            guard let samples = samples as? [HKQuantitySample],
                  !samples.isEmpty else {
                completion(nil)
                return
            }

            let values = samples.map {
                $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }

            let avg = values.reduce(0, +) / Double(values.count)
            completion(avg)
        }

        store.execute(query)
    }
    
    func fetchWorkoutsThisWeek(
        start: Date,
        end: Date,
        completion: @escaping ([HKWorkout]) -> Void
    ) {

        let type = HKObjectType.workoutType()

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in

            completion(samples as? [HKWorkout] ?? [])
        }

        store.execute(query)
    }

    func verdict(minutesHigh: Double, hrMax: Double?) -> String {
        if minutesHigh >= 10 { return "Allenante" }
        if let m = hrMax, m >= HR_MAX * 0.9 { return "Allenante" }
        if hrMax != nil { return "Neutra" }
        return "Sprecata"
    }

    func analyzeWorkoutHR(
        workouts: [HKWorkout],
        completion: @escaping (_ hrMean: Double?, _ hrMax: Double?, _ minutesHigh: Double) -> Void
    ) {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let group = DispatchGroup()

        var allValues: [Double] = []
        var highZoneCount = 0

        for w in workouts {
            group.enter()

            let predicate = HKQuery.predicateForSamples(
                withStart: w.startDate,
                end: w.endDate
            )

            let q = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let values = (samples as? [HKQuantitySample])?.map {
                    $0.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                } ?? []

                allValues.append(contentsOf: values)
                highZoneCount += values.filter { $0 >= HR_THRESHOLD }.count

                group.leave()
            }

            store.execute(q)
        }

        group.notify(queue: .main) {
        
            guard !allValues.isEmpty else {
                completion(nil, nil, 0)
                return
            }

            let mean = allValues.reduce(0,+) / Double(allValues.count)
            let max = allValues.max()!
            let minutesHigh = Double(highZoneCount) / 60.0

            completion(mean, max, minutesHigh)
        }
    }

}

extension HealthKitManager {

    func isoWeekRange(for date: Date) -> (start: Date, end: Date) {
        let cal = Calendar(identifier: .iso8601)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = cal.date(from: comps)!
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        return (start, end)
    }
}

extension HealthKitManager {

    func fetchVO2MaxThisWeek(
        start: Date,
        end: Date,
        completion: @escaping (Double?, Double?) -> Void
    ) {
        let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max)!
        let range = isoWeekRange(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let q = HKSampleQuery(sampleType: vo2, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map {
                $0.quantity.doubleValue(for: .init(from: "ml/kg*min"))
            } ?? []

            let mean = values.isEmpty ? nil : values.reduce(0,+) / Double(values.count)
            let last = values.last

            DispatchQueue.main.async { completion(mean, last) }
        }
        store.execute(q)
    }
    
    func fetchWeeklySteps(
        start: Date,
        end: Date,
        completion: @escaping (Int) -> Void
    ) {

        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in

            let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            completion(Int(sum))
        }

        store.execute(query)
    }
}

extension HealthKitManager {

    func fetchActiveKcalThisWeek(
        start: Date,
        end: Date,
        completion: @escaping (Double) -> Void
    ) {

        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(0)
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in

            let sum = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            completion(sum)
        }

        store.execute(query)
    }
}

extension HealthKitManager {
    func fetchRecentWorkouts(
        limit: Int = 5,
        completion: @escaping ([HKWorkout]) -> Void
    ) {
        
        let type = HKObjectType.workoutType()
        
        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: limit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            
            completion(samples as? [HKWorkout] ?? [])
        }
        
        store.execute(query)
    }
}

extension HealthKitManager {
    func fetchHeartRateForWorkout(
        workout: HKWorkout,
        completion: @escaping ([(date: Date, bpm: Double)]) -> Void
    ) {
        
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            
            guard let samples = samples as? [HKQuantitySample] else {
                completion([])
                return
            }
            
            let results = samples.map {
                (
                    date: $0.startDate,
                    bpm: $0.quantity.doubleValue(
                        for: HKUnit.count().unitDivided(by: .minute())
                    )
                )
            }
            
            completion(results)
        }
        
        store.execute(query)
    }
}

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining: return "Strength"
        default: return "Other"
        }
    }
}
