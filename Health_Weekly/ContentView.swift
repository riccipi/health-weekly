//
//  ContentView.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import SwiftUI
import UserNotifications
import HealthKit

struct ContentView: View {
    
    @AppStorage("weeksIncluded")
    private var weeksIncluded: Int = 1
    
    @AppStorage("lastWeeklyReportSentAt")
    private var lastReportSentAt: Double = 0
    
    let hk = HealthKitManager()
    
    @State private var showSendConfirmation = false
    @State private var workouts: [HKWorkout] = []
    @State private var selectedWorkout: HKWorkout?
    
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
           
            Picker("Weeks included", selection: $weeksIncluded) {
                ForEach(1...4, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.segmented)
            
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
            
            List(workouts, id: \.self) { workout in
                Button {
                    selectedWorkout = workout

                    hk.fetchHeartRateForWorkout(workout: workout) { samples in

                        let payload = samples.map {
                            HeartRateSample(
                                timestamp: $0.date.timeIntervalSince1970,
                                bpm: $0.bpm
                            )
                        }
                        sendHeartRateToBackend(payload)
                    }

                } label: {
                    VStack(alignment: .leading) {
                        Text(workout.workoutActivityType.name)
                            .font(.headline)

                        Text(workout.startDate.formatted())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            .onAppear {
                hk.requestAuthorization { ok in
                    guard ok else { return }

                    hk.fetchRecentWorkouts { w in
                        DispatchQueue.main.async {
                            self.workouts = w
                        }
                    }
                }
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

