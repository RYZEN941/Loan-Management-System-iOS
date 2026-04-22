//
//  AdminLoansView.swift
//  lms_project
//
//  Repurposed for Loan Product Management
//

import SwiftUI

struct AdminLoansView: View {
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Binding var showProfile: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.lg),
        GridItem(.flexible(), spacing: Theme.Spacing.lg)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Search loan products...", text: Binding(
                                get: { loansVM.searchText },
                                set: { loansVM.searchText = $0 }
                            ))
                                .font(Theme.Typography.subheadline)
                        }
                        .padding(12)
                        .background(Theme.Colors.adaptiveSurface(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
                        )
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)
                        
                        // Header
                        HStack {
                            Text("Available Loan Products")
                                .font(Theme.Typography.title)
                            Spacer()
                            Text("\(loansVM.filteredProducts.count) total")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        
                        // Grid of Cards
                        if loansVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 400)
                        } else if loansVM.filteredProducts.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                                ForEach(loansVM.filteredProducts) { product in
                                    LoanProductCard(product: product)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Loans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            loansVM.showAddLoanSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Loan")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        ProfileNavButton(showProfile: $showProfile)
                    }
                }
            }
            .onAppear { loansVM.loadData() }
            .sheet(isPresented: Binding(
                get: { loansVM.showAddLoanSheet },
                set: { loansVM.showAddLoanSheet = $0 }
            )) {
                AddLoanSheet()
                    .environmentObject(loansVM)
            }
            .alert(loansVM.actionMessage ?? "", isPresented: Binding(
                get: { loansVM.showActionAlert },
                set: { loansVM.showActionAlert = $0 }
            )) {
                Button("OK", role: .cancel) {}
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No loan products found")
                .font(Theme.Typography.headline)
                .foregroundStyle(.secondary)
            Text("Try a different search term or add a new product.")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}

// MARK: - Loan Product Card

struct LoanProductCard: View {
    let product: LoanProduct
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Colors.primary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: product.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(Theme.Typography.headline)
                    Text(product.category)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .foregroundStyle(Theme.Colors.primary)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Button {
                    loansVM.deleteLoanProduct(product)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(8)
                        .background(Color.red.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Text(product.description)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(height: 36, alignment: .top)
            
            Divider()
            
            HStack(spacing: 0) {
                cardKPI(title: "Interest", value: "\(product.interestRate)%", icon: "percent")
                divider
                cardKPI(title: "Max Amount", value: product.maxAmount.shortCurrency, icon: "indianrupeesign")
                divider
                cardKPI(title: "Tenure", value: "\(product.maxTenure)m", icon: "calendar")
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle(colorScheme: colorScheme)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Theme.Colors.adaptiveBorder(colorScheme))
            .frame(width: 0.5, height: 24)
            .padding(.horizontal, Theme.Spacing.sm)
    }
    
    private func cardKPI(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(Theme.Typography.caption2)
            }
            .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Add Loan Sheet

struct AddLoanSheet: View {
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name = ""
    @State private var description = ""
    @State private var category = "Asset"
    @State private var interestRate = ""
    @State private var maxAmount = ""
    @State private var maxTenure = ""
    @State private var selectedIcon = "house.fill"
    
    let icons = ["house.fill", "car.fill", "person.fill", "briefcase.fill", "box.truck.fill", "leaf.fill", "graduationcap.fill", "medicalpalette.fill"]
    let categories = ["Asset", "Personal", "Business", "Education", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Loan Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                
                Section("Financial Details") {
                    HStack {
                        Text("Interest Rate (%)")
                        Spacer()
                        TextField("8.5", text: $interestRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Max Amount (₹)")
                        Spacer()
                        TextField("1,000,000", text: $maxAmount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Max Tenure (Months)")
                        Spacer()
                        TextField("120", text: $maxTenure)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Section("Visual Style") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(icons, id: \.self) { icon in
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: icon)
                                        .foregroundStyle(selectedIcon == icon ? .white : Theme.Colors.primary)
                                }
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Add New Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.isEmpty || interestRate.isEmpty || maxAmount.isEmpty)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func save() {
        let product = LoanProduct(
            name: name,
            description: description,
            icon: selectedIcon,
            interestRate: Double(interestRate) ?? 0.0,
            maxAmount: Double(maxAmount) ?? 0.0,
            maxTenure: Int(maxTenure) ?? 0,
            category: category
        )
        loansVM.addLoanProduct(product)
    }
}

// MARK: - Helper Extension

private extension Double {
    var shortCurrency: String {
        if self >= 10_000_000 { return "₹\(String(format: "%.1f", self / 10_000_000))Cr" }
        if self >= 100_000    { return "₹\(String(format: "%.0f", self / 100_000))L" }
        if self >= 1_000      { return "₹\(String(format: "%.0f", self / 1_000))K" }
        return "₹\(String(format: "%.0f", self))"
    }
}
