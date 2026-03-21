-- ─────────────────────────────────────────
-- ENUM TYPES
-- ─────────────────────────────────────────
CREATE TYPE public.user_role   AS ENUM ('resident', 'lgu_officer', 'admin');
CREATE TYPE public.auth_method AS ENUM ('email', 'phone', 'google');
CREATE TYPE public.otp_status  AS ENUM ('pending', 'verified', 'expired');

-- ─────────────────────────────────────────
-- PROFILES
-- extends Supabase auth.users
-- ─────────────────────────────────────────
CREATE TABLE public.profiles (
  id            UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  role          public.user_role NOT NULL DEFAULT 'resident',
  full_name     TEXT,
  email         TEXT UNIQUE,
  phone         TEXT UNIQUE,
  avatar_url    TEXT,
  barangay      TEXT,                        -- which barangay they belong to
  city          TEXT DEFAULT 'San Pablo City',
  is_verified   BOOLEAN DEFAULT FALSE,       -- phone/email confirmed
  is_active     BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- OTP LOGS
-- tracks all OTP requests via Semaphore SMS
-- ─────────────────────────────────────────
CREATE TABLE public.otp_logs (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  phone         TEXT,                        -- recipient number
  otp_code      TEXT NOT NULL,              -- hashed in production
  status        public.otp_status DEFAULT 'pending',
  attempts      INT DEFAULT 0,              -- how many times user tried
  expires_at    TIMESTAMPTZ NOT NULL,
  verified_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- AUTH SESSIONS LOG
-- tracks login history per user
-- ─────────────────────────────────────────
CREATE TABLE public.auth_logs (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  method        public.auth_method NOT NULL,
  ip_address    TEXT,
  device_info   TEXT,                       -- Flutter device info
  success       BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- LGU OFFICERS
-- additional info for LGU dashboard users
-- ─────────────────────────────────────────
CREATE TABLE public.lgu_officers (
  id            UUID REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
  jurisdiction  TEXT NOT NULL,              -- barangay or city scope
  department    TEXT,                       -- e.g. 'Waste Management Office'
  employee_id   TEXT UNIQUE,
  is_approved   BOOLEAN DEFAULT FALSE,      -- admin must approve LGU accounts
  approved_by   UUID REFERENCES public.profiles(id),
  approved_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
