//
//  MockDataService.swift
//  lms_project
//

import Foundation

// MARK: - LMS Data Service Protocol

protocol LMSDataService {
    func fetchApplications() -> [LoanApplication]
    func fetchApplication(id: String) -> LoanApplication?
    func fetchConversations() -> [Conversation]
    func fetchMessages(conversationId: String) -> [Message]
    func fetchUsers() -> [User]
    func currentUser(role: UserRole) -> User
    func fetchApplicationMessages(applicationId: String) -> [ApplicationMessage]
}

// MARK: - Mock Data Service

class MockDataService: LMSDataService {
    static let shared = MockDataService()
    
    private init() {}
    
    // MARK: - Current User
    
    func currentUser(role: UserRole) -> User {
        switch role {
        case .loanOfficer:
            return User(
                id: "LO-001",
                name: "Amit Singh",
                email: "amit.singh@bank.com",
                role: .loanOfficer,
                branch: "Mumbai Central",
                phone: "+91-9876543210",
                isActive: true,
                joinedAt: Calendar.current.date(byAdding: .year, value: -2, to: Date())!
            )
        case .manager:
            return User(
                id: "MGR-001",
                name: "Deepak Mehta",
                email: "deepak.mehta@bank.com",
                role: .manager,
                branch: "Mumbai Central",
                phone: "+91-9876543211",
                isActive: true,
                joinedAt: Calendar.current.date(byAdding: .year, value: -5, to: Date())!
            )
        case .admin:
            return User(
                id: "ADM-001",
                name: "Sunita Patel",
                email: "sunita.patel@bank.com",
                role: .admin,
                branch: "Head Office",
                phone: "+91-9876543212",
                isActive: true,
                joinedAt: Calendar.current.date(byAdding: .year, value: -8, to: Date())!
            )
        }
    }
    
    // MARK: - Applications
    
    func fetchApplications() -> [LoanApplication] {
        return [
            makeApplication(
                id: "APP-2024-001", name: "Rajesh Kumar", employer: "TCS",
                amount: 2500000, type: .homeLoan, status: .underReview,
                risk: .medium, cibil: 720, income: 125000, dti: 0.29,
                daysFromNow: 5
            ),
            makeApplication(
                id: "APP-2024-002", name: "Priya Sharma", employer: "Infosys",
                amount: 500000, type: .personalLoan, status: .new,
                risk: .low, cibil: 785, income: 95000, dti: 0.15,
                daysFromNow: 7
            ),
            makeApplication(
                id: "APP-2024-003", name: "Vikram Desai", employer: "Reliance Industries",
                amount: 8000000, type: .homeLoan, status: .recommended,
                risk: .low, cibil: 810, income: 250000, dti: 0.22,
                daysFromNow: 3
            ),
            makeApplication(
                id: "APP-2024-004", name: "Anita Reddy", employer: "Wipro",
                amount: 1500000, type: .vehicleLoan, status: .underReview,
                risk: .medium, cibil: 690, income: 85000, dti: 0.35,
                daysFromNow: 2
            ),
            makeApplication(
                id: "APP-2024-005", name: "Suresh Nair", employer: "Self Employed",
                amount: 5000000, type: .businessLoan, status: .underReview,
                risk: .high, cibil: 640, income: 200000, dti: 0.45,
                daysFromNow: 1
            ),
            makeApplication(
                id: "APP-2024-006", name: "Meera Joshi", employer: "HDFC Bank",
                amount: 300000, type: .personalLoan, status: .approved,
                risk: .low, cibil: 800, income: 110000, dti: 0.12,
                daysFromNow: -2
            ),
            makeApplication(
                id: "APP-2024-007", name: "Karan Malhotra", employer: "Startup Inc",
                amount: 3500000, type: .homeLoan, status: .sentBack,
                risk: .high, cibil: 660, income: 150000, dti: 0.40,
                daysFromNow: 4
            ),
            makeApplication(
                id: "APP-2024-008", name: "Fatima Sheikh", employer: "Government",
                amount: 2000000, type: .homeLoan, status: .recommended,
                risk: .low, cibil: 760, income: 105000, dti: 0.25,
                daysFromNow: 6
            ),
            makeApplication(
                id: "APP-2024-009", name: "Arjun Patel", employer: "Amazon India",
                amount: 1000000, type: .educationLoan, status: .new,
                risk: .low, cibil: 750, income: 0, dti: 0.0,
                daysFromNow: 8
            ),
            makeApplication(
                id: "APP-2024-010", name: "Divya Krishnan", employer: "HCL Technologies",
                amount: 4500000, type: .homeLoan, status: .rejected,
                risk: .high, cibil: 580, income: 95000, dti: 0.52,
                daysFromNow: -5
            ),
            makeApplication(
                id: "APP-2024-011", name: "Rohan Gupta", employer: "Google India",
                amount: 6000000, type: .homeLoan, status: .underReview,
                risk: .low, cibil: 830, income: 350000, dti: 0.18,
                daysFromNow: 4
            ),
            makeApplication(
                id: "APP-2024-012", name: "Sneha Iyer", employer: "Deloitte",
                amount: 750000, type: .personalLoan, status: .assigned,
                risk: .medium, cibil: 710, income: 90000, dti: 0.28,
                daysFromNow: 6
            )
        ]
    }
    
