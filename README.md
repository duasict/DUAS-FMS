# DUAS FMS Mobile

**Davao UAS Fleet Management System** — A Flutter mobile application for managing UAS/drone flight operations in compliance with CAAP RPAS Operations Manual v2.0 and PCAR regulations.

---

## Overview

DUAS FMS Mobile provides a complete end-to-end mission management workflow for Remote Pilot Certificate (RPC) holders and Chief Remote Pilots (CRP). From mission planning through post-flight documentation, the app enforces the full Annex A checklist sequence and generates compliance PDFs for each stage.

---

## Features

### Mission Management
- Create and track missions with full crew assignment (RPIC, VO/GCS, Tech)
- Guided **9-step** mission execution flow:
  1. **Document Submission** — Travel Order, Site Permission, Property Owner Consent
  2. **Flight Planning** — Coverage area mapping, weather, contingency plan
  3. **HIRA** — Hazard identification & risk assessment
  4. **Equipment Checklist** — Pre-mission gear verification with equipment locker integration
  5. **Fit-to-Fly** — Crew fitness declaration + battery slot assignment
  6. **Pre-flight Checklist** — Annex A pre-flight compliance
  7. **In-flight Checklist** — Annex A in-flight monitoring
  8. **Post-flight Checklist** — Annex A post-flight compliance
  9. **Flight Log** — Full sortie record per Annex D
- Mission status tracking: Planning, In Progress, Completed, Cancelled
- CRP advisory notes and automatic concurrence flagging when HIRA residual risk ≥ 9
- **Personal account mode** — single-operator workflow that hides crew assignment and CRP features

### Document Submission
- Submit and store mission-authorising documents locally before flight operations begin
- Supported document types: Travel Order (required), Site Permission (required, with issuing authority), Property Owner Consent (optional)
- Accepted formats: PDF, PNG, JPG
- Documents are viewable from both Mission Details and the Flight Report Log

### Equipment Locker
- Central inventory for all ground-support equipment: batteries, chargers, PPE, tools, and other items
- Per-item fields: equipment code, serial number, capacity (mAh for batteries), brand, notes
- Equipment selected during the Equipment Checklist step is logged against the mission
- Battery slots assigned during Fit-to-Fly are drawn from the locker inventory

### Hazard Identification & Risk Assessment (HIRA)
- Dynamic HIRA table with likelihood × impact scoring
- Automatic escalation: missions with any residual risk ≥ 9 require CRP concurrence before operations

### Checklists (Annex A)
- **Equipment Checklist** — Batteries, propellers, GCS/radios, UAS/RPAS airframe; equipment-used section with time-started/completed capture
- **Fit-to-Fly** — Aircraft condition, propulsion, power, payload, controller/comms, nav/sensors; battery slot assignment per aircraft configuration; time-started/completed capture
- **Pre-flight Checklist** — Mission & crew, aircraft & payload, GCS & comms, environment & safety
- **In-flight Checklist** — Launch, en-route, and contingency phases
- **Post-flight Checklist** — Aircraft inspection, documentation, maintenance actions
- **Flight Log** — Full sortie record per Annex D

### Flight Report Log
- PDF generation for all Annex A/D compliance forms (A-1 through A-8, A-11)
- Per-form download with system viewer integration
- Bulk download: select any combination of forms and export as a single ZIP
- Download All: saves every completed form to the device in one tap
- Submitted mission documents (Travel Order, Site Permission, etc.) are viewable with the Open button directly from the report screen
- Coverage area displayed in hectares or km²
- RPIC license details accessible from the report header

### Aircraft Fleet
- Register and manage aircraft (multi-rotor, VTOL)
- Track airworthiness status, serial numbers, and batteries needed per aircraft

### Battery Maintenance
- Log battery health status per cycle: Good, Degraded, Replace, Retired
- Battery health alert shown on Mission Details when the assigned aircraft's latest log shows a degraded or replace status

### License Verification
- Scan CAAP Remote Pilot Certificate via camera
- Google ML Kit OCR automatically extracts license number and expiry date
- Optional face verification: ML Kit face detection crops the ID photo for side-by-side selfie comparison

### Role System

| Role | Level | Description |
|------|-------|-------------|
| `crp` | Profile | Chief Remote Pilot — org admin |
| `pic` | Profile | Person in Command — granted on license verification |
| `vo` | Profile | Visual Observer |
| `gcs` | Profile | GCS Operator |
| `tech` | Profile | Technician |
| `rpic` | Mission crew | Remote Pilot in Command — mission-specific |

### Account Types

| Type | Description |
|------|-------------|
| `organizational` | Full multi-crew workflow with CRP concurrence |
| `personal` | Single-operator mode — crew assignment and CRP features hidden |

### Authentication & Cloud Sync
- Supabase email/password authentication
- Offline-first: encrypted SQLite is the primary local store; cloud sync is deferred (planned)
- Password reset via email

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart SDK ^3.10.8) |
| Local DB | Encrypted SQLite via `sqflite_sqlcipher` |
| Cloud DB / Auth | Supabase (`supabase_flutter`) |
| State management | Provider |
| PDF generation | `pdf` package |
| File picking | `file_picker` |
| File opening | `open_file` |
| ZIP export | `archive` |
| OCR | Google ML Kit Text Recognition |
| Face detection | Google ML Kit Face Detection |
| Image processing | `image` |
| Fonts | Google Fonts |
| Connectivity | `connectivity_plus` |

