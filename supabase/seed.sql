-- ════════════════════════════════════════════════════════════════════════════
-- DUAS FMS — Initial Seed
-- Run ONCE in the Supabase SQL Editor after schema.sql
-- Creates: 1 organization + 1 CRP admin account
-- ════════════════════════════════════════════════════════════════════════════
--
-- After running this script, sign in to the app with:
--   Email   : admin@duas.mil
--   Password: Admin@DUAS2025!
--
-- IMPORTANT: Change the password immediately after first login.
-- ════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_org_id   UUID;
  v_user_id  UUID := gen_random_uuid();
BEGIN

  -- ── 1. Organization ─────────────────────────────────────────────────────
  INSERT INTO public.organizations (name, code, address)
  VALUES ('Davao UAS', 'DUAS', 'Davao City, Philippines')
  RETURNING id INTO v_org_id;

  RAISE NOTICE 'Created organization: DUAS (id: %)', v_org_id;

  -- ── 2. Supabase Auth user ────────────────────────────────────────────────
  -- Direct insert into auth.users (requires admin/SQL Editor access)
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',  -- instance_id
    v_user_id,
    'authenticated',
    'authenticated',
    'admin@duas.mil',
    crypt('Admin@DUAS2025!', gen_salt('bf')),
    NOW(),           -- email pre-confirmed
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    FALSE,
    NOW(),
    NOW(),
    '', '', '', ''
  );

  -- Auth identity record (required for Supabase sign-in to work)
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', 'admin@duas.mil'),
    'email',
    'admin@duas.mil',   -- provider_id for email = email address
    NOW(),
    NOW(),
    NOW()
  );

  RAISE NOTICE 'Created auth user: admin@duas.mil (id: %)', v_user_id;

  -- ── 3. Profile (trigger auto-creates a bare row; we update it) ───────────
  -- Wait a moment for the trigger, then update with full data
  UPDATE public.profiles
  SET
    name              = 'DUAS Administrator',
    role              = 'crp',
    unit              = 'UAS Operations Command',
    organization_id   = v_org_id
  WHERE id = v_user_id;

  -- If trigger hasn't fired yet, insert directly
  IF NOT FOUND THEN
    INSERT INTO public.profiles (id, name, email, role, unit, organization_id)
    VALUES (v_user_id, 'DUAS Administrator', 'admin@duas.mil', 'crp',
            'UAS Operations Command', v_org_id);
  END IF;

  RAISE NOTICE 'Seed complete.  org_id=%, admin_id=%', v_org_id, v_user_id;
  RAISE NOTICE 'Login: admin@duas.mil / Admin@DUAS2025!';
  RAISE NOTICE '⚠ Change the password after first login!';

END $$;
