//
//  WeeklyReport.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import Foundation

struct WeeklyReport: Codable {

    let stepsWeeklyTotal: Int
    let stepsDailyAverage: Int

    let year: Int
    let week: Int

    let vo2maxMean: Double?
    let vo2maxLast: Double?

    let restingHR: Double?
    let activeKcal: Int

    let workoutHRMean: Double?
    let workoutHRMax: Double?
    let minutesHigh: Double
    let verdict: String

    init(
        stepsWeeklyTotal: Int,
        stepsDailyAverage: Int,
        year: Int,
        week: Int,
        vo2maxMean: Double?,
        vo2maxLast: Double?,
        restingHR: Double?,
        activeKcal: Int,
        workoutHRMean: Double?,
        workoutHRMax: Double?,
        minutesHigh: Double,
        verdict: String
    ) {
        self.stepsWeeklyTotal = stepsWeeklyTotal
        self.stepsDailyAverage = stepsDailyAverage
        self.year = year
        self.week = week
        self.vo2maxMean = vo2maxMean
        self.vo2maxLast = vo2maxLast
        self.restingHR = restingHR
        self.activeKcal = activeKcal
        self.workoutHRMean = workoutHRMean
        self.workoutHRMax = workoutHRMax
        self.minutesHigh = minutesHigh
        self.verdict = verdict
    }
}