---

## Project Structure

```
lib/
├── database/               # DatabaseHelper — encrypted SQLite, schema v16
├── models/                 # Mission, Aircraft, EquipmentItem, UserProfile, HiraRow, etc.
├── providers/              # ChangeNotifier providers (App, Theme, UserProfile, OrgSettings)
├── screens/
│   ├── aircraft/           # Fleet management
│   ├── alerts/             # Notification centre
│   ├── battery/            # Battery log & history
│   ├── checklists/         # Base checklist screen + Pre/In/Post-flight screens
│   ├── dashboard/          # Home dashboard
│   ├── document_submission/# Mission document upload (Travel Order, Site Permission, etc.)
│   ├── equipment_checklist/# Equipment verification checklist
│   ├── equipment_locker/   # Equipment inventory (list + add/edit)
│   ├── fit_to_fly/         # Fit-to-Fly declaration + battery slot assignment
│   ├── flight_log/         # Flight log entry
│   ├── flight_planning/    # Coverage map + flight plan form
│   ├── hira/               # Hazard identification & risk assessment
│   ├── incidents/          # Incident reports
│   ├── license/            # CAAP license verification (OCR + face detection)
│   ├── maintenance/        # Maintenance log
│   ├── mission_approval/   # CRP concurrence workflow
│   ├── mission_details/    # Mission detail view + step navigation
│   ├── missions/           # Mission list, creation, and editing
│   ├── more/               # Profile, Equipment Locker, Battery Log, Settings
│   ├── onboarding/         # Sign-up (org + personal) and org setup
│   ├── reports/            # Flight report log + fleet summary
│   └── shared/             # Reusable mission flow widgets
├── services/
│   ├── org_settings_service.dart  # Org branding persistence
│   ├── pdf_generator_service.dart # Annex A/D PDF generation
│   └── supabase_service.dart      # Auth + Supabase client
├── theme/                  # AppTheme, AppColors, dark/light colour schemes
├── utils/
│   ├── app_constants.dart  # White-label config defaults
│   └── geo_utils.dart      # Shared polygon area calculation (spherical excess)
└── widgets/
    ├── checklist_tile.dart
    ├── mission_document_row.dart  # Shared doc row widget (details + report log)
    ├── mission_card.dart
    └── stat_card.dart
supabase/
├── schema.sql              # PostgreSQL schema with RLS policies
└── seed.sql                # Initial org + CRP admin seed
```

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.10.8
- Android SDK (minSdk 21) or Xcode for iOS builds
- A Supabase project (or use the existing DUAS project credentials)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/duasict/DUAS-FMS.git
   cd DUAS-FMS
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Supabase — first-time database setup**

   In the Supabase SQL Editor, run in order:
   ```
   supabase/schema.sql   ← creates all tables, RLS policies, triggers
   supabase/seed.sql     ← creates the DUAS org + initial CRP admin account
   ```

   Default admin credentials (change immediately after first login):
   ```
   Email   : admin@duas.mil
   Password: Admin@DUAS2025!
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### White-labelling

Org branding is configured entirely within the app via the **Org Setup** screen (accessible after first login or from Settings). The following can be set without touching code:

- Organisation name and tagline
- Short app name (shown on the splash screen)
- Mission ID prefix (e.g. `UAS` → `UAS-2025-001`)
- Org logo (picked from the device gallery)
- Login slogan

Default fallback values live in `lib/utils/app_constants.dart` and `lib/services/org_settings_service.dart`.

---

## Database Schema

The app uses a **dual-database** architecture:

- **SQLite** (local, encrypted) — primary store, always available offline. Schema version **16**.
- **Supabase / PostgreSQL** (cloud) — sync target with full RLS multi-tenancy (sync planned).

Key local tables: `missions`, `mission_crew`, `mission_flights`, `mission_documents`, `hira_rows`, `checklist_items`, `checklist_timestamps`, `flight_plans`, `fit_to_fly_records`, `fit_to_fly_batteries`, `flight_logs`, `maintenance_logs`, `battery_logs`, `incident_reports`, `equipment_items`, `mission_equipment`, `aircraft`, `profiles`, `alerts`.

All cloud tables are isolated by `organization_id` via the `my_org_id()` RLS helper function.

---

## Compliance

Built to support documentation requirements under:
- **CAAP RPAS Operations Manual v2.0**
- **Philippine Civil Aviation Regulations (PCAR) Part 9**

Annex forms covered: A-1 (Flight Plan), A-2 (HIRA), A-3 (Equipment), A-4 (Fit-to-Fly), A-5/6/7 (Pre/In/Post-flight), A-8 (Flight Log), A-11 (Incident Report).

---

## Version

`v1.1.0` — Equipment Locker, Document Submission, Personal Accounts, encrypted local DB, PDF report log with ZIP export
