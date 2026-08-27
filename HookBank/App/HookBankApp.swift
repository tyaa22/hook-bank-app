//
//  HookBankApp.swift
//  HookBank
//
//  Created by Cyintia Limmanto on 18/08/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck

@main
struct HookBankApp: App {
    init () {
        Self.configureFirebase()
    }
    
    /// Persistent SwiftData container — activities survive app restarts.
    let container: ModelContainer = {
        let schema = Schema([Activity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .modelContainer(container)
        }
    }
    
    private static func configureFirebase() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("GoogleService-Info.plist not found - PDF import via gemini will be unavailable")
            return
        }
        
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif
        FirebaseApp.configure()
    }
}
