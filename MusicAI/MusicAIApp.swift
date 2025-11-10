//
//  MusicAIApp.swift
//  MusicAI
//
//  Created by Ian on 2025/5/21.
//

import SwiftUI

@main
struct MusicAIApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .onAppear {
                    NotificationManager.requestAuthorization()
                    RemoteConfig.shared.fetchConfig()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        RemoteConfig.shared.fetchConfig()
                    }
                }
        }
    }
}
