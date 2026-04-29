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
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var applicationsVM = ApplicationsViewModel()
    @StateObject private var messagesVM = MessagesViewModel()
    @StateObject private var adminVM = AdminViewModel()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
                .environmentObject(dashboardVM)
                .environmentObject(applicationsVM)
                .environmentObject(messagesVM)
                .environmentObject(adminVM)
                .preferredColorScheme(authVM.isDarkMode ? .dark : .light)
                .onChange(of: authVM.currentRole) { _, newRole in
                    if newRole != nil {
                        // User just authenticated — start loading data immediately
                        applicationsVM.preloadAfterLogin()
                    } else {
                        // User logged out — reset data state
                        applicationsVM.resetOnLogout()
                    }
                }
        }
    }
}
