//
//  AdminNewTabView.swift
//  lms_project
//

import SwiftUI

struct AdminNewTabView: View {

    @State private var selectedTab = 0
    @State private var showProfile = false

    // EnvironmentObjects for globally provided modules
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var adminVM: AdminViewModel
    
    // StateObjects for new admin modules
    @StateObject private var loansVM = AdminLoansViewModel()
    @StateObject private var riskVM = AdminRiskViewModel()
    @StateObject private var collectionsVM = AdminCollectionsViewModel()
    @StateObject private var reportsVM = AdminReportsViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            AdminDashboardView(showProfile: $showProfile, selectedTab: $selectedTab)
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                .tag(0)

            AdminLoansView(showProfile: $showProfile)
                .environmentObject(loansVM)
                .tabItem { Label("Loans", systemImage: "doc.text.fill") }
                .tag(1)

            AdminRiskView(showProfile: $showProfile)
                .environmentObject(riskVM)
                .tabItem { Label("Risk", systemImage: "shield.righthalf.filled") }
                .tag(2)

            AdminCollectionsView(showProfile: $showProfile)
                .environmentObject(collectionsVM)
                .tabItem { Label("Collections", systemImage: "indianrupeesign.circle.fill") }
                .tag(3)

            AdminReportsView(showProfile: $showProfile)
                .environmentObject(reportsVM)
                .tabItem { Label("Reports", systemImage: "chart.pie.fill") }
                .tag(4)
        }
        .tint(Theme.Colors.primary)
        .sheet(isPresented: $showProfile) {
            // Using the new enhanced settings view for Admin profile
            AdminProfileSettingsView()
        }
    }
}
