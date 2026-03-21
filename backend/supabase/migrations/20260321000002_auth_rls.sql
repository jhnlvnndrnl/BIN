-- ─────────────────────────────────────────
-- RLS: PROFILES
-- ─────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- LGU officers can view resident profiles in their jurisdiction
CREATE POLICY "LGU can view residents in jurisdiction"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.lgu_officers
      WHERE id = auth.uid()
        AND is_approved = TRUE
        AND jurisdiction = public.profiles.barangay
    )
  );

-- ─────────────────────────────────────────
-- RLS: OTP LOGS
-- ─────────────────────────────────────────
ALTER TABLE public.otp_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own otp logs"
  ON public.otp_logs FOR SELECT
  USING (user_id = auth.uid());

-- Only service role can insert (done via backend)
CREATE POLICY "Service role inserts otp logs"
  ON public.otp_logs FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- ─────────────────────────────────────────
-- RLS: AUTH LOGS
-- ─────────────────────────────────────────
ALTER TABLE public.auth_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own auth logs"
  ON public.auth_logs FOR SELECT
  USING (user_id = auth.uid());

-- ─────────────────────────────────────────
-- RLS: LGU OFFICERS
-- ─────────────────────────────────────────
ALTER TABLE public.lgu_officers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "LGU officers can view own record"
  ON public.lgu_officers FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Admin can manage LGU officers"
  ON public.lgu_officers FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND role = 'admin'
    )
  );
