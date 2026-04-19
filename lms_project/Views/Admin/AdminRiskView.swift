//
//  AdminRiskView.swift
//  lms_project
//
//  TAB 3 — Risk & Collections (Merged)
//

import SwiftUI

struct AdminRiskView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var riskVM: AdminRiskViewModel
    @EnvironmentObject var collectionsVM: AdminCollectionsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var selectedSection = 0
    @State private var riskFilter: RiskFilter = .all
    @State private var dpdBucket: DPDBucket = .thirty
    @State private var showSettlementSheet: CollectionCase? = nil
    @State private var showAgentAssign: CollectionCase? = nil

    enum RiskFilter: String, CaseIterable { case all="All", high="High", medium="Medium", low="Low" }
    enum DPDBucket: String, CaseIterable {
        case thirty="30 DPD", sixty="60 DPD", ninety="90+ DPD"
        var color: Color {
            switch self { case .thirty: return Theme.Colors.warning; case .sixty: return Color(hex:"E8720C"); case .ninety: return Theme.Colors.critical }
        }
    }

    // Mock data
    private let foirData: [(label:String,value:Double)] = [("Home Loan",0.38),("Personal Loan",0.52),("Business Loan",0.44),("Vehicle Loan",0.31),("Education Loan",0.28)]
    private let cibilData: [(label:String,count:Int,color:Color)] = [("750+",42,Theme.Colors.success),("650–749",28,Theme.Colors.warning),("<650",8,Theme.Colors.critical)]
    private let ltvData: [(label:String,value:Double)] = [("Home Loan",0.72),("Vehicle Loan",0.65),("Business Loan",0.55),("Education Loan",0.40)]

    private let flaggedApps: [FlaggedApplication] = [
        FlaggedApplication(id:"APP-031",borrower:"Ramesh Gupta",loanType:"Personal",amount:"₹5.5L",riskScore:88,risk:.high,flag:"CIBIL 542, DTI 61%"),
        FlaggedApplication(id:"APP-047",borrower:"Kavitha Nair",loanType:"Business",amount:"₹18L",riskScore:76,risk:.high,flag:"Multiple active loans"),
        FlaggedApplication(id:"APP-055",borrower:"Ajay Sharma",loanType:"Home",amount:"₹42L",riskScore:61,risk:.medium,flag:"LTV 84% exceeds cap"),
        FlaggedApplication(id:"APP-062",borrower:"Priya Menon",loanType:"Vehicle",amount:"₹8.2L",riskScore:54,risk:.medium,flag:"Income verification gap"),
        FlaggedApplication(id:"APP-071",borrower:"Suresh Pillai",loanType:"Education",amount:"₹3.8L",riskScore:38,risk:.low,flag:"Document mismatch"),
    ]

    private let cases30: [CollectionCase] = [
        CollectionCase(id:"COL-001",borrower:"Vivek Tiwari",loanType:"Personal Loan",outstanding:"₹2.4L",emi:"₹8,500",agent:"Ravi Kumar",status:.contacted),
        CollectionCase(id:"COL-002",borrower:"Sunita Rao",loanType:"Vehicle Loan",outstanding:"₹3.8L",emi:"₹12,200",agent:"Priya Sharma",status:.pendingPTP),
        CollectionCase(id:"COL-003",borrower:"Arjun Kulkarni",loanType:"Home Loan",outstanding:"₹18.6L",emi:"₹24,500",agent:"Unassigned",status:.unassigned),
    ]
    private let cases60: [CollectionCase] = [
        CollectionCase(id:"COL-004",borrower:"Deepa Nambiar",loanType:"Business Loan",outstanding:"₹7.2L",emi:"₹18,000",agent:"Suresh Nair",status:.escalated),
        CollectionCase(id:"COL-005",borrower:"Manoj Patel",loanType:"Personal Loan",outstanding:"₹1.9L",emi:"₹6,800",agent:"Ravi Kumar",status:.partialPayment),
    ]
    private let cases90: [CollectionCase] = [
        CollectionCase(id:"COL-006",borrower:"Girish Mehta",loanType:"Home Loan",outstanding:"₹34.5L",emi:"₹42,000",agent:"Legal Team",status:.legal),
        CollectionCase(id:"COL-007",borrower:"Rekha Joshi",loanType:"Business Loan",outstanding:"₹11.2L",emi:"₹22,500",agent:"Vikram Seth",status:.settled),
    ]
    private let npaLoans: [CollectionCase] = [
        CollectionCase(id:"NPA-001",borrower:"Farhan Siddiqui",loanType:"Vehicle Loan",outstanding:"₹5.6L",emi:"₹14,000",agent:"Unassigned",status:.unassigned),
    ]

    private var filteredFlagged: [FlaggedApplication] {
        switch riskFilter {
        case .all: return flaggedApps
        case .high: return flaggedApps.filter{$0.risk == .high}
        case .medium: return flaggedApps.filter{$0.risk == .medium}
        case .low: return flaggedApps.filter{$0.risk == .low}
        }
    }
    private var activeCases: [CollectionCase] {
        switch dpdBucket { case .thirty: return cases30; case .sixty: return cases60; case .ninety: return cases90 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Section", selection: $selectedSection) {
                        Text("Risk Dashboard").tag(0)
                        Text("Fraud Detection").tag(1)
                        Text("Collections").tag(2)
                        Text("NPA").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)

                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            switch selectedSection {
                            case 0: riskDashboardSection
                            case 1: fraudDetectionSection
                            case 2: collectionsSection
                            case 3: npaSection
                            default: EmptyView()
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Risk & Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ProfileNavButton(showProfile: $showProfile) }
            }
            .sheet(item: $showAgentAssign) { ccase in AgentAssignmentSheet(collectionCase: ccase) }
            .animation(.easeInOut(duration: 0.2), value: selectedSection)
        }
    }

    // MARK: - Risk Dashboard
    private var riskDashboardSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // FOIR
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "FOIR Distribution", icon: "chart.bar")
                Text("Fixed Obligation to Income Ratio — target ≤ 50%").font(Theme.Typography.caption).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(foirData, id:\.label) { item in
                        RiskBarRow(label:item.label, value:item.value, valueText:"\(Int(item.value*100))%", warningThreshold:0.50, dangerThreshold:0.60, colorScheme:colorScheme)
                        if item.label != foirData.last?.label { Divider().padding(.leading, Theme.Spacing.md) }
                    }
                }.cardStyle(colorScheme: colorScheme)
            }
            // CIBIL
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "CIBIL Score Distribution", icon: "chart.bar.xaxis")
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(cibilData, id:\.label) { item in
                        VStack(spacing: Theme.Spacing.sm) {
                            Text("\(item.count)").font(.system(size:28,weight:.bold,design:.rounded)).foregroundStyle(item.color)
                            Text(item.label).font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity).padding(Theme.Spacing.md).cardStyle(colorScheme:colorScheme)
                    }
                }
            }
            // LTV
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "LTV Distribution", icon: "percent")
                Text("Loan to Value Ratio — target ≤ 80%").font(Theme.Typography.caption).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(ltvData, id:\.label) { item in
                        RiskBarRow(label:item.label, value:item.value, valueText:"\(Int(item.value*100))%", warningThreshold:0.70, dangerThreshold:0.80, colorScheme:colorScheme)
                        if item.label != ltvData.last?.label { Divider().padding(.leading, Theme.Spacing.md) }
                    }
                }.cardStyle(colorScheme: colorScheme)
            }
            // Risk Profile Summary
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Applicant Risk Profile", icon: "shield.lefthalf.filled")
                HStack(spacing: Theme.Spacing.md) {
                    riskCountPill(label:"High",count:flaggedApps.filter{$0.risk == .high}.count,color:Theme.Colors.critical)
                    riskCountPill(label:"Medium",count:flaggedApps.filter{$0.risk == .medium}.count,color:Theme.Colors.warning)
                    riskCountPill(label:"Low",count:flaggedApps.filter{$0.risk == .low}.count,color:Theme.Colors.success)
                }
            }
        }
    }

    // MARK: - Fraud Detection
    private var fraudDetectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "Flagged Applications", icon: "shield.slash")
                Spacer()
                Text("\(filteredFlagged.count) flagged").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Picker("Risk Level", selection:$riskFilter) {
                ForEach(RiskFilter.allCases, id:\.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)

            if filteredFlagged.isEmpty {
                emptyState(icon:"checkmark.shield.fill",text:"No flags in this category")
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredFlagged) { app in
                        FlaggedAppRow(app:app, colorScheme:colorScheme)
                        if app.id != filteredFlagged.last?.id { Divider().padding(.leading, Theme.Spacing.md) }
                    }
                }.cardStyle(colorScheme: colorScheme)
            }

            // Duplicate Applications
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Duplicate Applications", icon: "doc.on.doc")
                VStack(spacing: 0) {
                    dupRow(name:"Ramesh Gupta",apps:"2 applications",detail:"Same PAN, different addresses")
                    Divider().padding(.leading, Theme.Spacing.md)
                    dupRow(name:"Unknown",apps:"3 applications",detail:"Same phone number across apps")
                }.cardStyle(colorScheme:colorScheme)
            }
        }
    }

    private func dupRow(name:String,apps:String,detail:String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName:"exclamationmark.triangle.fill").font(.system(size:14)).foregroundStyle(Theme.Colors.critical)
            VStack(alignment:.leading,spacing:2) {
                Text(name).font(Theme.Typography.subheadline).fontWeight(.medium)
                Text("\(apps) · \(detail)").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            GenericBadge(text:"Suspicious",color:Theme.Colors.critical)
        }.padding(.horizontal,Theme.Spacing.md).padding(.vertical,12)
    }

    // MARK: - Collections
    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Picker("DPD Bucket",selection:$dpdBucket) {
                ForEach(DPDBucket.allCases,id:\.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)

            // Summary
            HStack(spacing:Theme.Spacing.lg) {
                VStack(alignment:.leading,spacing:Theme.Spacing.xs) {
                    Text(dpdBucket.rawValue).font(.system(size:28,weight:.bold,design:.rounded)).foregroundStyle(dpdBucket.color)
                    Text("Overdue Loans").font(Theme.Typography.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment:.trailing,spacing:Theme.Spacing.xs) {
                    Text("\(activeCases.count)").font(.system(size:36,weight:.bold,design:.rounded)).foregroundStyle(dpdBucket.color)
                    Text("cases").font(Theme.Typography.caption).foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(dpdBucket.color.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius:Theme.Radius.lg).stroke(dpdBucket.color.opacity(0.25),lineWidth:1))
            .clipShape(RoundedRectangle(cornerRadius:Theme.Radius.lg))

            // Case list
            VStack(alignment:.leading,spacing:Theme.Spacing.md) {
                SectionHeader(title:"Borrower Cases",icon:"person.crop.rectangle.stack")
                if activeCases.isEmpty {
                    emptyState(icon:"checkmark.circle.fill",text:"No cases in this bucket")
                } else {
                    VStack(spacing:0) {
                        ForEach(activeCases) { ccase in
                            CollectionCaseRow(ccase:ccase,bucketColor:dpdBucket.color,colorScheme:colorScheme,onAssign:{ showAgentAssign = ccase })
                            if ccase.id != activeCases.last?.id { Divider().padding(.leading,Theme.Spacing.md) }
                        }
                    }.cardStyle(colorScheme:colorScheme)
                }
            }

            // Recovery summary
            VStack(alignment:.leading,spacing:Theme.Spacing.md) {
                SectionHeader(title:"Recovery Summary",icon:"arrow.uturn.down.circle")
                VStack(spacing:0) {
                    recoveryRow(label:"Contacted",count:4,color:Theme.Colors.primary)
                    Divider().padding(.leading,Theme.Spacing.md)
                    recoveryRow(label:"PTP Received",count:3,color:Theme.Colors.success)
                    Divider().padding(.leading,Theme.Spacing.md)
                    recoveryRow(label:"Partial Payment",count:2,color:Theme.Colors.warning)
                    Divider().padding(.leading,Theme.Spacing.md)
                    recoveryRow(label:"Settled",count:1,color:Theme.Colors.success)
                    Divider().padding(.leading,Theme.Spacing.md)
                    recoveryRow(label:"Legal Action",count:1,color:Theme.Colors.critical)
                }.cardStyle(colorScheme:colorScheme)
            }
        }
    }

    // MARK: - NPA
    private var npaSection: some View {
        VStack(alignment:.leading,spacing:Theme.Spacing.md) {
            SectionHeader(title:"NPA Management",icon:"exclamationmark.triangle")
            Text("Loans classified as Non-Performing Assets (90+ DPD)").font(Theme.Typography.caption).foregroundStyle(.secondary)

            if npaLoans.isEmpty {
                emptyState(icon:"checkmark.shield.fill",text:"No NPA loans currently")
            } else {
                VStack(spacing:0) {
                    ForEach(npaLoans) { loan in
                        HStack(spacing:Theme.Spacing.md) {
                            Image(systemName:"exclamationmark.triangle.fill").font(.system(size:16)).foregroundStyle(Theme.Colors.critical)
                            VStack(alignment:.leading,spacing:2) {
                                HStack { Text(loan.borrower).font(Theme.Typography.headline); Spacer(); GenericBadge(text:"NPA",color:Theme.Colors.critical) }
                                Text("\(loan.id) · \(loan.loanType) · \(loan.outstanding) outstanding").font(Theme.Typography.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.horizontal,Theme.Spacing.md).padding(.vertical,12)
                    }
                }.cardStyle(colorScheme:colorScheme)
            }

            // NPA Stats
            HStack(spacing:Theme.Spacing.md) {
                npaStatCard(label:"Total NPA",value:"\(npaLoans.count)",color:Theme.Colors.critical)
                npaStatCard(label:"NPA Ratio",value:"2.4%",color:Theme.Colors.warning)
                npaStatCard(label:"Recovery Rate",value:"34%",color:Theme.Colors.success)
            }
        }
    }

    // MARK: - Helpers
    private func emptyState(icon:String,text:String) -> some View {
        VStack(spacing:Theme.Spacing.md) {
            Image(systemName:icon).font(.system(size:36)).foregroundStyle(Theme.Colors.success)
            Text(text).font(Theme.Typography.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity).padding(Theme.Spacing.xxl).cardStyle(colorScheme:colorScheme)
    }

    private func riskCountPill(label:String,count:Int,color:Color) -> some View {
        VStack(spacing:Theme.Spacing.xs) {
            Text("\(count)").font(.system(size:28,weight:.bold,design:.rounded)).foregroundStyle(color)
            Text(label+" Risk").font(Theme.Typography.caption).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity).padding(Theme.Spacing.md).cardStyle(colorScheme:colorScheme)
    }

    private func recoveryRow(label:String,count:Int,color:Color) -> some View {
        HStack {
            Circle().fill(color).frame(width:8,height:8)
            Text(label).font(Theme.Typography.subheadline)
            Spacer()
            Text("\(count)").font(.system(size:20,weight:.bold,design:.rounded)).foregroundStyle(color)
        }.padding(.horizontal,Theme.Spacing.md).padding(.vertical,13)
    }

    private func npaStatCard(label:String,value:String,color:Color) -> some View {
        VStack(spacing:6) {
            Text(value).font(.system(size:24,weight:.bold,design:.rounded)).foregroundStyle(color)
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity).padding(Theme.Spacing.md).cardStyle(colorScheme:colorScheme)
    }
}

// MARK: - Risk Bar Row
private struct RiskBarRow: View {
    let label:String; let value:Double; let valueText:String; let warningThreshold:Double; let dangerThreshold:Double; let colorScheme:ColorScheme
    private var barColor: Color {
        if value >= dangerThreshold { return Theme.Colors.critical }
        if value >= warningThreshold { return Theme.Colors.warning }
        return Theme.Colors.success
    }
    var body: some View {
        VStack(spacing:6) {
            HStack { Text(label).font(Theme.Typography.subheadline); Spacer(); Text(valueText).font(Theme.Typography.mono).foregroundStyle(barColor) }
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    RoundedRectangle(cornerRadius:4).fill(barColor.opacity(0.12)).frame(height:6)
                    RoundedRectangle(cornerRadius:4).fill(barColor).frame(width:geo.size.width*min(value,1.0),height:6)
                    Rectangle().fill(Theme.Colors.neutral.opacity(0.4)).frame(width:1.5,height:10).offset(x:geo.size.width*warningThreshold-0.75,y:-2)
                }
            }.frame(height:6)
        }.padding(.horizontal,Theme.Spacing.md).padding(.vertical,12)
    }
}

// MARK: - Flagged App Row
private struct FlaggedAppRow: View {
    let app: FlaggedApplication; let colorScheme: ColorScheme
    private var riskColor: Color { switch app.risk { case .high: return Theme.Colors.critical; case .medium: return Theme.Colors.warning; case .low: return Theme.Colors.success } }
    var body: some View {
        HStack(spacing:Theme.Spacing.md) {
            ZStack {
                Circle().stroke(riskColor.opacity(0.2),lineWidth:3).frame(width:44,height:44)
                Circle().trim(from:0,to:Double(app.riskScore)/100).stroke(riskColor,style:StrokeStyle(lineWidth:3,lineCap:.round)).rotationEffect(.degrees(-90)).frame(width:44,height:44)
                Text("\(app.riskScore)").font(.system(size:12,weight:.bold)).foregroundStyle(riskColor)
            }
            VStack(alignment:.leading,spacing:3) {
                HStack { Text(app.borrower).font(Theme.Typography.headline); Spacer(); GenericBadge(text:app.risk.displayName,color:riskColor) }
                Text("\(app.id) · \(app.loanType) · \(app.amount)").font(Theme.Typography.caption).foregroundStyle(.secondary)
                HStack(spacing:4) {
                    Image(systemName:"flag.fill").font(.system(size:10)).foregroundStyle(riskColor)
                    Text(app.flag).font(Theme.Typography.caption).foregroundStyle(riskColor)
                }
            }
        }.padding(.horizontal,Theme.Spacing.md).padding(.vertical,12)
    }
}

// MARK: - Collection Case Row
private struct CollectionCaseRow: View {
    let ccase:CollectionCase; let bucketColor:Color; let colorScheme:ColorScheme; let onAssign:()->Void
    var body: some View {
        HStack(spacing:Theme.Spacing.md) {
            Circle().fill(ccase.status.color).frame(width:10,height:10)
            VStack(alignment:.leading,spacing:3) {
                HStack { Text(ccase.borrower).font(Theme.Typography.headline); Spacer(); GenericBadge(text:ccase.status.displayName,color:ccase.status.color) }
                Text("\(ccase.id) · \(ccase.loanType)").font(Theme.Typography.caption).foregroundStyle(.secondary)
                HStack {
                    Label(ccase.outstanding+" outstanding",systemImage:"indianrupeesign.circle").font(Theme.Typography.caption).foregroundStyle(.secondary)
                    Spacer()
                    if ccase.agent == "Unassigned" {
                        Button("Assign Agent"){onAssign()}.font(.system(size:12,weight:.semibold)).foregroundStyle(bucketColor).buttonStyle(.plain)
                    } else {
                        Label(ccase.agent,systemImage:"person.fill").font(Theme.Typography.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.padding(.horizontal,Theme.Spacing.md).padding(.vertical,12)
    }
}

// MARK: - Agent Assignment Sheet
private struct AgentAssignmentSheet: View {
    let collectionCase: CollectionCase
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAgent = 0
    private let agents = ["Ravi Kumar","Priya Sharma","Suresh Nair","Vikram Seth","Ananya Bose"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Case Details") {
                    LabeledContent("Case ID",value:collectionCase.id)
                    LabeledContent("Borrower",value:collectionCase.borrower)
                    LabeledContent("Outstanding",value:collectionCase.outstanding)
                }
                Section("Assign Recovery Agent") {
                    Picker("Agent",selection:$selectedAgent) {
                        ForEach(agents.indices,id:\.self) { Text(agents[$0]).tag($0) }
                    }
                }
            }
            .navigationTitle("Assign Agent").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Cancel"){dismiss()} }
                ToolbarItem(placement:.confirmationAction) { Button("Assign"){dismiss()}.fontWeight(.semibold) }
            }
        }
    }
}

// MARK: - Local Data Models
private struct FlaggedApplication: Identifiable {
    let id:String; let borrower:String; let loanType:String; let amount:String; let riskScore:Int; let risk:RiskLevel; let flag:String
}
