//
//  LoginView.swift
//  lms_project
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedRole: UserRole? = nil
    @State private var isAnimating = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.xxl) {
                    Spacer()
                    
                    // Logo & Title
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.primary.opacity(0.1))
                                .frame(width: 88, height: 88)
                            
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.Colors.primary)
                        }
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        
                        Text("Loan Management System")
                            .font(Theme.Typography.titleLarge)
                            .foregroundStyle(.primary)
                        
                        Text("Select your role to continue")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, Theme.Spacing.lg)
                    
                    // Role Cards
                    HStack(spacing: Theme.Spacing.lg) {
                        ForEach(UserRole.allCases) { role in
                            RoleCard(
                                role: role,
                                isSelected: selectedRole == role,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedRole = role
                                    }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: 700)
                    
                    // Login Button
                    Button {
                        if let role = selectedRole {
                            authVM.login(as: role)
                        }
                    } label: {
                        Text("Continue")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(width: 280, height: Theme.Layout.buttonHeight)
                            .background(selectedRole != nil ? Theme.Colors.primary : Theme.Colors.neutral.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedRole == nil)
                    
                    Spacer()
                    
                    // Footer
                    Text("v1.0 • Internal Staff Application")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, Theme.Spacing.lg)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Role Card

private struct RoleCard: View {
    let role: UserRole
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.Colors.primary.opacity(0.15) : Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: role.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? Theme.Colors.primary : Theme.Colors.neutral)
                }
                
                Text(role.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(isSelected ? Theme.Colors.primary : .primary)
                
                Text(roleDescription)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.adaptiveBorder(colorScheme), lineWidth: isSelected ? 2 : 0.5)
            )
            .shadow(color: isSelected ? Theme.Colors.primary.opacity(0.1) : Theme.Shadows.subtle, radius: isSelected ? 8 : 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private var roleDescription: String {
        switch role {
        case .loanOfficer: return "Process & review loan applications"
        case .manager: return "Approve & manage loan portfolio"
        case .admin: return "System configuration & user management"
        }
    }
}
