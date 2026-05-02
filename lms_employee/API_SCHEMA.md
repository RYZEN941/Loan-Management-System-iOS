# API Schema — Loan Management System

## Overview
All endpoints return JSON. Authentication via Bearer token (mocked). Base URL: `https://api.lms.example.com/v1`

---

## 1. GET /applications

**Description**: Fetch list of loan applications for the current user's role.

**Query Parameters**:
- `status` (optional): Filter by status
- `assignedTo` (optional): Filter by loan officer ID
- `page` (optional): Pagination (default: 1)
- `limit` (optional): Items per page (default: 20)

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "APP-2024-001",
      "borrowerName": "Rajesh Kumar",
      "loanAmount": 2500000,
      "loanType": "Home Loan",
      "status": "under_review",
      "assignedTo": "LO-001",
      "branch": "Mumbai Central",
      "createdAt": "2024-12-01T10:30:00Z",
      "slaDeadline": "2024-12-08T10:30:00Z",
      "riskLevel": "medium",
      "cibilScore": 720
    },
    {
      "id": "APP-2024-002",
      "borrowerName": "Priya Sharma",
      "loanAmount": 500000,
      "loanType": "Personal Loan",
      "status": "new",
      "assignedTo": "LO-001",
      "branch": "Mumbai Central",
      "createdAt": "2024-12-03T14:00:00Z",
      "slaDeadline": "2024-12-10T14:00:00Z",
      "riskLevel": "low",
      "cibilScore": 785
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 12
  }
}
```

---

## 2. GET /application/{id}

**Description**: Fetch full detail for a single application.

**Response** (200):
```json
{
  "success": true,
  "data": {
    "id": "APP-2024-001",
    "borrower": {
      "name": "Rajesh Kumar",
      "dob": "1985-03-15",
      "address": "42, Marine Drive, Mumbai, Maharashtra 400001",
      "employer": "Tata Consultancy Services",
      "employmentType": "salaried",
      "phone": "+91-9876543210",
      "email": "rajesh.kumar@email.com"
    },
    "loan": {
      "amount": 2500000,
      "type": "Home Loan",
      "tenure": 240,
      "interestRate": 8.5,
      "emi": 21700
    },
    "financials": {
      "monthlyIncome": 125000,
      "annualIncome": 1500000,
      "existingEMI": 15000,
      "dtiRatio": 0.29,
      "cibilScore": 720,
      "bankBalance": 450000
    },
    "documents": [
      {
        "id": "DOC-001",
        "type": "pan_card",
        "label": "PAN Card",
        "status": "verified",
        "uploadedAt": "2024-12-01T11:00:00Z"
      },
      {
        "id": "DOC-002",
        "type": "aadhaar",
        "label": "Aadhaar Card",
        "status": "pending",
        "uploadedAt": null
      },
      {
        "id": "DOC-003",
        "type": "bank_statement",
        "label": "Bank Statement",
        "status": "verified",
        "uploadedAt": "2024-12-02T09:00:00Z"
      }
    ],
    "verification": [
      {
        "field": "PAN Name",
        "declared": "Rajesh Kumar",
        "extracted": "Rajesh Kumar",
        "match": true
      },
      {
        "field": "Monthly Income",
        "declared": 125000,
        "extracted": 118000,
        "match": false
      }
    ],
    "notes": [
      {
        "id": "NOTE-001",
        "author": "Amit Singh (LO)",
        "text": "Income docs verified. Minor discrepancy in bank statement.",
        "timestamp": "2024-12-03T16:30:00Z"
      }
    ],
    "status": "under_review",
    "assignedTo": "LO-001",
    "createdAt": "2024-12-01T10:30:00Z",
    "slaDeadline": "2024-12-08T10:30:00Z"
  }
}
```

---

## 3. POST /application/action

**Description**: Perform an action on an application.

**Request Body**:
```json
{
  "applicationId": "APP-2024-001",
  "action": "recommend",
  "remarks": "All documents verified. Income within acceptable range.",
  "fraudFlag": false
}
```

**Actions**: `recommend`, `reject`, `request_docs`, `approve`, `send_back`

**Response** (200):
```json
{
  "success": true,
  "data": {
    "applicationId": "APP-2024-001",
    "newStatus": "recommended",
    "actionBy": "LO-001",
    "timestamp": "2024-12-04T10:00:00Z"
  }
}
```

---

## 4. POST /upload/xml

**Description**: Upload and parse an XML file for financial data extraction.

**Request**: Multipart form data with XML file.

**Response** (200):
```json
{
  "success": true,
  "data": {
    "parsedFields": {
      "accountHolder": "Rajesh Kumar",
      "bankName": "State Bank of India",
      "accountNumber": "XXXX1234",
      "monthlyIncome": 125000,
      "averageBalance": 340000,
      "transactions": [
        {
          "date": "2024-11-01",
          "description": "Salary Credit",
          "amount": 125000,
          "type": "credit"
        },
        {
          "date": "2024-11-05",
          "description": "EMI Payment",
          "amount": -15000,
          "type": "debit"
        }
      ],
      "totalCredits": 125000,
      "totalDebits": 85000
    }
  }
}
```

---

## 5. POST /chat/message

**Description**: Send a chat message.

**Request Body**:
```json
{
  "conversationId": "CONV-001",
  "senderId": "LO-001",
  "text": "Please upload your latest bank statement.",
  "attachments": []
}
```

**Response** (200):
```json
{
  "success": true,
  "data": {
    "messageId": "MSG-042",
    "conversationId": "CONV-001",
    "senderId": "LO-001",
    "senderName": "Amit Singh",
    "text": "Please upload your latest bank statement.",
    "timestamp": "2024-12-04T11:30:00Z",
    "attachments": []
  }
}
```

---

## 6. GET /dashboard

**Description**: Fetch dashboard KPIs for the current role.

**Response** (200) — Loan Officer:
```json
{
  "success": true,
  "data": {
    "role": "loan_officer",
    "kpis": {
      "assignedApplications": 12,
      "pendingReview": 5,
      "highRiskCases": 2
    },
    "recentActivity": [
      {
        "type": "status_change",
        "applicationId": "APP-2024-003",
        "message": "Application approved by Manager",
        "timestamp": "2024-12-04T09:00:00Z"
      }
    ]
  }
}
```

**Response** (200) — Manager:
```json
{
  "success": true,
  "data": {
    "role": "manager",
    "kpis": {
      "pendingApprovals": 8,
      "approvedThisMonth": 24,
      "totalPortfolioValue": 125000000
    }
  }
}
```

**Response** (200) — Admin:
```json
{
  "success": true,
  "data": {
    "role": "admin",
    "kpis": {
      "activeUsers": 45,
      "applicationsProcessedToday": 18,
      "systemHealth": "healthy"
    }
  }
}
```
