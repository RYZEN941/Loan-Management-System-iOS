# Feature Map — Loan Management System

## 1. Tabs Per Role

### Loan Officer (Phase 1)
| Tab | Icon | Description |
|-----|------|-------------|
| Dashboard | `chart.bar.fill` | KPIs + active workspace |
| Applications | `doc.text.fill` | Full application detail |
| Messages | `message.fill` | Chat with borrowers/LOs |
| Profile | `person.circle.fill` | User info + logout |

### Manager (Phase 2)
| Tab | Icon | Description |
|-----|------|-------------|
| Dashboard | `chart.bar.fill` | Portfolio KPIs |
| Approvals | `checkmark.circle.fill` | Recommended apps queue |
| Portfolio & Reports | `chart.pie.fill` | Analytics |
| Messages | `message.fill` | Communication |
| Profile | `person.circle.fill` | User info + logout |

### Admin (Phase 3)
| Tab | Icon | Description |
|-----|------|-------------|
| Dashboard | `chart.bar.fill` | System KPIs |
| Users | `person.3.fill` | User management |
| System Control | `gearshape.fill` | Configs, rules, audit |
| Messages | `message.fill` | Announcements |
| Profile | `person.circle.fill` | User info + logout |

## 2. Reusable Components

| Component | Used By | Description |
|-----------|---------|-------------|
| `ApplicationRow` | LO, Manager | List item with name, amount, status |
| `StatusBadge` | All | Color-coded status pill |
| `CardView` | All | Generic card wrapper |
| `KPIStripView` | All | Horizontal KPI strip |
| `ActionPanel` | LO, Manager | Action buttons |
| `DocumentRow` | LO, Manager | Document item with status |
| `VerificationRow` | LO, Manager | AI/OCR match/mismatch |
| `MessageBubble` | All | Chat bubble |
| `SectionHeader` | All | Section header |

## 3. Shared vs Role-Specific

### Shared (All Roles)
- Login / Role Selection
- Dashboard KPIs (shared components, role-specific data)
- Messages (shared chat UI)
- Profile (name, role, logout)

### Loan Officer Only
- Active Workspace (split-panel)
- Application Detail (6 sections)
- XML Upload & Parse
- AI/OCR Verification
- Recommend / Reject / Request Docs

### Manager Only
- Approvals Queue
- Approve / Reject / Send Back
- Structured Remarks (form-based)
- Portfolio & Reports

### Admin Only
- User Management (CRUD)
- System Control (configs, rules, audit, doc rules)
