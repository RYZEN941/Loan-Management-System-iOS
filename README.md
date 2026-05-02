# Loan-Manangement-System

# 🏦 Loan Management System — iOS

A production-grade, fully native iOS Loan Management System built for financial institutions and NBFCs. Three apps in one repository — Borrower App, Employee App (Loan Officer · Manager · Admin), and DST (Direct Sales Team) App.

---

## 📱 Apps Overview

| App | Users | Purpose |
|-----|-------|---------|
| **Borrower App** | Borrowers | Apply for loans, track status, manage repayments |
| **Employee App** | Loan Officers, Managers, Admins | Review applications, approve loans, manage portfolio |
| **DST App** | Direct Sales Team | Onboard customers in the field, originate loans on-site |

---

## ✨ Features

### Borrower App
- 🔐 Passkey / Face ID login via FIDO2 — passwordless authentication
- 🏷️ Aadhaar eKYC integration — auto-fills name, DOB, and address
- 🔍 Pre-eligibility checker — know your maximum loan amount before applying
- 💰 EMI calculator with amortization breakdown (principal + interest per installment)
- 📊 Repayment dashboard — upcoming EMIs, payment history, outstanding balance
- 💳 In-app EMI payments via Razorpay (UPI + Net Banking)
- 🔔 Live Activities on Lock Screen — real-time application status without opening the app
- 📈 Internal Credibility Score with 12-month trend graph and improvement tips
- 🌐 Regional language support — Hindi, Kannada, Tamil, Telugu, Marathi
- ♿ Dynamic Type, Dark Mode

### Employee App
- 🗂️ Auto-sorted application queue — by SLA deadline, risk flags, and time in queue
- ⚠️ Red-flag visual indicators for high-risk borrowers
- ⏱️ SLA countdown timer per application
- 📄 Consolidated application view — documents, credibility score, CIBIL score, DTI ratio on one screen
- ✅ Approve, reject, escalate, or request document re-upload from iPhone
- 📊 Manager portfolio dashboard — disbursements, NPA ratio, collection efficiency
- 📉 Collection aging report — 1–30, 31–60, 61–90 days past due buckets
- 👤 Officer performance metrics — turnaround time, approval rate, case count
- ⚙️ Admin configuration — loan products, interest rates, credibility tier thresholds, notification templates

### DST App
- 📷 Aadhaar QR scan — auto-populates customer KYC details instantly
- 🧠 On-device document quality check via Core ML
- 📝 Full loan application origination on-site
- 🔏 Customer OTP consent — legally valid digital sign-off
- 🔄 Applications flow directly into the Employee App queue — no re-entry, no duplication

---

## 🛠 Tech Stack

### iOS (Frontend)
| Technology | Usage |
|-----------|-------|
| **SwiftUI** | UI framework across all three apps |
| **Swift Concurrency** (async/await + Actors) | All async operations, thread safety |
| **Core ML + Vision** | On-device document quality validation |
| **App Intents** | Siri integration |
| **ActivityKit** | Live Activities on Lock Screen |
| **AuthenticationServices** | FIDO2 Passkey / Face ID login |
| **MVVM** | Architecture pattern |

### Backend
| Technology | Usage |
|-----------|-------|
| **Go** | Backend services |
| **gRPC** | Inter-service communication |
| **PostgreSQL** | Primary database |
| **Redis** | Caching and session management |

### Integrations
| Integration | Purpose |
|------------|---------|
| **Razorpay** | In-app EMI payments (UPI + Net Banking) |
| **Aadhaar eKYC** | Identity verification and auto-fill |
| **CIBIL / Equifax** | Bureau score fetch on application |

---

## 🗂 Data Models

27 entities across 8 domains:

```
Auth & Users        → User, Borrower, Employee, Branch, CoApplicant
KYC & Documents     → KYC, Document
Loan Products       → LoanProduct, EligibilityRule, CredibilityTierConfig
Applications        → LoanApplication, SanctionLetter
Loans & Repayment   → Loan, EMISchedule, Payment, PrepaymentRequest, PaymentDifficulty
Credibility         → CredibilityScore, CredibilityScoreHistory, BureauScore
Comms & Audit       → Notification, NotificationTemplate, Message, AuditLog
Analytics           → PortfolioSnapshot, OfficerMetrics, DataRetentionConfig
```

---

## 🏗 Architecture

