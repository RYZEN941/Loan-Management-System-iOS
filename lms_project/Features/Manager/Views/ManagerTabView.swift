//
//  ManagerTabView.swift
//  lms_project
//

import SwiftUI

struct ManagerTabView: View {

    
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab = 0
    @State private var showProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ManagerDashboardView(selectedTab: $selectedTab, showProfile: $showProfile)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            ManagerApprovalsView(selectedTab: $selectedTab, showProfile: $showProfile)
                .tabItem {
                    Label("Approvals", systemImage: "checkmark.circle.fill")
                }
                .tag(1)
            
            ManagerPortfolioView(selectedTab: $selectedTab, showProfile: $showProfile)
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie.fill")
                }
                .tag(2)
            
            ManagerDstView(showProfile: $showProfile)
                .tabItem {
                    Label("Dst", systemImage: "person.2.badge.gearshape.fill")
                }
                .tag(3)
            
            ManagerMessagesView(showProfile: $showProfile)
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(4)
        }
        .tint(ManagerTheme.Colors.primary(colorScheme))
        .sheet(isPresented: $showProfile) {
            ManagerProfileView()
        }
    }
}
