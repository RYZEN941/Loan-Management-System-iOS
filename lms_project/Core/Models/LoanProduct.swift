//
//  LoanProduct.swift
//  lms_project
//

import Foundation

struct LoanProduct: Identifiable, Codable {
    var id: UUID
    var name: String
    var description: String
    var icon: String         // SF Symbol name
    var interestRate: Double // e.g., 8.5
    var maxAmount: Double    // e.g., 5000000
    var maxTenure: Int       // months
    var category: String     // e.g., "Personal", "Asset", "Business"
    
    init(id: UUID = UUID(), 
         name: String, 
         description: String, 
         icon: String, 
         interestRate: Double, 
         maxAmount: Double, 
         maxTenure: Int, 
         category: String) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.interestRate = interestRate
        self.maxAmount = maxAmount
        self.maxTenure = maxTenure
        self.category = category
    }
}
