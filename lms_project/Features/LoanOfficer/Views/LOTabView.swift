//
//  LOTabView.swift
//  lms_project
//

import SwiftUI

struct LOTabView: View {

    
    @State private var selectedTab = 0
    @State private var showProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LODashboardView(selectedTab: $selectedTab, showProfile: $showProfile)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            LOApplicationsView(showProfile: $showProfile)
                .tabItem {
                    Label("Applications", systemImage: "doc.text.fill")
                }
                .tag(1)
            
            LOMessagesView(showProfile: $showProfile)
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
