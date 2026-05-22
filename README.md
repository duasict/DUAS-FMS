# DUAS FMS Mobile

**Davao UAS Fleet Management System** — A Flutter mobile application for managing UAS/drone flight operations in compliance with CAAP RPAS Operations Manual v2.0 and PCAR regulations.

---

## Overview

DUAS FMS Mobile provides a complete end-to-end mission management workflow for Remote Pilot Certificate (RPC) holders and Chief Remote Pilots (CRP). From mission planning through post-flight documentation, the app enforces the full Annex A checklist sequence while syncing operational data to a Supabase cloud backend.

---

## Features

### Mission Management
- Create and track missions with full crew assignment (RPIC, VO/GCS, Tech)
- Guided 7-step mission execution flow: Flight Plan → HIRA → Equipment Checklist → Fit-to-Fly → Pre-flight → In-flight → Post-flight → Flight Log
- Mission status tracking: Planning, In Progress, Completed, Cancelled
- CRP advisory notes and automatic concurrence flagging when HIRA residual risk ≥ 9

### Hazard Identification & Risk Assessment (HIRA)
- Dynamic HIRA table with likelihood × impact scoring
- Automatic escalation: missions with any residual risk ≥ 9 require CRP concurrence before operations

### Checklists (Annex A)
- **Equipment Checklist** — Batteries, propellers, GCS/radios, UAS/RPAS airframe
- **Fit-to-Fly** — Crew fitness and pre-mission declaration
- **Pre-flight Checklist** — Mission & crew, aircraft & payload, GCS & comms, environment & safety
- **In-flight Checklist** — Launch, en-route, and contingency checks
- **Post-flight Checklist** — Aircraft inspection, documentation, maintenance actions
- **Flight Log** — Full sortie record per Annex D

### Aircraft Fleet
- Register and manage aircraft (multi-rotor, VTOL, fixed-wing)
- Track airworthiness status and serial numbers

### License Verification
- Scan CAAP Remote Pilot Certificate via camera
- Google ML Kit OCR automatically extracts license number and expiry date — manual entry is not permitted
- Optional face verification: ML Kit face detection crops the ID photo for side-by-side selfie comparison
- PIC (Person in Command) role is auto-assigned when a valid, non-expired license is verified

### Role System

| Role | Level | Description |
|------|-------|-------------|
| `crp` | Profile | Chief Remote Pilot — org admin, assigned by system |
| `pic` | Profile | Person in Command — auto-granted on license verification |
| `vo` | Profile | Visual Observer |
| `gcs` | Profile | GCS Operator |
| `tech` | Profile | Technician |
| `rpic` | Mission crew | Remote Pilot in Command — mission-specific, requires `pic` profile role |

### Authentication & Cloud Sync
- Supabase email/password authentication
- Offline-first: SQLite is the primary local store; cloud sync when online
- Row-Level Security (RLS) enforces full org-level data isolation in Supabase
- Password reset via email

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart SDK ^3.10.8) |
| Local DB | SQLite via `sqflite` |
| Cloud DB / Auth | Supabase (`supabase_flutter ^2.8.0`) |
| State management | Provider |
| OCR | Google ML Kit Text Recognition (`^0.13.1`) |
| Face detection | Google ML Kit Face Detection (`^0.11.0`) |
| Image processing | `image ^4.2.0` |
| Fonts | Google Fonts |
| Connectivity | `connectivity_plus` |

---

## Project Structure

```
lib/
├── database/          # SQLite DatabaseHelper (offline-first, v6 schema)
├── models/            # Data models: Mission, Aircraft, UserProfile, HiraRow, etc.
├── providers/         # ChangeNotifier providers (App, Theme, UserProfile)
├── screens/
│   ├── aircraft/      # Fleet management
│   ├── alerts/        # Notification centre
│   ├── checklists/    # Pre-flight, In-flight, Post-flight screens + shared widgets
│   ├── dashboard/     # Home dashboard
│   ├── equipment_checklist/
│   ├── fit_to_fly/
│   ├── flight_log/
│   ├── flight_planning/
│   ├── hira/          # Hazard identification & risk assessment
│   ├── license/       # CAAP license verification (OCR + face detection)
│   ├── mission_approval/
│   ├── mission_details/
│   ├── missions/      # Mission list & creation
│   ├── more/          # Profile, settings, more menu
│   └── shared/        # Reusable mission flow widgets
├── services/
│   ├── supabase_service.dart   # Auth + Supabase client singleton
│   └── sync_service.dart       # Cloud sync (offline → cloud)
├── theme/             # AppTheme, AppColors, dark/light colour schemes
├── utils/             # AppConstants (white-label config)
└── widgets/           # ChecklistTile, MissionCard, StatCard
supabase/
├── schema.sql         # Full PostgreSQL schema with RLS policies
└── seed.sql           # Initial org + CRP admin account seed
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

All org-specific strings live in `lib/utils/app_constants.dart`:

```dart
static const String appName       = 'DUAS';
static const String orgName       = 'Davao UAS';
static const String missionPrefix = 'UAS';  // e.g. UAS-2025-001
```

Swap these values and replace `assets/icons/app_icon.png` to rebrand for a different unit.

---

## Database Schema

The app uses a **dual-database** architecture:

- **SQLite** (local) — primary store, always available offline. Schema version 6.
- **Supabase / PostgreSQL** (cloud) — sync target with full RLS multi-tenancy.

Key tables: `organizations`, `profiles`, `missions`, `mission_crew`, `hira_rows`, `checklist_items`, `flight_plans`, `fit_to_fly_records`, `flight_logs`, `concurrences`, `maintenance_logs`, `battery_logs`, `incident_reports`, `alerts`.

All tables are isolated by `organization_id` via the `my_org_id()` RLS helper function.

---

## Compliance

Built to support documentation requirements under:
- **CAAP RPAS Operations Manual v2.0**
- **Philippine Civil Aviation Regulations (PCAR) Part 9**

Annex forms covered: A-3 (Equipment), A-4 (Fit-to-Fly), A-5/6/7 (Pre/In/Post-flight), A-9 (Maintenance), A-10 (Battery), A-11 (Incident Report), D (Flight Log).

---

## Version

`v1.0.0` — Initial release
