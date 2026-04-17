//
//  ActionPanel.swift
//  lms_project
//

import SwiftUI

// MARK: - Loan Officer Action Panel

struct LOActionPanel: View {
    let onRecommend: () -> Void
    let onReject: () -> Void
    let onRequestDocs: () -> Void
    
    @State private var showRejectAlert = false
    @State private var isFraud = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Divider()
            
            HStack(spacing: Theme.Spacing.md) {
                // Request Documents
                Button(action: onRequestDocs) {
                    Label("Request Docs", systemImage: "doc.badge.plus")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                
                // Reject
                Button {
                    showRejectAlert = true
                } label: {
                    Label("Reject", systemImage: "xmark.circle")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.critical)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.critical.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                
                // Recommend
                Button(action: onRecommend) {
                    Label("Recommend", systemImage: "arrow.up.circle.fill")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .alert("Reject Application", isPresented: $showRejectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) { onReject() }
            Button("Reject as Fraud", role: .destructive) {
                isFraud = true
                onReject()
            }
        } message: {
            Text("Are you sure you want to reject this application? You can also flag it as potential fraud.")
        }
    }
}

// MARK: - Manager Action Panel

struct ManagerActionPanel: View {
    let onApprove: () -> Void
    let onReject: () -> Void
    let onSendBack: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Divider()
            
            HStack(spacing: Theme.Spacing.md) {
                // Send Back
                Button(action: onSendBack) {
                    Label("Send Back", systemImage: "arrow.uturn.left")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                
                // Reject
                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark.circle")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.critical)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.critical.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                
                // Approve
                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.success)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
    }
}
