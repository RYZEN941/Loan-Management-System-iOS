//
//  ManagerTabView.swift
//  lms_project
//

import SwiftUI

struct ManagerTabView: View {
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var applicationsVM = ApplicationsViewModel()
    @StateObject private var messagesVM = MessagesViewModel()
    
    @State private var selectedTab = 0
    @State private var showProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ManagerDashboardView(showProfile: $showProfile)
                .environmentObject(dashboardVM)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            ManagerApprovalsView(showProfile: $showProfile)
                .environmentObject(applicationsVM)
                .tabItem {
                    Label("Approvals", systemImage: "checkmark.circle.fill")
                }
                .tag(1)
            
            ManagerPortfolioView(showProfile: $showProfile)
                .environmentObject(dashboardVM)
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie.fill")
                }
                .tag(2)
            
            ManagerMessagesView(showProfile: $showProfile)
                .environmentObject(messagesVM)
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(3)
        }
        .tint(Theme.Colors.primary)
        .sheet(isPresented: $showProfile) {
            LOProfileView(isModal: true)
        }
    }
}