    func fetchApplication(id: String) -> LoanApplication? {
        fetchApplications().first { $0.id == id }
    }
    
    // MARK: - Conversations
    
    func fetchConversations() -> [Conversation] {
        return [
            Conversation(id: "CONV-001", participantName: "Rajesh Kumar", participantRole: "Borrower",
                         lastMessage: "I have uploaded the bank statement.", lastMessageTime: Date().addingTimeInterval(-3600),
                         unreadCount: 2, isOnline: true),
            Conversation(id: "CONV-002", participantName: "Priya Sharma", participantRole: "Borrower",
                         lastMessage: "When will I receive an update?", lastMessageTime: Date().addingTimeInterval(-7200),
                         unreadCount: 1, isOnline: false),
            Conversation(id: "CONV-003", participantName: "Neha Kapoor", participantRole: "Loan Officer",
                         lastMessage: "Can you review APP-2024-005?", lastMessageTime: Date().addingTimeInterval(-14400),
                         unreadCount: 0, isOnline: true),
            Conversation(id: "CONV-004", participantName: "Vikram Desai", participantRole: "Borrower",
                         lastMessage: "Thank you for the update.", lastMessageTime: Date().addingTimeInterval(-86400),
                         unreadCount: 0, isOnline: false),
            Conversation(id: "CONV-005", participantName: "Ravi Shankar", participantRole: "Loan Officer",
                         lastMessage: "Meeting at 3 PM today.", lastMessageTime: Date().addingTimeInterval(-28800),
                         unreadCount: 0, isOnline: true)
        ]
    }
    
    // MARK: - Messages
    
    func fetchMessages(conversationId: String) -> [Message] {
        switch conversationId {
        case "CONV-001":
            return [
                Message(id: "MSG-001", conversationId: "CONV-001", senderId: "BOR-001", senderName: "Rajesh Kumar",
                        text: "Hello, I wanted to check on my loan application status.", timestamp: Date().addingTimeInterval(-86400),
                        isFromCurrentUser: false),
                Message(id: "MSG-002", conversationId: "CONV-001", senderId: "LO-001", senderName: "Amit Singh",
                        text: "Hi Rajesh, your application is under review. We need your latest bank statement.",
                        timestamp: Date().addingTimeInterval(-82800), isFromCurrentUser: true),
                Message(id: "MSG-003", conversationId: "CONV-001", senderId: "BOR-001", senderName: "Rajesh Kumar",
                        text: "Sure, I will upload it today.", timestamp: Date().addingTimeInterval(-79200),
                        isFromCurrentUser: false),
                Message(id: "MSG-004", conversationId: "CONV-001", senderId: "BOR-001", senderName: "Rajesh Kumar",
                        text: "I have uploaded the bank statement.", timestamp: Date().addingTimeInterval(-3600),
                        isFromCurrentUser: false, attachmentName: "bank_statement_nov_2024.pdf")
            ]
        default:
            return [
                Message(id: "MSG-D01", conversationId: conversationId, senderId: "OTHER", senderName: "Participant",
                        text: "Hello, how can I help you?", timestamp: Date().addingTimeInterval(-7200),
                        isFromCurrentUser: false),
                Message(id: "MSG-D02", conversationId: conversationId, senderId: "LO-001", senderName: "Amit Singh",
                        text: "I need to discuss an application.", timestamp: Date().addingTimeInterval(-3600),
                        isFromCurrentUser: true)
            ]
        }
    }
    
