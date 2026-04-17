//
//  LOTabView.swift
//  lms_project
//

import SwiftUI

struct LOTabView: View {
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var applicationsVM = ApplicationsViewModel()
    @StateObject private var messagesVM = MessagesViewModel()
    
    @State private var selectedTab = 0
    @State private var showProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LODashboardView(showProfile: $showProfile)
                .environmentObject(dashboardVM)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            LOApplicationsView(showProfile: $showProfile)
                .environmentObject(applicationsVM)
                .tabItem {
                    Label("Applications", systemImage: "doc.text.fill")
                }
                .tag(1)
            
            LOMessagesView(showProfile: $showProfile)
                .environmentObject(messagesVM)
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(2)
        }
        .tint(Theme.Colors.primary)
        .sheet(isPresented: $showProfile) {
            LOProfileView(isModal: true)
        }
    }
}
