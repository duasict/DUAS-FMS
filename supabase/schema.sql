-- ════════════════════════════════════════════════════════════════════════════
-- DUAS FMS — Supabase PostgreSQL Schema
-- Organization: Davao UAS (DUAS)
-- Compliance: PCAR / CAAP RPAS Operations Manual v2.0
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Extensions ───────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ════════════════════════════════════════════════════════════════════════════
-- CORE TABLES
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Organizations ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.organizations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  code        TEXT NOT NULL UNIQUE,           -- e.g. 'DUAS'
  logo_url    TEXT,
  address     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.organizations IS 'Multi-tenant organizations. Each org is fully isolated via RLS.';

-- ─── Profiles (extends auth.users) ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id                  UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name                TEXT NOT NULL DEFAULT '',
  email               TEXT NOT NULL DEFAULT '',
  phone               TEXT NOT NULL DEFAULT '',
  photo_url           TEXT,
  -- Profile roles:
  --   crp  = Chief Remote Pilot (org-level admin, assigned by CRP or admin)
  --   pic  = Pilot in Command (auto-granted when CAAP license verified + non-expired)
  --   vo   = Visual Observer
  --   gcs  = GCS Operator
  --   tech = Technician
  -- NOTE: 'rpic' (Remote Pilot in Command) is a MISSION-SPECIFIC crew role only.
  --       It is NOT a profile-level role. Only users with role='pic' may be
  --       assigned as RPIC on a mission.
  role                TEXT NOT NULL DEFAULT 'vo'
                        CHECK (role IN ('crp', 'pic', 'vo', 'gcs', 'tech')),
  unit                TEXT NOT NULL DEFAULT '',
  license_number      TEXT NOT NULL DEFAULT '',
  license_expiry_date DATE,
  -- License verification (populated via in-app ID card OCR scan — not manual entry)
  license_verified    BOOLEAN NOT NULL DEFAULT FALSE,
  face_verified       BOOLEAN NOT NULL DEFAULT FALSE,
  organization_id     UUID REFERENCES public.organizations(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.profiles IS 'User profiles. Profile roles: crp (Chief Remote Pilot) | pic (Pilot in Command) | vo | gcs | tech. Mission crew role ''rpic'' is separate and mission-specific.';
COMMENT ON COLUMN public.profiles.role IS 'crp=Chief Remote Pilot | pic=Pilot in Command (license verified) | vo | gcs | tech';
COMMENT ON COLUMN public.profiles.license_verified IS 'TRUE only after in-app CAAP ID card OCR scan. Cannot be set manually.';
COMMENT ON COLUMN public.profiles.face_verified IS 'TRUE when selfie matched ID photo during license verification.';

-- Auto-create profile row when a new Supabase Auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, COALESCE(NEW.email, ''))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── Aircraft ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.aircraft (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  type            TEXT NOT NULL
                    CHECK (type IN ('multi-rotor', 'vtol', 'fixed-wing')),
  model           TEXT NOT NULL,
  serial_number   TEXT NOT NULL DEFAULT '',
  mtow            FLOAT8 NOT NULL DEFAULT 0,
  status          TEXT NOT NULL DEFAULT 'serviceable'
                    CHECK (status IN ('serviceable', 'under_maintenance', 'unserviceable')),
  organization_id UUID REFERENCES public.organizations(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════════════════════════════════════════
-- MISSION TABLES
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Missions ─────────────────────────────────────────────────────────────────
-- NOTE: hazard_risk / risk_level / approved_by removed (see remarks #5, #6, #7)
-- CRP concurrence only required when HIRA total risk ≥ 9
CREATE TABLE IF NOT EXISTS public.missions (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_ref               TEXT NOT NULL,           -- e.g. 'UAS-2025-001'
  title                     TEXT NOT NULL,
  status                    TEXT NOT NULL DEFAULT 'planning'
                              CHECK (status IN ('planning', 'in_progress', 'completed', 'cancelled')),
  date                      DATE NOT NULL,
  time_str                  TEXT NOT NULL,
  location                  TEXT NOT NULL,
  latitude                  FLOAT8,
  longitude                 FLOAT8,
  environment               TEXT NOT NULL DEFAULT '',
  objective                 TEXT NOT NULL DEFAULT '',
  aircraft_id               UUID REFERENCES public.aircraft(id),
  aircraft_name             TEXT NOT NULL DEFAULT '',
  aircraft_type             TEXT NOT NULL DEFAULT '',
  duration                  INT4,                     -- total flight minutes
  crp_advisory_notes        TEXT NOT NULL DEFAULT '',
  crp_concurrence_required  BOOLEAN NOT NULL DEFAULT FALSE,
  -- '' = not yet reviewed | 'approved' = CRP approved | 'rejected' = CRP rejected
  crp_concurrence_status    TEXT NOT NULL DEFAULT '',
  created_by                UUID REFERENCES public.profiles(id),
  organization_id           UUID REFERENCES public.organizations(id),
  -- Step completion flags
  has_flight_plan_complete  BOOLEAN NOT NULL DEFAULT FALSE,
  has_hira_complete         BOOLEAN NOT NULL DEFAULT FALSE,
  has_equipment_complete    BOOLEAN NOT NULL DEFAULT FALSE,
  has_fit_to_fly_complete   BOOLEAN NOT NULL DEFAULT FALSE,
  has_preflight_complete    BOOLEAN NOT NULL DEFAULT FALSE,
  has_inflight_complete     BOOLEAN NOT NULL DEFAULT FALSE,
  has_postflight_complete   BOOLEAN NOT NULL DEFAULT FALSE,
  has_flightlog_complete    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (mission_ref, organization_id)
);
COMMENT ON COLUMN public.missions.crp_concurrence_required IS 'TRUE when max HIRA residual risk ≥ 9 (HIGH). CRP must approve before operations.';
COMMENT ON COLUMN public.missions.crp_advisory_notes IS 'CRP advisory for low/medium risk missions. Not a blocker.';

-- ─── Mission Crew ─────────────────────────────────────────────────────────────
-- Business rule (enforced at app layer):
--   • Exactly 1 member with role = 'rpic' (required)
--   • At least 1 member with role IN ('vo', 'gcs') (required)
CREATE TABLE IF NOT EXISTS public.mission_crew (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id      UUID NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES public.profiles(id),   -- nullable (external crew)
  name            TEXT NOT NULL,                          -- denormalized display name
  role            TEXT NOT NULL
                    CHECK (role IN ('rpic', 'vo', 'gcs', 'tech')),
  organization_id UUID REFERENCES public.organizations(id)
);
COMMENT ON TABLE public.mission_crew IS 'Crew per mission. Exactly 1 RPIC + at least 1 VO or GCS required.';

-- ─── Concurrences (high-risk only) ───────────────────────────────────────────
-- Created automatically when crp_concurrence_required = TRUE on a mission
CREATE TABLE IF NOT EXISTS public.concurrences (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id        UUID NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
  rpic_user_id      UUID REFERENCES public.profiles(id),
  rpic_confirmed_at TIMESTAMPTZ,
  crp_user_id       UUID REFERENCES public.profiles(id),
  crp_confirmed_at  TIMESTAMPTZ,
  status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'approved', 'rejected')),
  notes             TEXT NOT NULL DEFAULT '',
  origin            TEXT NOT NULL DEFAULT 'cloud'
                      CHECK (origin IN ('local', 'cloud')),
  organization_id   UUID REFERENCES public.organizations(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.concurrences IS 'CRP approval for HIGH risk missions (HIRA ≥ 9). origin=local means initiated via P2P hotspot.';

-- ════════════════════════════════════════════════════════════════════════════
-- FORMS & CHECKLISTS (Annex A)
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Flight Plans (Annex B) ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.flight_plans (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id            UUID NOT NULL UNIQUE REFERENCES public.missions(id) ON DELETE CASCADE,
  area_of_operation     TEXT NOT NULL DEFAULT '',
  wind_speed            FLOAT8,
  visibility            FLOAT8,
  weather_forecast      TEXT,
  airspace_class        TEXT,
  notams                TEXT,
  airspace_restrictions TEXT,
  mission_objectives    TEXT,
  contingency_plan      TEXT,
  organization_id       UUID REFERENCES public.organizations(id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── HIRA Rows (Annex C) ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.hira_rows (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id      UUID NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
  hazard          TEXT NOT NULL,
  likelihood      INT2 NOT NULL DEFAULT 1 CHECK (likelihood BETWEEN 1 AND 5),
  impact          INT2 NOT NULL DEFAULT 1 CHECK (impact BETWEEN 1 AND 5),
  mitigation      TEXT NOT NULL DEFAULT '',
  residual_risk   INT2 NOT NULL DEFAULT 1,   -- likelihood × impact (1–25)
  organization_id UUID REFERENCES public.organizations(id)
);
COMMENT ON COLUMN public.hira_rows.residual_risk IS 'likelihood × impact. If any row ≥ 9, mission.crp_concurrence_required = TRUE.';

-- ─── Checklist Items ──────────────────────────────────────────────────────────
-- checklist_type : equipment | fit_to_fly | preflight | inflight | postflight
-- item_type      : standard | contingency
-- status         : 0 = unchecked, 1 = checked/yes, 2 = n/a
CREATE TABLE IF NOT EXISTS public.checklist_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id      UUID NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
  checklist_type  TEXT NOT NULL,
  item_type       TEXT NOT NULL DEFAULT 'standard'
                    CHECK (item_type IN ('standard', 'contingency')),
  section         TEXT NOT NULL,
  item_index      INT4 NOT NULL,
  item_text       TEXT NOT NULL,
  status          INT2 NOT NULL DEFAULT 0 CHECK (status IN (0, 1, 2)),
  remark          TEXT NOT NULL DEFAULT '',
  updated_by      UUID REFERENCES public.profiles(id),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  organization_id UUID REFERENCES public.organizations(id)
);
COMMENT ON COLUMN public.checklist_items.item_type IS 'standard = normal check; contingency = situational (defaults to N/A=2 in in-flight checklist)';

-- ─── Fit-to-Fly Records (Annex A-4) ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fit_to_fly_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id      UUID NOT NULL UNIQUE REFERENCES public.missions(id) ON DELETE CASCADE,
  record_date     DATE,
  record_time     TEXT,
  location        TEXT,
  mission_type    TEXT,
  rpa_model       TEXT,
  serial_number   TEXT,
  payload         TEXT[],                   -- multi-select array
  pic             TEXT,
  organization_id UUID REFERENCES public.organizations(id)
);

-- ─── Flight Logs (Annex D) ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.flight_logs (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id         UUID NOT NULL UNIQUE REFERENCES public.missions(id) ON DELETE CASCADE,
  date_time          TIMESTAMPTZ,
  location           TEXT NOT NULL DEFAULT '',
  latitude           FLOAT8,
  longitude          FLOAT8,
  altitude_agl       FLOAT8,
  highest_point      FLOAT8,
  landing_zone       TEXT,
  -- Aircraft
  platform_type      TEXT,       -- multi-rotor | vtol | fixed-wing  (radio)
  model              TEXT,
  mtow               FLOAT8,
  payload            TEXT[],     -- multi-select: Multispectral | RGB | Thermal | LiDAR | Video | Other
  -- Mission
  mission_type       TEXT,       -- Agri | Survey | SAR | Inspection | Training | Other  (radio)
  -- Crew
  rpic               TEXT NOT NULL DEFAULT '',
  vo                 TEXT NOT NULL DEFAULT '',
  tech               TEXT NOT NULL DEFAULT '',
  -- Flights
  flights            JSONB,      -- [{flightNum, takeoff, landing, totalMin}]
  -- Conditions
  weather_wind       FLOAT8,
  weather_visibility FLOAT8,
  weather_cloud      TEXT,
  notams             TEXT,       -- Yes | No  (radio)
  anomalies          TEXT[],     -- multi-select: None | Link Loss | Weather | Low Battery | Motor Issue | Other
  -- Data collected
  data_geotiff       TEXT,
  data_photos        TEXT,
  data_video         TEXT,
  data_lidar         BOOLEAN DEFAULT FALSE,
  -- Maintenance
  next_maintenance   TEXT,       -- free text e.g. '50 hrs / 2025-06-01'
  organization_id    UUID REFERENCES public.organizations(id),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════════════════════════════════════════
-- MAINTENANCE & SAFETY LOGS (Annex A-9, A-10, A-11)
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Maintenance Logs (Annex A-9) ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maintenance_logs (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aircraft_id              UUID REFERENCES public.aircraft(id),
  mission_id               UUID REFERENCES public.missions(id),
  technician_id            UUID REFERENCES public.profiles(id),
  maintenance_date         DATE NOT NULL,
  maintenance_type         TEXT NOT NULL
                             CHECK (maintenance_type IN ('scheduled', 'unscheduled', 'post-incident')),
  description              TEXT NOT NULL DEFAULT '',
  parts_replaced           TEXT[],
  flight_hours             FLOAT8,
  cycle_count              INT4,
  next_maintenance_date    DATE,
  next_maintenance_hours   FLOAT8,
  airworthiness_status     TEXT NOT NULL DEFAULT 'serviceable'
                             CHECK (airworthiness_status IN ('serviceable', 'unserviceable')),
  signed_by                TEXT NOT NULL DEFAULT '',
  remarks                  TEXT NOT NULL DEFAULT '',
  organization_id          UUID REFERENCES public.organizations(id),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Battery Logs (Annex A-10) ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.battery_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aircraft_id     UUID REFERENCES public.aircraft(id),
  mission_id      UUID REFERENCES public.missions(id),
  battery_id      TEXT NOT NULL,          -- serial number or label
  log_date        DATE NOT NULL,
  charge_cycles   INT4,
  voltage_before  FLOAT8,
  voltage_after   FLOAT8,
  charge_time_min INT4,
  status          TEXT NOT NULL DEFAULT 'good'
                    CHECK (status IN ('good', 'degraded', 'replace')),
  remarks         TEXT NOT NULL DEFAULT '',
  organization_id UUID REFERENCES public.organizations(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Incident Reports (Annex A-11) ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.incident_reports (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id          UUID REFERENCES public.missions(id),
  aircraft_id         UUID REFERENCES public.aircraft(id),
  reporter_id         UUID REFERENCES public.profiles(id),
  incident_date       DATE NOT NULL,
  incident_time       TEXT,
  location            TEXT NOT NULL DEFAULT '',
  -- multi-select: Ground Collision | Air Collision | Fly-Away | Loss of Control | Fire | Payload Release | Data Breach | Other
  incident_type       TEXT[],
  severity            TEXT NOT NULL DEFAULT 'minor'
                        CHECK (severity IN ('minor', 'major', 'critical')),
  description         TEXT NOT NULL DEFAULT '',
  immediate_actions   TEXT NOT NULL DEFAULT '',
  five_whys           JSONB,              -- [{why: "Why 1", answer: "..."}]
  corrective_actions  TEXT NOT NULL DEFAULT '',
  reported_to_caap    BOOLEAN NOT NULL DEFAULT FALSE,
  caap_reference      TEXT,
  organization_id     UUID REFERENCES public.organizations(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════════════════════════════════════════
-- P2P & NOTIFICATIONS
-- ════════════════════════════════════════════════════════════════════════════

-- ─── P2P Sessions (local hotspot concurrence) ─────────────────────────────────
-- RPIC device runs shelf HTTP server on port 7788.
-- VO/GCS connects via hotspot. Synced to cloud when online.
CREATE TABLE IF NOT EXISTS public.p2p_sessions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id        UUID NOT NULL REFERENCES public.missions(id),
  rpic_device_ip    TEXT,
  rpic_device_name  TEXT,
  status            TEXT NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active', 'completed', 'abandoned')),
  started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at          TIMESTAMPTZ,
  organization_id   UUID REFERENCES public.organizations(id)
);

-- ─── Alerts ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.alerts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type            TEXT NOT NULL
                    CHECK (type IN ('concurrence', 'notification', 'maintenance', 'weather')),
  title           TEXT NOT NULL,
  message         TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'info'
                    CHECK (status IN ('pending', 'info', 'resolved')),
  mission_id      UUID REFERENCES public.missions(id),
  mission_title   TEXT,
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  user_id         UUID REFERENCES public.profiles(id),
  organization_id UUID REFERENCES public.organizations(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════════════════════════════════════════
-- INDEXES
-- ════════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_profiles_org       ON public.profiles(organization_id);
CREATE INDEX IF NOT EXISTS idx_aircraft_org       ON public.aircraft(organization_id);
CREATE INDEX IF NOT EXISTS idx_missions_org       ON public.missions(organization_id);
CREATE INDEX IF NOT EXISTS idx_missions_status    ON public.missions(status);
CREATE INDEX IF NOT EXISTS idx_missions_date      ON public.missions(date);
CREATE INDEX IF NOT EXISTS idx_crew_mission       ON public.mission_crew(mission_id);
CREATE INDEX IF NOT EXISTS idx_concurrence_mission ON public.concurrences(mission_id);
CREATE INDEX IF NOT EXISTS idx_checklist_mission  ON public.checklist_items(mission_id, checklist_type);
CREATE INDEX IF NOT EXISTS idx_hira_mission       ON public.hira_rows(mission_id);
CREATE INDEX IF NOT EXISTS idx_alerts_user        ON public.alerts(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_maintenance_aircraft ON public.maintenance_logs(aircraft_id);
CREATE INDEX IF NOT EXISTS idx_battery_aircraft   ON public.battery_logs(aircraft_id);
CREATE INDEX IF NOT EXISTS idx_incident_aircraft  ON public.incident_reports(aircraft_id);

-- ════════════════════════════════════════════════════════════════════════════
-- ROW-LEVEL SECURITY
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.organizations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aircraft           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.missions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mission_crew       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concurrences       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flight_plans       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hira_rows          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fit_to_fly_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flight_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battery_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_reports   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p2p_sessions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts             ENABLE ROW LEVEL SECURITY;

-- Helper: resolve the caller's organization_id from profiles
CREATE OR REPLACE FUNCTION public.my_org_id()
RETURNS UUID LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT organization_id FROM public.profiles WHERE id = auth.uid()
$$;

-- ── Organizations: members read their own org ─────────────────────────────────
DROP POLICY IF EXISTS "org_select" ON public.organizations;
CREATE POLICY "org_select" ON public.organizations
  FOR SELECT USING (id = public.my_org_id());

-- ── Profiles: users see own org; users update only their own row ──────────────
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
-- Allow: (1) users in the same org to see each other's profiles, AND
--        (2) a user to always read their own profile even before org assignment
--            (bootstrap: new user's organization_id is empty until the CRP sets it)
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (organization_id = public.my_org_id() OR id = auth.uid());

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (id = auth.uid());

-- ── Standard org-isolation for all other tables (SELECT/INSERT/UPDATE/DELETE) ─
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'aircraft', 'missions', 'mission_crew', 'concurrences', 'flight_plans',
    'hira_rows', 'checklist_items', 'fit_to_fly_records', 'flight_logs',
    'maintenance_logs', 'battery_logs', 'incident_reports',
    'p2p_sessions', 'alerts'
  ] LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON public.%I',
      t || '_org_isolation', t
    );
    EXECUTE format('
      CREATE POLICY %I ON public.%I
        FOR ALL
        USING (organization_id = public.my_org_id())
        WITH CHECK (organization_id = public.my_org_id());
    ', t || '_org_isolation', t);
  END LOOP;
END $$;

-- ════════════════════════════════════════════════════════════════════════════
-- updated_at TRIGGERS
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_missions_updated_at ON public.missions;
CREATE TRIGGER trg_missions_updated_at
  BEFORE UPDATE ON public.missions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
