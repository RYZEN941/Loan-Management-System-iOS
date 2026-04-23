//
//  AdminDashboardView.swift
//  lms_project
//
//  EXECUTIVE COMMAND CENTER
//  Elite structural reorganization: Grid-based monitoring, side-by-side outcomes, and footer activity.
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    @Binding var selectedTab: Int
    
    @State private var lastRefresh = Date()
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                // Executive Layer
                LinearGradient(colors: [Theme.Colors.primary.opacity(0.03), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        greetingBar
                        
                        // ROW 1: ACTIONS REQUIRED
                        actionRequiredSection
                        
                        // ROW 2: OPERATIONAL HEALTH
                        operationalPerformanceSection
                        
                        // ROW 3: SYSTEM HEALTH
                        systemHealthSection
                        
                        // ROW 4: RULES & RISK
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            policyEngineCard
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            riskComplianceSection
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        
                        // ROW 4: FINAL OUTCOMES (Side by Side)
                        outcomeMetricsSection
                        
                        // ROW 5: LIVE ACTIVITY (Footer)
                        recentActivitySection
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .navigationTitle("Executive Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                dashboardVM.loadData()
                adminVM.loadData()
                withAnimation(.easeOut(duration: 0.6)) {
                    isAnimating = true
                }
            }
        }
    }
    
    // MARK: - Greeting Bar
    
    private var greetingBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Command Center")
                    .font(Theme.Typography.titleLarge)
                Text("Operational Insights & Controls")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(Color.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .opacity(isAnimating ? 1 : 0)
    }
    
    // MARK: - 1. ACTIONS REQUIRED
    
    private var actionRequiredSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            MinimalHeader(title: "ACTION REQUIRED")
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md), GridItem(.flexible(), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
                statusCard(title: "SLA Breaches", count: 5, color: .red, icon: "timer", trend: "↑ 20%", trendPositive: false, subtext: "Avg delay: 24m")
                statusCard(title: "Fraud Alerts", count: 3, color: .orange, icon: "shield.righthalf.filled", subtext: "2 Critical level")
                statusCard(title: "Policy Overrides", count: 2, color: .orange, icon: "doc.on.doc.fill", trend: "↓ 10%", trendPositive: true, subtext: "Auto-processed")
                statusCard(title: "Stuck Applications", count: 6, color: .yellow, icon: "hourglass.badge.plus", trend: "↑ 5%", trendPositive: false, subtext: "Manual review req.")
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
    }
    
    // MARK: - 2. SYSTEM HEALTH
    
    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            MinimalHeader(title: "SYSTEM HEALTH")
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md), GridItem(.flexible(), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
                statusCard(title: "Processing Time", value: "4.2h", color: .blue, icon: "clock.fill", trend: "↓ 8%", trendPositive: true, subtext: "Limit: 12h")
                statusCard(title: "Applications Today", value: "48", color: .purple, icon: "doc.text.fill", trend: "↑ 15%", trendPositive: true, subtext: "Forecast: 60")
                statusCard(title: "Active Users", value: "12", color: .green, icon: "person.2.fill", subtext: "Peak: 24 (10 AM)")
                statusCard(title: "SLA Compliance", value: "92%", color: .blue, icon: "checkmark.shield.fill", trend: "↓ 2%", trendPositive: false, subtext: "Target: 95%")
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 25)
    }
    
    private func statusCard(title: String, 
                            count: Int? = nil, 
                            value: String? = nil, 
                            color: Color = Theme.Colors.primary, 
                            icon: String, 
                            trend: String? = nil, 
                            trendPositive: Bool? = nil, 
                            subtext: String? = nil) -> some View {
        Button(action: {
            // Mapping titles to actions
            switch title {
            case "SLA Breaches":
                adminVM.selectedRiskSection = .actionRequired
                adminVM.selectedRiskFilter = .slaBreach
                selectedTab = 2 // Risk Tab index
            case "Fraud Alerts":
                adminVM.selectedRiskSection = .actionRequired
                adminVM.selectedRiskFilter = .fraudAlert
                selectedTab = 2
            case "Policy Overrides", "Policy Violations":
                adminVM.selectedRiskSection = .actionRequired
                adminVM.selectedRiskFilter = .policyViolation
                selectedTab = 2
            case "Stuck Applications":
                adminVM.selectedRiskSection = .actionRequired
                adminVM.selectedRiskFilter = .stuckApplication
                selectedTab = 2
            default: break
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().fill(Theme.Colors.primary.opacity(0.08)).frame(width: 32, height: 32)
                        Image(systemName: icon).font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.primary.opacity(0.8))
                    
                    Spacer()
                    if let trend = trend {
                        HStack(spacing: 4) {
                            Text(trend)
                                .font(Theme.Typography.caption2)
                            Image(systemName: trendPositive == true ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(trendPositive == true ? Color.green : Color.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value ?? "\(count ?? 0)")
                        .font(Theme.Typography.titleLarge)
                        .foregroundStyle(.primary)
                    
                    Text(title)
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if let subtext = subtext {
                        Text(subtext)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    Theme.Colors.adaptiveSurface(colorScheme)
                    
                    // Neutral Mini Sparkline
                    GeometryReader { geo in
                        MiniSparkline(color: Theme.Colors.primary.opacity(0.06))
                            .frame(width: geo.size.width * 0.6)
                            .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.5)
                    }
                }
            }
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private struct MiniSparkline: View {
        let color: Color
        
        var body: some View {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 20))
                path.addCurve(to: CGPoint(x: 40, y: 5), control1: CGPoint(x: 10, y: 25), control2: CGPoint(x: 20, y: 0))
                path.addCurve(to: CGPoint(x: 80, y: 15), control1: CGPoint(x: 60, y: 10), control2: CGPoint(x: 70, y: 20))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
    
    // MARK: - 3. PERFORMANCE TRENDS
    
    private var operationalPerformanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                MinimalHeader(title: "OPERATIONAL HEALTH")
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("SLA BREACHES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLA Breach Trend")
                        .font(Theme.Typography.headline)
                    Text("Daily volume of applications exceeding response time threshold")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding([.horizontal, .top], 20)
                
                PremiumLineChart(
                    data: adminVM.slaBreachTrendData,
                    labels: adminVM.slaBreachTrendLabels,
                    accentColor: .red,
                    showPoints: true,
                    unit: "breaches"
                )
                .frame(height: 180)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.Colors.adaptiveSurface(colorScheme))
                    .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 28)
    }
    
    // MARK: - 4. POLICY ENGINE
    
    private var policyEngineCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            MinimalHeader(title: "POLICY ENGINE")
            
            VStack(spacing: 1) {
                policyRow(label: "FOIR Threshold", value: "50%", icon: "percent")
                policyRow(label: "Min CIBIL Score", value: "650", icon: "chart.bar.fill")
                policyRow(label: "Auto Approval", value: "ON", icon: "cpu.fill", color: .green)
                policyRow(label: "Last Updated", value: "2h ago", icon: "clock.fill", isLast: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
    }
    
    private func policyRow(label: String, value: String, icon: String, color: Color? = nil, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(label)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(value)
                    .font(Theme.Typography.mono)
                    .foregroundStyle(color ?? .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if !isLast {
                Divider().padding(.leading, 48)
            }
        }
    }
    
    // MARK: - 4. RISK SNAPSHOT
    
    private var riskComplianceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            MinimalHeader(title: "RISK ANALYSIS")
            
            RiskIndexCard(fraud: 3, alerts: 2)
                .frame(maxHeight: .infinity)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
    }
    
    private struct RiskIndexCard: View {
        let fraud: Int
        let alerts: Int
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            VStack(spacing: 0) {
                // Table Header
                HStack(spacing: 0) {
                    tableHeaderLabel("MONITOR", width: 140)
                    tableHeaderLabel("SCORE", width: 80)
                    tableHeaderLabel("RISK LEVEL", width: 100)
                    tableHeaderLabel("STATUS", width: 100)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                
                // Table Rows
                VStack(spacing: 0) {
                    RiskAnalysisRow(title: "Fraud flags", value: "\(fraud)", risk: "Critical", status: "Increasing", color: Color(hex: "FA114F"), icon: "shield.fill")
                    Divider().padding(.horizontal, 12)
                    RiskAnalysisRow(title: "Safety Index", value: "92%", risk: "Optimal", status: "Stable", color: Color(hex: "34C759"), icon: "checkmark.shield.fill")
                    Divider().padding(.horizontal, 12)
                    RiskAnalysisRow(title: "System Alerts", value: "\(alerts)", risk: "Moderate", status: "Decreasing", color: Color(hex: "21DFF0"), icon: "bell.fill")
                    Divider().padding(.horizontal, 12)
                    RiskAnalysisRow(title: "Overrides", value: "12", risk: "Low", status: "Stable", color: .orange, icon: "doc.on.doc.fill")
                }
                .padding(.vertical, 8)
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        
        private func tableHeaderLabel(_ title: String, width: CGFloat) -> some View {
            Text(title)
                .font(Theme.Typography.caption2)
                .foregroundStyle(.secondary)
                .frame(width: width, alignment: .leading)
        }
    }
    
    private struct RiskAnalysisRow: View {
        let title: String
        let value: String
        let risk: String
        let status: String
        let color: Color
        let icon: String
        
        var body: some View {
            HStack(spacing: 0) {
                // Category
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(title)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                }
                .frame(width: 140, alignment: .leading)
                
                // Value
                Text(value)
                    .font(Theme.Typography.mono)
                    .frame(width: 80, alignment: .leading)
                
                // Risk Badge
                riskBadge(text: risk, color: color)
                    .frame(width: 100, alignment: .leading)
                
                // Status
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10))
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        
        private var statusIcon: String {
            switch status {
            case "Increasing": return "arrow.up.right"
            case "Decreasing": return "arrow.down.right"
            default: return "minus"
            }
        }
        
        private func riskBadge(text: String, color: Color) -> some View {
            Text(text.uppercased())
                .font(Theme.Typography.caption2)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
    }
    
    
    // MARK: - 5. FINAL OUTCOMES (Side-by-Side)
    
    private var outcomeMetricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            MinimalHeader(title: "FINAL OUTCOMES")
            
            HStack(spacing: Theme.Spacing.md) {
                outcomeCard(label: "NPA RATIO", value: "2.4%", status: "Good", color: Theme.Colors.primary)
                outcomeCard(label: "COLLECTION EFFICIENCY", value: "94.7%", status: "On Track", color: Theme.Colors.success)
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 35)
    }
    
    private func outcomeCard(label: String, value: String, status: String, color: Color) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
            }
            Spacer()
            Text(status)
                .font(Theme.Typography.caption2)
                .foregroundStyle(Theme.Colors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.primary.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .cornerRadius(16)
    }
    
    // MARK: - 6. LIVE ACTIVITY (Footer)
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            MinimalHeader(title: "RECENT ACTIVITIES")
            
            VStack(spacing: 0) {
                activityItem(title: "APP-2024-006 approved", actor: "Deepak Mehta", time: "12m ago", color: .green)
                activityItem(title: "Policy Update: Min CIBIL Score matched", actor: "System Rule", time: "1h ago", color: .blue)
                activityItem(title: "APP-2024-009 escalated to Admin", actor: "Sunita Patel", time: "2h ago", color: .orange)
                activityItem(title: "Suspicious Application detected", actor: "Fraud Engine", time: "3h ago", color: .red, isLast: true)
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 40)
    }
    
    private func activityItem(title: String, actor: String, time: String, color: Color, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color.opacity(0.4), radius: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        Text(actor)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(time)
                            .foregroundStyle(.tertiary)
                    }
                    .font(Theme.Typography.caption)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if !isLast {
                Divider().padding(.leading, 40)
            }
        }
    }
}

// MARK: - Components

struct MinimalHeader: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(Theme.Typography.title)
                .foregroundStyle(.primary)
                .tracking(1.2)
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
