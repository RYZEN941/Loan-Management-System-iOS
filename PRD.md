# Product Requirements Document — Loan Management System (LMS)

## 1. Product Overview

The Loan Management System (LMS) is an **iPad-native staff application** built with SwiftUI, designed for banking and financial institutions to manage the end-to-end loan lifecycle. The application serves three distinct staff roles — Loan Officer, Manager, and Admin — each with tailored workflows, dashboards, and permissions.

The app is designed with an **iPad-first hybrid layout** inspired by Apple Files, Apple Mail, and modern fintech dashboards (Stripe-like clarity). It prioritizes workflow efficiency over visual clutter, using split-panel layouts, inline actions, and contextual previews to minimize navigation depth.

---

## 2. Roles

### 2.1 Loan Officer (Phase 1)
- **Primary user.** Handles day-to-day loan processing.
- Reviews and manages assigned loan applications.
- Uploads and verifies borrower documents (PAN, Aadhaar, Bank Statements).
- Uploads XML files for auto-filling financial data.
- Reviews AI/OCR verification results.
- Recommends applications to Manager or rejects them.
- Communicates with borrowers and other Loan Officers.

### 2.2 Manager (Phase 2)
- **Approval authority.** Reviews applications recommended by Loan Officers.
- Approves, rejects, or sends back applications with structured remarks.
- Views portfolio-level reports and analytics.
- Does **not** use chat-style notes — uses structured remark forms instead.

### 2.3 Admin (Phase 3)
- **System administrator.** Manages users, configurations, and system rules.
- Creates/edits/deactivates staff accounts.
- Configures loan products, risk thresholds, and document rules.
- Views audit logs for compliance.

---

## 3. Key Workflows

### 3.1 Application Lifecycle

```
New → Assigned → Under Review → Recommended → Approved / Rejected
                                    ↑
                              Sent Back (by Manager)
```

1. Application is created (externally or via intake).
2. Assigned to a Loan Officer.
3. LO reviews borrower profile, documents, and financials.
4. LO can: **Recommend** (to Manager), **Reject** (with optional Fraud flag), or **Request Documents** (from borrower).
5. Manager reviews and: **Approves**, **Rejects**, or **Sends Back** (to LO for more info).

### 3.2 Loan Officer → Manager Approval Flow

1. LO completes review and clicks "Recommend to Manager."
2. Application status changes to `Recommended`.
3. Application appears in Manager's Approvals queue.
4. Manager reviews the same application detail (reused screen), plus LO notes.
5. Manager adds structured remarks and takes action.

### 3.3 XML Upload & Parsing Flow

1. LO opens an application's Documents section.
2. Clicks "Upload XML."
3. System opens file picker (`.xml` files).
4. Selected file is parsed using Foundation's `XMLParser`.
5. Extracted data auto-fills:
   - Income
   - Transaction history
   - Identity fields (name, PAN, etc.)
6. LO reviews auto-filled data before confirming.

### 3.4 AI/OCR Verification Flow

1. After documents are uploaded, the system runs OCR extraction (simulated in mock).
2. Extracted values are compared against application data.
3. Results are displayed in the Verification Panel:
   - ✅ Match: PAN Name matches Application Name
   - ⚠️ Mismatch: Income discrepancy between bank statement and declared income
4. LO reviews flags and takes appropriate action.

---

## 4. Functional Requirements

### 4.1 Loan Officer

| Feature | Description |
|---------|-------------|
| Dashboard | Greeting, KPI strip (3 cards), active workspace with split layout |
| Application List | Scrollable list with name, amount, status, SLA indicator |
| Application Preview | Inline preview panel (no navigation push) |
| Application Detail | 6-section vertical scroll: Profile, Documents, AI/OCR, Financials, Notes, Actions |
| XML Upload | File picker → parse → auto-fill fields |
| Document Management | Upload, view, track verification status per document |
| AI/OCR Verification | Match/mismatch flags for extracted vs declared values |
| Actions | Recommend, Reject (+ Fraud), Request Documents |
| Messages | Chat with borrowers and other LOs, attachments, quick reply templates |
| Profile | Name, role display, logout |

### 4.2 Manager

| Feature | Description |
|---------|-------------|
| Dashboard | Portfolio-level KPIs, pending approvals count |
| Approvals | Queue of recommended applications, reuse application detail screen |
| Actions | Approve, Reject, Send Back |
| Manager Notes | Structured remarks form (not chat) |
| Portfolio & Reports | Summary statistics, loan distribution, risk overview |
| Messages | Communication channel |
| Profile | Name, role, logout |

### 4.3 Admin

| Feature | Description |
|---------|-------------|
| Dashboard | System-level KPIs (active users, processed today, system health) |
| User Management | List users, add/edit/deactivate, assign roles |
| System Control | Loan product configs, risk rules, document rules, audit logs |
| Messages | System announcements and staff communication |
| Profile | Name, role, logout |
