//
//  HookBankApp.swift
//  HookBank
//
//  Created by Cyintia Limmanto on 18/08/26.
//

//import SwiftUI
//
//@main
//struct HookBankApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}

//
//  CobaNLApp.swift
//  CobaNL
//
//  Created by Irfan Hanif Khoiru Rijal on 19/08/26.
//

import SwiftUI
import SwiftData

@main
struct HookBankApp: App {
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
            ContentView()
                .modelContainer(container)
        }
    }
}