    // MARK: - Users
    
    func fetchUsers() -> [User] {
        return [
            User(id: "LO-001", name: "Amit Singh", email: "amit.singh@bank.com", role: .loanOfficer,
                 branch: "Mumbai Central", phone: "+91-9876543210", isActive: true,
                 joinedAt: Calendar.current.date(byAdding: .year, value: -2, to: Date())!),
            User(id: "LO-002", name: "Neha Kapoor", email: "neha.kapoor@bank.com", role: .loanOfficer,
                 branch: "Mumbai Central", phone: "+91-9876543213", isActive: true,
                 joinedAt: Calendar.current.date(byAdding: .year, value: -1, to: Date())!),
            User(id: "LO-003", name: "Ravi Shankar", email: "ravi.shankar@bank.com", role: .loanOfficer,
                 branch: "Delhi North", phone: "+91-9876543214", isActive: true,
                 joinedAt: Calendar.current.date(byAdding: .month, value: -8, to: Date())!),
            User(id: "MGR-001", name: "Deepak Mehta", email: "deepak.mehta@bank.com", role: .manager,
                 branch: "Mumbai Central", phone: "+91-9876543211", isActive: true,
                 joinedAt: Calendar.current.date(byAdding: .year, value: -5, to: Date())!),
            User(id: "MGR-002", name: "Lakshmi Rao", email: "lakshmi.rao@bank.com", role: .manager,
                 branch: "Bangalore South", phone: "+91-9876543215", isActive: true,
                 joinedAt: Calendar.current.date(byAdding: .year, value: -4, to: Date())!),
            User(id: "ADM-001", name: "Sunita Patel", email: "sunita.patel@bank.com", role: .admin,
                 branch: "Head Office", phone: "+91-9876543212", isActive: true,
                 joinedAt: Calendar.current.date(byAdding: .year, value: -8, to: Date())!),
            User(id: "LO-004", name: "Prakash Jha", email: "prakash.jha@bank.com", role: .loanOfficer,
                 branch: "Delhi North", phone: "+91-9876543216", isActive: false,
                 joinedAt: Calendar.current.date(byAdding: .year, value: -3, to: Date())!)
        ]
    }
    
    // MARK: - Application Messages (Per-Application Chat)
    
    func fetchApplicationMessages(applicationId: String) -> [ApplicationMessage] {
        var msgs: [ApplicationMessage] = []
        
        // Borrower initial message
        msgs.append(ApplicationMessage(
            id: "\(applicationId)-AM-01", applicationId: applicationId,
            senderId: "BOR-001", senderName: "Borrower", senderRole: "Borrower",
            text: "I have submitted all the required documents for my loan application.",
            timestamp: Date().addingTimeInterval(-259200), type: .message,
            isFromCurrentUser: false
        ))
        
        // LO response
        msgs.append(ApplicationMessage(
            id: "\(applicationId)-AM-02", applicationId: applicationId,
            senderId: "LO-001", senderName: "Amit Singh", senderRole: "Loan Officer",
            text: "Thank you. I am reviewing your documents now. Will update you shortly.",
            timestamp: Date().addingTimeInterval(-172800), type: .message,
            isFromCurrentUser: true
        ))
        
        // LO note
        msgs.append(ApplicationMessage(
            id: "\(applicationId)-AM-03", applicationId: applicationId,
            senderId: "LO-001", senderName: "Amit Singh", senderRole: "Loan Officer",
            text: "Income documents verified. Bank statement looks consistent.",
            timestamp: Date().addingTimeInterval(-86400), type: .message,
            isFromCurrentUser: true
        ))
        
        // Manager remark (only for recommended/approved/rejected/sentBack apps)
        if ["APP-2024-003", "APP-2024-006", "APP-2024-007", "APP-2024-008"].contains(applicationId) {
            msgs.append(ApplicationMessage(
                id: "\(applicationId)-AM-04", applicationId: applicationId,
                senderId: "MGR-001", senderName: "Deepak Mehta", senderRole: "Manager",
                text: "Please verify property documents before approval. Also confirm employer details with HR.",
                timestamp: Date().addingTimeInterval(-43200), type: .managerRemark,
                isFromCurrentUser: false
            ))
        }
        
        // Borrower follow-up
        msgs.append(ApplicationMessage(
            id: "\(applicationId)-AM-05", applicationId: applicationId,
            senderId: "BOR-001", senderName: "Borrower", senderRole: "Borrower",
            text: "Any updates on my application? Please let me know if you need anything else.",
            timestamp: Date().addingTimeInterval(-3600), type: .message,
            isFromCurrentUser: false
        ))
        
        return msgs
    }
    
