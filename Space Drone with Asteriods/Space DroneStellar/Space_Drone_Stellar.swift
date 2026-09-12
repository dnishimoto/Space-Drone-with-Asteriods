//
//  Space_Drone_with_AsteriodsApp.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 7/21/26.
//

import SwiftUI
import CoreData

@main
struct Space_Drone_with_AsteriodsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
