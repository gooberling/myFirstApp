//
//  MyFirstAppApp.swift
//  MyFirstApp
//
//  Created by Nick D on 10/07/2026.
//

import SwiftUI
import UserNotifications

@main
struct MyFirstAppApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
