//
//  ManagerTabView.swift
//  lms_project
//

import SwiftUI
import UIKit

struct ManagerTabView: View {

    
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var reportsVM = AdminReportsViewModel()
    
    @State private var selectedTab = 0
    @State private var showProfile = false

    init() {
        configureTabBarAppearance()
    }
    
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
            
            ManagerDstView(showProfile: $showProfile)
                .tabItem {
                    Label("DST", systemImage: "person.2.badge.gearshape.fill")
                }
                .tag(2)
            
            ManagerMessagesView(showProfile: $showProfile)
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(3)
            
            AdminReportsView(showProfile: $showProfile)
                .environmentObject(reportsVM)
                .tabItem {
                    Label("Reports", systemImage: "doc.text")
                }
                .tag(4)
        }
        .tint(ManagerTheme.Colors.primary(colorScheme))
        .sheet(isPresented: $showProfile) {
            ManagerProfileView()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray3

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.systemGray3
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold)
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
        appearance.stackedItemPositioning = .automatic
        appearance.stackedItemWidth = 60

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
