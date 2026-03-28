//
//  WeeklyReportSender.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import Foundation
import UIKit

let lastReportSentKey = "lastWeeklyReportSentAt"

func sendWeeklyReport(_ report: [String: Any]) {
    guard let url = URL(string: "https://tight-art-8424.riccardo-771.workers.dev") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    request.httpBody = try? JSONSerialization.data(withJSONObject: report)

    URLSession.shared.dataTask(with: request).resume()
}

func sendHeartRateToBackend(_ samples: [HeartRateSample]) {

    guard let url = URL(string: "https://tight-art-8424.riccardo-771.workers.dev") else {
        print("❌ URL invalid")
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "type": "heart_rate_workout",
        "samples": samples.map {
            [
                "timestamp": $0.timestamp,
                "bpm": $0.bpm
            ]
        }
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    } catch {
        print("❌ JSON encoding error:", error)
        return
    }

    URLSession.shared.dataTask(with: request) { data, response, error in

        if let error = error {
            print("❌ NETWORK ERROR:", error)
            return
        }

        guard let data = data else {
            print("❌ NO DATA")
            return
        }

        // 🔥 QUI VA IL CODICE
        if let text = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                UIPasteboard.general.string = text
                print("📋 JSON copiato negli appunti")
            }
        }

    }.resume()
}
