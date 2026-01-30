//
//  WeeklyReportBuilder.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import Foundation

func buildWeeklyReport(completion: @escaping (WeeklyReport) -> Void) {

    let hk = HealthKitManager()

    // Calcolo range settimana ISO corrente
    let calendar = Calendar(identifier: .iso8601)
    let now = Date()

    guard
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
    else {
        return
    }

    let weekStart = weekInterval.start
    let weekEnd = weekInterval.end

    let comps = calendar.dateComponents(
        [.yearForWeekOfYear, .weekOfYear],
        from: now
    )

    hk.fetchVO2MaxThisWeek { vo2Mean, vo2Last in
        hk.fetchRestingHRThisWeek { rhr in
            hk.fetchActiveKcalThisWeek { kcal in
                hk.fetchWorkoutsThisWeek { workouts in
                    hk.analyzeWorkoutHR(workouts: workouts) { hrMean, hrMax, minutesHigh in

                        hk.fetchWeeklySteps(
                            start: weekStart,
                            end: weekEnd
                        ) { stepsTotal in

                            let stepsAvg = stepsTotal / 7

                            let verdict = hk.verdict(
                                minutesHigh: minutesHigh,
                                hrMax: hrMax
                            )

                            let report = WeeklyReport(
                                year: comps.yearForWeekOfYear ?? 0,
                                week: comps.weekOfYear ?? 0,
                                vo2maxMean: vo2Mean,
                                vo2maxLast: vo2Last,
                                restingHR: rhr,
                                activeKcal: Int(kcal),
                                workoutHRMean: hrMean,
                                workoutHRMax: hrMax,
                                minutesHigh: minutesHigh,
                                verdict: verdict,
                                stepsWeeklyTotal: stepsTotal,
                                stepsDailyAverage: stepsAvg
                            )

                            completion(report)
                        }
                    }
                }
            }
        }
    }
}
