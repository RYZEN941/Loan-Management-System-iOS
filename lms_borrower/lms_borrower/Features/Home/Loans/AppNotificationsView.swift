import SwiftUI

struct AppNotificationsView: View {
    @ObservedObject private var store = NotificationStore.shared
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerBar

                if store.notifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications")
                    .font(.largeTitle).bold()
                Text(store.unreadCount == 0
                    ? "You're all caught up."
                    : "You have \(store.unreadCount) unread notification\(store.unreadCount == 1 ? "" : "s").")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if store.hasUnread {
                Button("Mark all read") { store.markAllRead() }
                    .font(.subheadline.bold())
                    .foregroundColor(.mainBlue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - List

    private var notificationsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(store.notifications) { notif in
                NotificationRowView(notification: notif) {
                    handleTap(notif)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.delete(id: notif.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.top, 60)
            Text("No Notifications Yet")
                .font(.title3.bold())
            Text("Updates about your loans, EMIs, and KYC will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Deep Link Navigation

    private func handleTap(_ notif: AppNotification) {
        store.markRead(id: notif.id)
        switch notif.type {
        case .statusChange:
            break
        case .kycReminder, .kycCompleted:
            router.push(.kycStatus)
        case .emiDue:
            if let loanId = notif.loanId,
               let emiId = notif.emiScheduleId,
               let amount = notif.emiAmount {
                router.push(.paymentCheckout(loanId: loanId, emiScheduleId: emiId, amount: amount))
            }
        case .paymentSuccess:
            if let loanId = notif.loanId, !loanId.isEmpty {
                router.push(.repaymentsList(loanId: loanId, initialTab: 0))
            }
        }
    }
}

// MARK: - NotificationRowView

struct NotificationRowView: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: notification.type.icon)
                    .font(.title3)
                    .foregroundColor(notification.type.color)
                    .frame(width: 44, height: 44)
                    .background(notification.type.color.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(notification.createdAt.relativeFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(notification.body)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                }

                if !notification.isRead {
                    Circle()
                        .fill(DS.primary)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                }
            }
            .padding(16)
            .background(notification.isRead ? Color.white : DS.primaryLight.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppNotificationsView()
}
