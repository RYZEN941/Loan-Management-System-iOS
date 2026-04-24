//
//  ActionPanel.swift
//  lms_project
//

import SwiftUI

// MARK: - Loan Officer Action Panel

struct LOActionPanel: View {
    let onSendToManager: () -> Void
    let onReject: () -> Void
    let onRequestDocs: () -> Void
    
    @State private var showRejectAlert = false
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
                
                // Send to Manager
                Button(action: onSendToManager) {
                    Label("Send to Manager", systemImage: "arrow.up.circle.fill")
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
        } message: {
            Text("Are you sure you want to reject this application?")
        }
    }
}

// MARK: - Manager Action Panel

struct ManagerActionPanel: View {
    let onApprove: () -> Void
    let onRejectWithRemarks: () -> Void   // triggers remarks sheet
    let onSendBack: () -> Void
    var onEditTerms: (() -> Void)? = nil
    var onAssignOfficer: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Divider()

            // Row 1: Secondary actions
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
                Button(action: onRejectWithRemarks) {
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
            }

            // Row 2: Edit actions + final Approve
            HStack(spacing: Theme.Spacing.md) {
                // Edit Terms (calls UpdateLoanApplicationTerms)
                Button { onEditTerms?() } label: {
                    Label("Edit Terms", systemImage: "pencil.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)

                // Assign Officer (fallback alert — backend list not available)
                Button { onAssignOfficer?() } label: {
                    Label("Assign Officer", systemImage: "person.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    Text("N/A")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -6)
                }

                // Approve
                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.Colors.success)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
    }
}

