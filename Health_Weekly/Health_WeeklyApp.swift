//
//  Health_WeeklyApp.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import SwiftUI
import BackgroundTasks


@main
struct Health_WeeklyApp: App {

    let notificationDelegate = NotificationDelegate()
    
    init() {
        registerBackgroundTask()
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    scheduleNextWeeklyTask()
                }
        }
    }
}



func registerBackgroundTask() {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.riccardo.healthweekly",
        using: nil
    ) { task in
        handleWeeklyTask(task: task as! BGProcessingTask)
    }
}

func handleWeeklyTask(task: BGProcessingTask) {

    scheduleNextWeeklyTask()
    print("🚀 Weekly background task STARTED at \(Date())")
    
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1

    let operation = BlockOperation {
        runWeeklyCheckAndSend()
    }

    task.expirationHandler = {
        queue.cancelAllOperations()
    }

    operation.completionBlock = {
        task.setTaskCompleted(success: !operation.isCancelled)
    }

    queue.addOperation(operation)
}

func runWeeklyCheckAndSend() {
    let hk = HealthKitManager()
    hk.requestAuthorization { ok in
        guard ok else { return }
        
        let weeksIncluded = max(UserDefaults.standard.integer(forKey: "weeksIncluded"), 1)

        buildWeeklyReport(weeksIncluded: weeksIncluded) { reports in

            let weeksArray: [[String: Any]] = reports.map { report in
                return [
                    "year": report.year,
                    "week": report.week,
                    "vo2maxMean": report.vo2maxMean as Any,
                    "vo2maxLast": report.vo2maxLast as Any,
                    "restingHR": report.restingHR as Any,
                    "activeKcal": report.activeKcal,
                    "workoutHRMean": report.workoutHRMean as Any,
                    "workoutHRMax": report.workoutHRMax as Any,
                    "minutesHigh": report.minutesHigh,
                    "verdict": report.verdict,
                    "stepsWeeklyTotal": report.stepsWeeklyTotal,
                    "stepsDailyAverage": report.stepsDailyAverage
                ]
            }

            let payload: [String: Any] = [
                "weeksIncluded": weeksIncluded,
                "generatedAt": Date().timeIntervalSince1970,
                "weeks": weeksArray
            ]

            sendWeeklyReport(payload)

            notifyWeeklyReportSent()
            UserDefaults.standard.set(
                Date().timeIntervalSince1970,
                forKey: lastReportSentKey
            )
        }    }
    }

func scheduleNextWeeklyTask() {

    let request = BGProcessingTaskRequest(
        identifier: "com.riccardo.healthweekly"
    )

    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false

    var date = DateComponents()
    date.weekday = 1        // Domenica (1 = Sunday)
    date.hour = 9           // target: mattina

    request.earliestBeginDate =
        Calendar.current.nextDate(
            after: Date(),
            matching: date,
            matchingPolicy: .nextTime
        )

    try? BGTaskScheduler.shared.submit(request)
    print("🟢 Weekly background task submitted")
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
