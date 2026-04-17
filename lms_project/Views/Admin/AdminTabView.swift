//
//  AdminTabView.swift
//  lms_project
//

import SwiftUI

struct AdminTabView: View {

    
    @State private var selectedTab = 0
    @State private var showProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AdminDashboardView(showProfile: $showProfile)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            AdminUsersView(showProfile: $showProfile)
                .tabItem {
                    Label("Users", systemImage: "person.3.fill")
                }
                .tag(1)
            
            AdminSystemControlView(showProfile: $showProfile)
                .tabItem {
                    Label("System", systemImage: "gearshape.fill")
                }
                .tag(2)
            
            AdminMessagesView(showProfile: $showProfile)
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