    // MARK: - Private Helpers
    
    private func makeApplication(
        id: String, name: String, employer: String,
        amount: Double, type: LoanType, status: ApplicationStatus,
        risk: RiskLevel, cibil: Int, income: Double, dti: Double,
        daysFromNow: Int
    ) -> LoanApplication {
        let createdAt = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let slaDeadline = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        let dob = Calendar.current.date(byAdding: .year, value: -35, to: Date())!
        let emi = (amount * 0.008)
        
        return LoanApplication(
            id: id,
            borrower: Borrower(
                name: name,
                dob: dob,
                address: "42, Marine Drive, Mumbai, Maharashtra 400001",
                employer: employer,
                employmentType: employer == "Self Employed" ? "Self Employed" : "Salaried",
                phone: "+91-98765\(id.suffix(5).hashValue % 90000 + 10000)",
                email: "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@email.com"
            ),
            loan: LoanDetails(
                amount: amount,
                type: type,
                tenure: type == .homeLoan ? 240 : (type == .personalLoan ? 36 : 60),
                interestRate: type == .homeLoan ? 8.5 : (type == .personalLoan ? 12.0 : 10.0),
                emi: emi
            ),
            financials: Financials(
                monthlyIncome: income,
                annualIncome: income * 12,
                existingEMI: income * dti * 0.5,
                dtiRatio: dti,
                cibilScore: cibil,
                bankBalance: income * 3.5
            ),
            documents: [
                LoanDocument(id: "\(id)-DOC-1", type: .panCard, label: "PAN Card",
                             status: status == .new ? .pending : .verified,
                             uploadedAt: status == .new ? nil : createdAt),
                LoanDocument(id: "\(id)-DOC-2", type: .aadhaar, label: "Aadhaar Card",
                             status: status == .new ? .pending : (risk == .high ? .pending : .verified),
                             uploadedAt: risk == .high ? nil : createdAt),
                LoanDocument(id: "\(id)-DOC-3", type: .bankStatement, label: "Bank Statement",
                             status: risk == .high ? .pending : .uploaded,
                             uploadedAt: risk == .high ? nil : createdAt.addingTimeInterval(86400))
            ],
            verification: [
                VerificationItem(id: "\(id)-VER-1", field: "PAN Name",
                                 declaredValue: name, extractedValue: name, isMatch: true),
                VerificationItem(id: "\(id)-VER-2", field: "Monthly Income",
                                 declaredValue: income.currencyFormatted,
                                 extractedValue: (income * (risk == .high ? 0.85 : 0.95)).currencyFormatted,
                                 isMatch: risk != .high),
                VerificationItem(id: "\(id)-VER-3", field: "Employer Name",
                                 declaredValue: employer,
                                 extractedValue: employer,
                                 isMatch: true)
            ],
            notes: [
                Note(id: "\(id)-NOTE-1", author: "Amit Singh (LO)",
                     text: "Initial review completed. \(risk == .high ? "High risk flagged — needs additional verification." : "Documents look good.")",
                     timestamp: createdAt.addingTimeInterval(172800))
            ],
            internalRemarks: [],
            status: status,
            assignedTo: "LO-001",
            branch: "Mumbai Central",
            riskLevel: risk,
            createdAt: createdAt,
            slaDeadline: slaDeadline
        )
    }
}
