//
//  AdminTabView.swift
//  lms_project
//
//  MODIFIED: Appended Executive, Risk, Collections, and Reports tabs.
//  All original 4 tabs (Dashboard, Users, System, Messages) are preserved untouched.
//

import SwiftUI

struct AdminTabView: View {

    // Shim: pull AuthViewModel from environment (injected from lms_projectApp entry point)
    @EnvironmentObject private var authVM_shim: AuthViewModel

    @StateObject private var adminVM     = AdminViewModel()
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var messagesVM  = MessagesViewModel()
    @State private var selectedTab = 0
    @State private var showProfile = false

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── EXISTING TAB 0 ── Dashboard (unchanged)
            AdminDashboardView(showProfile: $showProfile)
                .environmentObject(adminVM)
                .environmentObject(dashboardVM)
                .environmentObject(authVM_shim)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            // ── EXISTING TAB 1 ── Users (unchanged)
            AdminUsersView(showProfile: $showProfile)
                .environmentObject(adminVM)
                .tabItem {
                    Label("Users", systemImage: "person.3.fill")
                }
                .tag(1)

            // ── EXISTING TAB 2 ── System Control (unchanged)
            AdminSystemControlView(showProfile: $showProfile)
                .environmentObject(adminVM)
                .tabItem {
                    Label("System", systemImage: "gearshape.fill")
                }
                .tag(2)

            // ── EXISTING TAB 3 ── Messages (unchanged)
            AdminMessagesView(showProfile: $showProfile)
                .environmentObject(messagesVM)
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(3)

            // ── NEW TAB 4 ── Executive Dashboard
            AdminExecutiveDashboardView(showProfile: $showProfile)
                .environmentObject(adminVM)
                .environmentObject(dashboardVM)
                .tabItem {
                    Label("Executive", systemImage: "chart.xyaxis.line")
                }
                .tag(4)

            // ── NEW TAB 5 ── Risk & Decisioning
            AdminRiskView(showProfile: $showProfile)
                .environmentObject(adminVM)
                .tabItem {
                    Label("Risk", systemImage: "exclamationmark.shield.fill")
                }
                .tag(5)

            // ── NEW TAB 6 ── Collections
            AdminCollectionsView(showProfile: $showProfile)
                .environmentObject(adminVM)
                .tabItem {
                    Label("Collections", systemImage: "arrow.uturn.down.circle.fill")
                }
                .tag(6)

            // ── NEW TAB 7 ── Reports
            AdminReportsView(showProfile: $showProfile)
                .tabItem {
                    Label("Reports", systemImage: "doc.richtext.fill")
                }
                .tag(7)
        }
        .tint(Theme.Colors.primary)
        // Profile sheet now uses the full Admin Global Settings overlay
        .sheet(isPresented: $showProfile) {
            AdminGlobalSettingsView()
                .environmentObject(authVM_shim)
                .environmentObject(adminVM)
        }
    }
}
