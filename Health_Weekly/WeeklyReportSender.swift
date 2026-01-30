//
//  WeeklyReportSender.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import Foundation

let lastReportSentKey = "lastWeeklyReportSentAt"

func sendWeeklyReport(_ report: [String: Any]) {
    guard let url = URL(string: "https://tight-art-8424.riccardo-771.workers.dev") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    request.httpBody = try? JSONSerialization.data(withJSONObject: report)

    URLSession.shared.dataTask(with: request).resume()
}

