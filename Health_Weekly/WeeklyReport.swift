//
//  WeeklyReport.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import Foundation

struct WeeklyReport: Codable {
    
    // MARK: - Time
    let year: Int
    let week: Int

    // MARK: - VO2max
    let vo2maxMean: Double?
    let vo2maxLast: Double?

    // MARK: - Heart
    let restingHR: Double?

    // MARK: - Energy
    let activeKcal: Int

    // MARK: - Workout
    let workoutHRMean: Double?
    let workoutHRMax: Double?
    let minutesHigh: Double
    let verdict: String
    
    // MARK: - Steps
    let stepsWeeklyTotal: Int
    let stepsDailyAverage: Int
}
