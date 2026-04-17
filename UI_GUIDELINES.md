# UI Guidelines — Loan Management System

## 1. Layout System

### iPad-First Design
- **Primary layout**: Multi-panel (split view), NOT single-column mobile.
- **Orientation**: Optimized for landscape, functional in portrait.
- **Minimum width**: 1024pt (iPad landscape).
- **No full-screen pushes** for core workflows — use inline panels and split layouts.

### Split Layout Ratios
| Context | Left Panel | Right Panel |
|---------|-----------|-------------|
| Dashboard workspace | 40% (list) | 60% (preview) |
| Messages | 35% (conversations) | 65% (chat) |
| Admin users | 40% (user list) | 60% (user detail) |

---

## 2. Grid & Spacing

### 8pt Base Grid
All spacing values are multiples of 8pt.

| Token | Value | Usage |
|-------|-------|-------|
| `spacing.xs` | 4pt | Inline icon gaps |
| `spacing.sm` | 8pt | Compact element spacing |
| `spacing.md` | 16pt | Standard content padding |
| `spacing.lg` | 24pt | Section spacing |
| `spacing.xl` | 32pt | Major section breaks |
| `spacing.xxl` | 48pt | Page-level margins |

### Content Padding
- Card internal padding: **16pt**
- Screen edge padding: **24pt** (iPad)
- Section vertical spacing: **24pt**
- List row vertical padding: **12pt**

---

## 3. Color System

### Primary Palette

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Primary | Blue | `#0066FF` | Primary actions, selected states, links |
| Primary Dark | Dark Blue | `#0052CC` | Hover/pressed states |
| Primary Light | Light Blue | `#E6F0FF` | Selected backgrounds, badges |

### Semantic Colors

| Name | Hex | Usage |
|------|-----|-------|
| Critical | `#DC3545` | Reject actions, fraud flags, errors — **use sparingly** |
| Warning | `#F5A623` | SLA warnings, mismatches, attention needed |
| Success | `#28A745` | Approved status, verified docs — **avoid excessive use** |
| Neutral | `#6B7280` | Secondary text, borders, disabled states |

### Surface Colors

| Name | Light Mode | Dark Mode |
|------|-----------|-----------|
| Background | `#F8F9FA` | `#1C1C1E` |
| Surface | `#FFFFFF` | `#2C2C2E` |
| Surface Secondary | `#F1F3F5` | `#3A3A3C` |
| Border | `#E5E7EB` | `#48484A` |

### Rules
- ❌ **No pure red (#FF0000)** — use semantic `Critical` sparingly.
- ❌ **No excessive green** — limit to verified/approved status only.
- ✅ **Blue is always primary** — buttons, links, selection states.
- ✅ **Neutral grays** for most UI chrome.

---

## 4. Typography

### Font Stack
- **Primary**: SF Pro (system font) — no custom fonts needed.
- **Monospace**: SF Mono — for financial figures, IDs.

### Type Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Title Large | 28pt | Bold | Page titles |
| Title | 22pt | Semibold | Section headers |
| Headline | 17pt | Semibold | Card titles, row primary text |
| Body | 17pt | Regular | Default content |
| Subheadline | 15pt | Regular | Secondary text, labels |
| Caption | 13pt | Regular | Timestamps, metadata |
| Caption 2 | 11pt | Regular | Badges, tiny labels |

---

## 5. Component Specifications

### Cards (KPI Cards, Info Cards)
- Background: `Surface` color
- Corner radius: **12pt**
- Border: **1pt** `Border` color (light, minimal)
- Shadow: `0 1pt 3pt rgba(0,0,0,0.08)` — subtle only
- Internal padding: **16pt**
- No heavy drop shadows or gradients

### Buttons
| Type | Height | Style |
|------|--------|-------|
| Primary | 48pt | Filled blue, white text, 10pt radius |
| Secondary | 48pt | Outlined blue border, blue text |
| Destructive | 48pt | Filled red, white text — **critical actions only** |
| Ghost | 44pt | No border, blue text |

### Status Badges
- Height: **24pt**
- Corner radius: **12pt** (pill shape)
- Horizontal padding: **12pt**
- Font: Caption 2, semibold
- Colors: Semantic colors with light tinted backgrounds

| Status | Background | Text |
|--------|-----------|------|
| New | `#E6F0FF` | `#0066FF` |
| Under Review | `#FFF3CD` | `#856404` |
| Recommended | `#D4EDDA` | `#155724` |
| Approved | `#D4EDDA` | `#155724` |
| Rejected | `#F8D7DA` | `#721C24` |
| Sent Back | `#FFF3CD` | `#856404` |

### List Rows
- Minimum height: **64pt** (touch-friendly)
- Vertical padding: **12pt**
- Horizontal padding: **16pt**
- Divider: **0.5pt** hairline, `Border` color
- Selected state: `Primary Light` background

### Action Panel
- Horizontal stack of buttons
- Full-width at bottom of detail view
- Background: `Surface` with top border
- Padding: **16pt** all sides

---

## 6. Iconography
- Use **SF Symbols** exclusively.
- Weight: **medium** (default).
- Size: Match text size context.
- Color: Follow semantic color rules.

### Key Icons
| Element | SF Symbol |
|---------|-----------|
| Dashboard | `chart.bar.fill` |
| Applications | `doc.text.fill` |
| Messages | `message.fill` |
| Profile | `person.circle.fill` |
| Approvals | `checkmark.circle.fill` |
| Portfolio | `chart.pie.fill` |
| Users | `person.3.fill` |
| System | `gearshape.fill` |
| Upload | `arrow.up.doc.fill` |
| Verified | `checkmark.shield.fill` |
| Warning | `exclamationmark.triangle.fill` |
| Reject | `xmark.circle.fill` |

---

## 7. Animation & Interaction

### Transitions
- View transitions: `.easeInOut(duration: 0.2)` — subtle and fast.
- List selection: immediate highlight, no delay.
- Sheet presentation: system default.

### Hover / Press States
- Buttons: Slightly darker shade on press.
- List rows: Background tint on press.
- No bounce or spring animations — keep it professional.

### Rules
- ❌ No flashy animations — this is a banking app.
- ✅ Smooth, fast transitions for professional feel.
- ✅ Immediate feedback on tap/press.
