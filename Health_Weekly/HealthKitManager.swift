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
    
    func fetchRestingHRThisWeek(completion: @escaping (Double?) -> Void) {
        let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let range = isoWeekRange(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end)

        let q = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map {
                $0.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            } ?? []

            let mean = values.isEmpty ? nil : values.reduce(0,+) / Double(values.count)
            DispatchQueue.main.async { completion(mean) }
        }

        store.execute(q)
    }

    func fetchWorkoutsThisWeek(completion: @escaping ([HKWorkout]) -> Void) {
        let type = HKObjectType.workoutType()
        let range = isoWeekRange(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end)

        let q = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in
            DispatchQueue.main.async {
                completion(samples as? [HKWorkout] ?? [])
            }
        }

        store.execute(q)
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

    func fetchVO2MaxThisWeek(completion: @escaping (Double?, Double?) -> Void) {
        let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max)!
        let range = isoWeekRange(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end)

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
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let total = result?
                .sumQuantity()?
                .doubleValue(for: HKUnit.count()) ?? 0

            completion(Int(total))
        }

        store.execute(query)
    }
}

extension HealthKitManager {

    func fetchActiveKcalThisWeek(completion: @escaping (Double) -> Void) {
        let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let range = isoWeekRange(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end)

        let q = HKStatisticsQuery(quantityType: energy,
                                  quantitySamplePredicate: predicate,
                                  options: .cumulativeSum) { _, stats, _ in
            let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            DispatchQueue.main.async { completion(kcal) }
        }
        store.execute(q)
    }
}