```
LoanManagementSystem/
├── BorrowerApp/
│   ├── Authentication/
│   ├── KYC/
│   ├── LoanDiscovery/
│   ├── Application/
│   ├── Repayment/
│   ├── CredibilityScore/
│   └── Notifications/
├── EmployeeApp/
│   ├── Authentication/
│   ├── ApplicationQueue/
│   ├── ReviewFlow/
│   ├── ManagerDashboard/
│   └── AdminConfig/
├── DSTApp/
│   ├── CustomerOnboarding/
│   ├── KYCCapture/
│   ├── LoanOrigination/
│   └── ConsentFlow/
├── Shared/
│   ├── Models/
│   ├── Networking/
│   ├── CoreML/
│   └── Extensions/
└── Backend/
    ├── Services/
    ├── Models/
    └── Migrations/
```

---

## 🚀 Getting Started

### Prerequisites
- Xcode 16+
- iOS 18+ device or simulator
- macOS 15+
- Active Apple Developer account
- Go 1.22+
- PostgreSQL 16+
- Redis 7+

### Installation

**1. Clone the repository**
```bash
git clone https://github.com/your-username/loan-management-system.git
cd loan-management-system
```

**2. Open in Xcode**
```bash
open LoanManagementSystem.xcodeproj
```

**3. Configure signing**
- Select your target → Signing & Capabilities
- Set your Team to your Apple Developer account
- Ensure "Automatically manage signing" is checked

**4. Configure environment**
```bash
cp Config/template.env Config/.env
# Fill in your Razorpay keys, database URL, and API base URL
```

**5. Run the backend**
```bash
cd Backend
go mod download
go run main.go
```

**6. Build and run on device**
```
Cmd + R
```

---

## 🔑 Environment Variables

```env
# API
API_BASE_URL=http://localhost:8080

# Razorpay
RAZORPAY_KEY_ID=your_key_id
RAZORPAY_KEY_SECRET=your_key_secret

# Database
DATABASE_URL=postgres://user:password@localhost:5432/lms

# Redis
REDIS_URL=redis://localhost:6379

# KYC
AADHAAR_API_KEY=your_aadhaar_api_key
```

---

## 📋 Requirements Coverage

| SRS Requirement | Status |
|----------------|--------|
| Loan application & document upload | ✅ |
| Real-time application tracking | ✅ |
| Multi-level approval workflow | ✅ |
| EMI calculator & repayment dashboard | ✅ |
| Reports, analytics & audit trail | ✅ |
| Role-based access control | ✅ |
| Push notifications | ✅ |
| In-app messaging | ✅ |
| KYC document management | ✅ |
| Credit score display | ✅ |

### Beyond the SRS
| Enhancement | Status |
|------------|--------|
| Internal Credibility Score engine | ✅ |
| DST field origination app | ✅ |
| Razorpay in-app payment | ✅ |
| Aadhaar eKYC integration | ✅ |
| Core ML document quality validation | ✅ |
| Siri App Intents | ✅ |
| Live Activities (Lock Screen) | ✅ |
| FIDO2 Passkey authentication | ✅ |
| 5 regional languages | ✅ |
| NPA prevention reminder engine | ✅ |
| Prepayment simulator | ✅ |
| Self-serve payment difficulty flow | ✅ |

---

## 👥 Team

| Name | Role | Contribution |
|------|------|-------------|
| Sakshi Beloshe | Scrum Master | UI & integrations |
| Chirag Bhalotia | Backend Lead | Backend & integrations |
| Prathamesh Patil | Full Stack | Integrations & UI |
| Yajan Mehta | iOS Developer | Employee app UI |
| Aayudh Ninwane | iOS Developer | Employee app UI |
| Manas Jiwnani | iOS Developer | Employee app UI |
| Akshata Panda | iOS Developer | Borrower app UI |
| Gayatri | iOS Developer | Borrower app UI |
| Chirag Poojari | iOS Developer | UI & design system |

---

## 📊 Non-Functional Standards

- ✅ Zero memory leaks — verified with Instruments
- ✅ Zero SwiftUI constraint warnings
- ✅ All API calls complete within 2 seconds on 4G
- ✅ Swift Concurrency throughout — no data races
- ✅ GDPR + DPDP Act compliant — configurable data retention
- ✅ Full audit trail — every action timestamped and user-attributed
- ✅ Encrypted document storage

---

## 📄 License

This project was developed as part of an academic submission. All rights reserved.

---

## 📎 Submissions

- [x] Codebase
- [x] App video demo
- [x] Memory profile screenshots
- [x] Flow diagrams
- [x] SRS compliance mapping
