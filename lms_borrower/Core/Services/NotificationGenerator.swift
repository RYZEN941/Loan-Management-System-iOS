// Core/Services/NotificationGenerator.swift
// LoanOS Borrower App
// Stateless helper that detects state changes and fires in-app notifications
// via NotificationStore. All functions are static and safe to call from @MainActor contexts.

import Foundation

@MainActor
@available(iOS 18.0, *)
enum NotificationGenerator {

    // MARK: - 1. Loan Application Status Change

    static func checkApplicationStatusChanges(
        applications: [BorrowerLoanApplication]
    ) {
        let store = NotificationStore.shared
        let defaults = UserDefaults.standard
        let lastStatusPrefix = "loanOS_lastAppStatus_"

        for application in applications {
            let currentStatusRaw = application.status.rawValue
            let lastStatusKey = lastStatusPrefix + application.id
            let lastStatusRaw = defaults.string(forKey: lastStatusKey)

            // First time seeing this application — just persist the status, no notification
            if lastStatusRaw == nil {
                defaults.set(currentStatusRaw, forKey: lastStatusKey)
                continue
            }

            // Status changed?
            guard lastStatusRaw != currentStatusRaw else { continue }

            // Update persisted status
            defaults.set(currentStatusRaw, forKey: lastStatusKey)

            // Dedup check: one notification per (applicationId, newStatus) combination
            let dedupKey = "notif_app_status_\(application.id)_\(currentStatusRaw)"
            guard !store.hasAlreadyFired(dedupKey: dedupKey) else { continue }

            let notification = AppNotification(
                id: UUID(),
                title: "Application \(application.referenceNumber) Updated",
                body: "Your loan application status changed to \(application.status.displayName).",
                type: .statusChange,
                isRead: false,
                createdAt: Date(),
                applicationId: application.id,
                loanId: nil,
                emiScheduleId: nil,
                emiAmount: nil,
                transactionID: nil,
                applicationStatus: currentStatusRaw
            )
            store.add(notification)
            store.markFired(dedupKey: dedupKey)
        }
    }

    // MARK: - 2. EMI Payment Due

    static func checkUpcomingEMIs(
        loans: [ActiveLoan],
        schedules: [String: [EmiScheduleItem]],
        applicationsByLoanId: [String: BorrowerLoanApplication]
    ) {
        let store = NotificationStore.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for loan in loans {
            let items = schedules[loan.id] ?? []
            let application = applicationsByLoanId[loan.id]
            let loanProductName = application?.loanProductName.isEmpty == false
                ? application!.loanProductName
                : "Active Loan"

            for emi in items {
                guard emi.status == .upcoming || emi.status == .overdue else { continue }

                let dueDate = parseDate(emi.dueDate)
                let dueStart = calendar.startOfDay(for: dueDate)
                let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueStart).day ?? 0

                // Fire if overdue OR within 5 days (inclusive)
                let isOverdue = emi.status == .overdue || daysUntilDue < 0
                let isWithin5Days = daysUntilDue >= 0 && daysUntilDue <= 5
                guard isOverdue || isWithin5Days else { continue }

                // Dedup by emiScheduleId
                let dedupKey = "notif_emi_due_\(emi.id)"
                guard !store.hasAlreadyFired(dedupKey: dedupKey) else { continue }

                let amount = Double(emi.emiAmount) ?? 0
                let formattedAmount = formatINR(amount)
                let formattedDate = formatDate(dueDate)

                let title: String
                if isOverdue {
                    title = "EMI Overdue!"
                } else {
                    title = "EMI Due in \(daysUntilDue) Day\(daysUntilDue == 1 ? "" : "s")"
                }

                let notification = AppNotification(
                    id: UUID(),
                    title: title,
                    body: "EMI of \(formattedAmount) for loan \(loanProductName) is due on \(formattedDate).",
                    type: .emiDue,
                    isRead: false,
                    createdAt: Date(),
                    applicationId: nil,
                    loanId: loan.id,
                    emiScheduleId: emi.id,
                    emiAmount: amount,
                    transactionID: nil,
                    applicationStatus: nil
                )
                store.add(notification)
                store.markFired(dedupKey: dedupKey)
            }
        }
    }

    // MARK: - 3. Payment Successful

    static func recordPaymentSuccess(
        transactionID: String,
        loanId: String?
    ) {
        let store = NotificationStore.shared
        let dedupKey = "notif_payment_\(transactionID)"
        guard !store.hasAlreadyFired(dedupKey: dedupKey) else { return }

        let notification = AppNotification(
            id: UUID(),
            title: "Payment Successful",
            body: "Your payment was processed successfully. Transaction ID: \(transactionID).",
            type: .paymentSuccess,
            isRead: false,
            createdAt: Date(),
            applicationId: nil,
            loanId: loanId,
            emiScheduleId: nil,
            emiAmount: nil,
            transactionID: transactionID,
            applicationStatus: nil
        )
        store.add(notification)
        store.markFired(dedupKey: dedupKey)
    }

    // MARK: - 4. KYC Reminder (once per calendar day)

    static func checkKYCReminder(kycStatus: KYCStatus) {
        guard kycStatus == .notStarted || kycStatus == .pending else { return }

        let store = NotificationStore.shared
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let todayString = dateFormatter.string(from: Date())

        let dedupKey = "notif_kyc_reminder_\(todayString)"
        guard !store.hasAlreadyFired(dedupKey: dedupKey) else { return }

        let notification = AppNotification(
            id: UUID(),
            title: "Complete Your KYC",
            body: "Your KYC verification is pending. Complete it to unlock loan eligibility.",
            type: .kycReminder,
            isRead: false,
            createdAt: Date(),
            applicationId: nil,
            loanId: nil,
            emiScheduleId: nil,
            emiAmount: nil,
            transactionID: nil,
            applicationStatus: nil
        )
        store.add(notification)
        store.markFired(dedupKey: dedupKey)
    }

    // MARK: - 5. KYC Completed (one-time)

    static func checkKYCCompleted(kycStatus: KYCStatus) {
        guard kycStatus == .approved else { return }

        let store = NotificationStore.shared
        let dedupKey = "notif_kyc_completed"
        guard !store.hasAlreadyFired(dedupKey: dedupKey) else { return }

        let notification = AppNotification(
            id: UUID(),
            title: "KYC Verified ✓",
            body: "Your KYC has been successfully verified. You are now eligible to apply for loans.",
            type: .kycCompleted,
            isRead: false,
            createdAt: Date(),
            applicationId: nil,
            loanId: nil,
            emiScheduleId: nil,
            emiAmount: nil,
            transactionID: nil,
            applicationStatus: nil
        )
        store.add(notification)
        store.markFired(dedupKey: dedupKey)
    }

    // MARK: - Private Helpers

    private static func parseDate(_ raw: String) -> Date {
        if let date = ISO8601DateFormatter().date(from: raw) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw) ?? .distantPast
    }

    private static func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private static func formatINR(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }
}
