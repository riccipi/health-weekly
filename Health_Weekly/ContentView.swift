//
//  ContentView.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    
    @AppStorage("lastWeeklyReportSentAt")
    private var lastReportSentAt: Double = 0
    
    let hk = HealthKitManager()
    
    @State private var showSendConfirmation = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("HealthWeekly POC")
                .font(.headline)
            
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(
                        options: [.alert, .sound]
                    ) { granted, error in
                        if let error = error {
                            print("Notification permission error:", error)
                        }
                        print("Notifications granted:", granted)
                    }
                }
            
            Text("Ultimo report inviato: \(formattedLastReportDate())")
                .font(.footnote)
                .foregroundColor(.secondary)
           
            Button("Invio manuale") {
                showSendConfirmation = true
            }
            .confirmationDialog(
                "Inviare il report settimanale?",
                isPresented: $showSendConfirmation,
                titleVisibility: .visible
            ) {
                Button("Invia report", role: .destructive) {
                    runWeeklyCheckAndSend()
                }

                Button("Annulla", role: .cancel) {}
            }
            
        }
        .padding()
    }
    
    func formattedLastReportDate() -> String {
        guard lastReportSentAt > 0 else {
            return "Mai"
        }

        let date = Date(timeIntervalSince1970: lastReportSentAt)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter.string(from: date)
    }

}

