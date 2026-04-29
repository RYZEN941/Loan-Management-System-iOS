//
//  BorrowerProfileView.swift
//  lms_project
//

import SwiftUI

struct BorrowerProfileView: View {
    let borrowerRecord: BorrowerRecord
    var notes: [BorrowerNote] = []
    var showsInternalNotes = true
    var onAddNote: ((String) -> Void)? = nil
    var onSelectApplication: ((LoanApplication) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddNoteSheet = false
    @State private var noteDraft = ""
    @State private var showRepaymentSheet = false

    private var latestApplication: LoanApplication {
        borrowerRecord.latestApplication
    }

    private var activeLoan: LoanApplication? {
        borrowerRecord.activeLoanApplication
    }

    private var primary: Color { Theme.Colors.adaptivePrimary(colorScheme) }
    private var surface: Color { Theme.Colors.adaptiveSurface(colorScheme) }
    private var border: Color { Theme.Colors.adaptiveBorder(colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                identitySection
                creditProfileSection
                loanHistorySection

                if let activeLoan {
                    activeRepaymentSection(activeLoan)
                }

                if showsInternalNotes {
                    notesSection
                }
            }
            .padding(20)
        }
        .background(Theme.Colors.adaptiveBackground(colorScheme))
        .sheet(isPresented: $showAddNoteSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    TextEditor(text: $noteDraft)
                        .padding(12)
                        .frame(minHeight: 180)
                        .background(surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(border, lineWidth: 1)
                        )

                    Spacer()
                }
                .padding(20)
                .navigationTitle("Add Borrower Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            noteDraft = ""
                            showAddNoteSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onAddNote?(noteDraft)
                            noteDraft = ""
                            showAddNoteSheet = false
                        }
                        .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRepaymentSheet) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(repaymentTimeline(for: activeLoan ?? latestApplication), id: \.id) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.label)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(item.date)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.amount)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text(item.status)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(item.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .padding(14)
                            .background(surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(border, lineWidth: 1)
                            )
                        }
                    }
                    .padding(20)
                }
                .navigationTitle("Full Repayment Schedule")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(borrowerRecord.borrower.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(borrowerRecord.age) years • \(borrowerRecord.branch)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(borrowerRecord.borrower.employmentType)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(primary.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                metaPill(icon: "building.2.fill", text: borrowerRecord.borrower.employer)
                metaPill(icon: "phone.fill", text: borrowerRecord.borrower.phone)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("KYC Status")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(Array(borrowerRecord.latestKYCStatuses.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.status.color)
                                .frame(width: 8, height: 8)
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                            Text(item.status.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(item.status.color.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(20)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(border, lineWidth: 1))
    }

    private var creditProfileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Credit Profile", icon: "chart.bar.doc.horizontal.fill")

            CIBILGaugeView(score: latestApplication.financials.cibilScore)

            HStack(spacing: 12) {
                ratioTile(
                    title: "FOIR",
                    value: String(format: "%.1f%%", latestApplication.financials.foir),
                    threshold: "Target <= 50%",
                    color: latestApplication.financials.foir <= 50 ? Theme.Colors.success : .orange
                )
                ratioTile(
                    title: "DTI Ratio",
                    value: latestApplication.financials.dtiRatio.percentFormatted,
                    threshold: latestApplication.financials.dtiRatio <= 0.30 ? "Healthy" : "Needs attention",
                    color: dtiColor(latestApplication.financials.dtiRatio)
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statTile("Monthly Income", latestApplication.financials.monthlyIncome.currencyFormatted, icon: "indianrupeesign")
                statTile("Annual Income", latestApplication.financials.annualIncome.currencyFormatted, icon: "calendar")
                statTile("Bank Balance", latestApplication.financials.bankBalance.currencyFormatted, icon: "building.columns")
            }
        }
        .padding(20)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(border, lineWidth: 1))
    }

    private var loanHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Loan History At This Bank", icon: "clock.arrow.circlepath")

            ForEach(borrowerRecord.applications) { application in
                Button {
                    onSelectApplication?(application)
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(application.riskLevel.color)
                            .frame(width: 5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(application.loan.type.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(application.createdAt.shortFormatted)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(application.loan.amount.currencyFormatted)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(application.status.displayName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(application.status.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(application.status.backgroundColor)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)
                    .background(surface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(border, lineWidth: 1))
    }

    private func activeRepaymentSection(_ application: LoanApplication) -> some View {
        let overdueCount = repaymentTimeline(for: application).filter { $0.status == "Overdue" }.count
        let onTimeCount = repaymentTimeline(for: application).filter { $0.status == "Paid" }.count
        let estimatedOutstanding = max(application.loan.amount - (Double(onTimeCount) * application.loan.emi), application.loan.amount * 0.42)

        return VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Active Loan Repayment Summary", icon: "waveform.path.ecg.rectangle.fill")

            HStack(spacing: 12) {
                statTile("Outstanding", estimatedOutstanding.currencyFormatted, icon: "creditcard")
                statTile("On-Time EMIs", "\(onTimeCount)", icon: "checkmark.circle")
                statTile("Overdue", "\(overdueCount)", icon: "exclamationmark.triangle")
            }

            VStack(spacing: 10) {
                ForEach(repaymentTimeline(for: application).prefix(6), id: \.id) { item in
                    HStack {
                        Text(item.shortMonth)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 44, alignment: .leading)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.color.opacity(0.85))
                            .frame(height: 12)
                            .overlay(alignment: .leading) {
                                Text(item.status)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.leading, 8)
                            }
                    }
                }
            }

            Button("Full Repayment Schedule") {
                showRepaymentSheet = true
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(primary)
        }
        .padding(20)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(border, lineWidth: 1))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionLabel("Internal Notes", icon: "note.text")
                Spacer()
                if onAddNote != nil {
                    Button {
                        showAddNoteSheet = true
                    } label: {
                        Label("Add Note", systemImage: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(primary)
                    }
                }
            }

            if notes.isEmpty {
                Text("No borrower-level notes yet. Add quick context here while backend storage is still local-first.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(note.author)
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text(note.createdAt.relativeFormatted)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Text(note.text)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                    }
                    .padding(14)
                    .background(surface.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(border, lineWidth: 1)
                    )
                }
            }
        }
        .padding(20)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(border, lineWidth: 1))
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(primary)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(primary.opacity(0.08))
        .clipShape(Capsule())
    }

    private func statTile(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title.uppercased())
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func ratioTile(title: String, value: String, threshold: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(threshold)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primary)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.3)
        }
    }

    private func dtiColor(_ value: Double) -> Color {
        if value <= 0.30 { return Theme.Colors.success }
        if value <= 0.40 { return .orange }
        return Theme.Colors.critical
    }

    private func repaymentTimeline(for application: LoanApplication) -> [RepaymentSnapshot] {
        let calendar = Calendar.current
        let statuses = ["Paid", "Paid", "Paid", "Late", "Paid", "Overdue"]

        return (0..<6).map { index in
            let date = calendar.date(byAdding: .month, value: -(5 - index), to: Date()) ?? Date()
            let status = statuses[index]
            return RepaymentSnapshot(
                id: "\(application.id)-repayment-\(index)",
                label: date.monthYearFormatted,
                shortMonth: date.shortMonthLabel,
                date: date.shortFormatted,
                amount: application.loan.emi.currencyFormatted,
                status: status,
                color: {
                    switch status {
                    case "Paid": return Theme.Colors.success
                    case "Late": return .orange
                    default: return Theme.Colors.critical
                    }
                }()
            )
        }
    }
}

private struct RepaymentSnapshot {
    let id: String
    let label: String
    let shortMonth: String
    let date: String
    let amount: String
    let status: String
    let color: Color
}

private extension Date {
    var monthYearFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }

    var shortMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: self)
    }
}
