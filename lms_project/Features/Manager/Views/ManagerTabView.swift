//
//  ManagerTabView.swift
//  lms_project
//

import SwiftUI

struct ManagerTabView: View {

    
    @State private var selectedTab = 0
    @State private var showProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ManagerDashboardView(showProfile: $showProfile)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            ManagerApprovalsView(showProfile: $showProfile)
                .tabItem {
                    Label("Approvals", systemImage: "checkmark.circle.fill")
                }
                .tag(1)
            
            ManagerPortfolioView(showProfile: $showProfile)
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie.fill")
                }
                .tag(2)
            
            ManagerMessagesView(showProfile: $showProfile)
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
