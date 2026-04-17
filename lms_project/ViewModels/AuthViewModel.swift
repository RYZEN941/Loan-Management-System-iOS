//
//  AuthViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var currentRole: UserRole? = nil
    @Published var currentUser: User? = nil
    
    private let dataService = MockDataService.shared
    
    var isLoggedIn: Bool {
        currentRole != nil
    }
    
    func login(as role: UserRole) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentRole = role
            currentUser = dataService.currentUser(role: role)
        }
    }
    
    func logout() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentRole = nil
            currentUser = nil
        }
    }
}
