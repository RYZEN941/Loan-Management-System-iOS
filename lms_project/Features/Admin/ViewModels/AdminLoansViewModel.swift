//
//  AdminLoansViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - Admin Loans View Model

class AdminLoansViewModel: ObservableObject {

    // MARK: Published State
    @Published var loanProducts: [LoanProduct] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var actionMessage: String? = nil
    @Published var showActionAlert = false
    @Published var showAddLoanSheet = false
    
    // MARK: - Legacy Compatibility (DO NOT REMOVE - used by Dashboard)
    @Published var applications: [LoanApplication] = [] // Kept for type compatibility
    var totalCount: Int { loanProducts.count }
    var pendingCount: Int { 0 }
    var underReviewCount: Int { 0 }
    var approvedCount: Int { loanProducts.count }
    var rejectedCount: Int { 0 }

    // MARK: - Filtered
    
    var filteredProducts: [LoanProduct] {
        if searchText.isEmpty {
            return loanProducts
        }
        return loanProducts.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) || 
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Load
    
    func loadData() {
        isLoading = true
        // Mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.loanProducts = [
                LoanProduct(name: "Home Loan", 
                            description: "Flexible financing for your dream home with competitive rates.", 
                            icon: "house.fill", 
                            interestRate: 8.5, 
                            maxAmount: 15000000, 
                            maxTenure: 240, 
                            category: "Asset"),
                LoanProduct(name: "Car Loan", 
                            description: "Drive your dream car with easy EMI options and quick approval.", 
                            icon: "car.fill", 
                            interestRate: 9.2, 
                            maxAmount: 5000000, 
                            maxTenure: 84, 
                            category: "Asset"),
                LoanProduct(name: "Personal Loan", 
                            description: "Instant funds for your personal needs, weddings, or travel.", 
                            icon: "person.fill", 
                            interestRate: 11.5, 
                            maxAmount: 2000000, 
                            maxTenure: 60, 
                            category: "Personal"),
                LoanProduct(name: "Business Loan", 
                            description: "Empower your business growth with our tailored financial solutions.", 
                            icon: "briefcase.fill", 
                            interestRate: 10.0, 
                            maxAmount: 10000000, 
                            maxTenure: 120, 
                            category: "Business"),
                LoanProduct(name: "Vehicle Loan", 
                            description: "Affordable loans for two-wheelers and commercial vehicles.", 
                            icon: "box.truck.fill", 
                            interestRate: 9.8, 
                            maxAmount: 1500000, 
                            maxTenure: 48, 
                            category: "Asset")
            ]
            self.isLoading = false
        }
    }

    // MARK: - Actions
    
    func addLoanProduct(_ product: LoanProduct) {
        withAnimation {
            loanProducts.insert(product, at: 0)
        }
        actionMessage = "Loan '\(product.name)' added successfully!"
        showActionAlert = true
        showAddLoanSheet = false
    }
    
    func deleteLoanProduct(at indexSet: IndexSet) {
        loanProducts.remove(atOffsets: indexSet)
    }
    
    func deleteLoanProduct(_ product: LoanProduct) {
        if let index = loanProducts.firstIndex(where: { $0.id == product.id }) {
            withAnimation {
                loanProducts.remove(at: index)
            }
        }
    }
}
