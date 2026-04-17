//
//  lms_projectApp.swift
//  lms_project
//
//  Created by apple on 17/04/26.
//

import SwiftUI

@main
struct lms_projectApp: App {
    @StateObject private var authVM = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
        }
    }
}
