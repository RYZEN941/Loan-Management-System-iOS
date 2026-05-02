# Architecture Document — Loan Management System

## 1. Architecture Pattern: MVVM

The application follows the **Model-View-ViewModel (MVVM)** pattern, which is the recommended architecture for SwiftUI applications.

```
┌─────────────────────────────────────────────────┐
│                    Views                         │
│  (SwiftUI Views — declarative UI)               │
│  Observes ViewModels via @StateObject            │
├─────────────────────────────────────────────────┤
│                  ViewModels                      │
│  (ObservableObject classes)                      │
│  Business logic, state management                │
│  Calls Services for data                         │
├─────────────────────────────────────────────────┤
│                   Services                       │
│  (Protocol-based abstraction)                    │
│  MockDataService / future APIService             │
│  XMLParserService                                │
├─────────────────────────────────────────────────┤
│                    Models                        │
│  (Swift structs — Codable, Identifiable)         │
│  Pure data representations                       │
└─────────────────────────────────────────────────┘
```

---

## 2. Folder Structure

```
lms_project/
├── lms_projectApp.swift              # App entry point
├── Assets.xcassets/                  # Asset catalog
│
├── Models/
│   ├── User.swift                    # User model (id, name, role, branch)
│   ├── LoanApplication.swift         # Core application model
│   ├── Document.swift                # Document model (type, status, URL)
│   ├── Message.swift                 # Chat message model
│   └── Enums.swift                   # UserRole, ApplicationStatus, DocumentStatus, etc.
│
├── Services/
│   ├── MockDataService.swift         # In-memory mock data + protocol definition
│   └── XMLParserService.swift        # XML file parsing logic
│
├── ViewModels/
│   ├── AuthViewModel.swift           # Login state, role selection, current user
│   ├── DashboardViewModel.swift      # KPI computation, active workspace state
│   ├── ApplicationsViewModel.swift   # Application list, filtering, detail state
│   ├── MessagesViewModel.swift       # Chat conversations, message sending
│   └── AdminViewModel.swift          # User management, system config state
│
├── Views/
│   ├── RootView.swift                # Role-based router
│   ├── LoginView.swift               # Role selection / login screen
│   ├── LoanOfficer/
│   │   ├── LOTabView.swift           # 4-tab layout
│   │   ├── LODashboardView.swift     # KPIs + split workspace
│   │   ├── LOApplicationsView.swift  # Full detail (6 sections)
│   │   ├── LOMessagesView.swift      # Chat UI
│   │   └── LOProfileView.swift       # Profile + logout
│   ├── Manager/
│   │   ├── ManagerTabView.swift      # 5-tab layout
│   │   ├── ManagerDashboardView.swift
│   │   ├── ManagerApprovalsView.swift
│   │   ├── ManagerPortfolioView.swift
│   │   ├── ManagerMessagesView.swift
│   │   └── ManagerProfileView.swift
│   └── Admin/
│       ├── AdminTabView.swift        # 5-tab layout
│       ├── AdminDashboardView.swift
│       ├── AdminUsersView.swift
│       ├── AdminSystemControlView.swift
│       ├── AdminMessagesView.swift
│       └── AdminProfileView.swift
│
├── Components/
│   ├── ApplicationRow.swift          # Reusable list row
│   ├── StatusBadge.swift             # Color-coded status pill
│   ├── CardView.swift                # KPI card wrapper
│   ├── ActionPanel.swift             # Action buttons (Recommend, Reject, etc.)
│   ├── DocumentRow.swift             # Document list item
│   ├── VerificationRow.swift         # AI/OCR match/mismatch row
│   ├── MessageBubble.swift           # Chat bubble
│   ├── KPIStripView.swift            # Horizontal KPI card strip
│   └── SectionHeader.swift           # Reusable section header
│
└── Utils/
    ├── Theme.swift                   # Design tokens (colors, fonts, spacing)
    └── Extensions.swift              # Date formatters, number formatters
```

---

## 3. State Management

### Pattern: `ObservableObject` + `@StateObject` + `@EnvironmentObject`

| Layer | Usage |
|-------|-------|
| `@StateObject` | ViewModel ownership at the top-level view that creates it |
| `@EnvironmentObject` | Shared state injected into the view hierarchy (e.g., `AuthViewModel`) |
| `@Published` | Properties in ViewModels that trigger view updates |
| `@State` / `@Binding` | Local UI state within views |

### ViewModel Lifecycle

```swift
// App entry — owns AuthViewModel
@main
struct lms_projectApp: App {
    @StateObject private var authVM = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
        }
    }
}

// Tab-level — owns feature ViewModels
struct LOTabView: View {
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var applicationsVM = ApplicationsViewModel()
    @StateObject private var messagesVM = MessagesViewModel()
    // ...
}
```

---

## 4. API Layer Abstraction

### Protocol-based design for future backend integration:

```swift
protocol LMSDataService {
    func fetchApplications() async throws -> [LoanApplication]
    func fetchApplication(id: String) async throws -> LoanApplication
    func performAction(applicationId: String, action: ApplicationAction) async throws
    func uploadXML(data: Data) async throws -> XMLParseResult
    func fetchMessages(conversationId: String) async throws -> [Message]
    func sendMessage(_ message: Message) async throws
    func fetchDashboard() async throws -> DashboardData
}

// Current implementation
class MockDataService: LMSDataService {
    // Returns pre-built mock data
}

// Future implementation
// class APIDataService: LMSDataService {
//     // Real HTTP calls
// }
```

---

## 5. Role-Based Rendering Logic

### Router pattern in RootView:

```swift
struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        Group {
            switch authVM.currentRole {
            case .none:
                LoginView()
            case .loanOfficer:
                LOTabView()
            case .manager:
                ManagerTabView()
            case .admin:
                AdminTabView()
            }
        }
    }
}
```

### Key principles:
- **No conditional logic inside views for different roles.** Each role gets its own top-level tab view.
- **Shared components** (ApplicationRow, StatusBadge, etc.) are role-agnostic.
- **Role-specific actions** are controlled by the ViewModel, not the View.
- **Login** simply sets the role on `AuthViewModel`, which triggers the router.

---

## 6. Navigation Strategy

| Pattern | Usage |
|---------|-------|
| `TabView` | Top-level role navigation (4-5 tabs per role) |
| Split layout (GeometryReader) | Dashboard workspace (list + preview) |
| `NavigationStack` | Within tabs for drill-down (e.g., application list → detail) |
| Sheet / `.sheet()` | Modal overlays (XML upload, document viewer) |
| Inline selection | Application list → preview panel (no push) |

### iPad-specific considerations:
- Use `GeometryReader` for proportional split layouts (40/60).
- Avoid `NavigationSplitView` for the dashboard workspace — use custom split for more control.
- `NavigationStack` only within individual tabs where drill-down is appropriate.
