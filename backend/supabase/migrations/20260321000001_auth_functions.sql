-- ─────────────────────────────────────────
-- AUTO-CREATE PROFILE ON SIGNUP
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, phone, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.phone,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────
-- AUTO-UPDATE updated_at ON PROFILES
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────
-- MARK PROFILE AS VERIFIED AFTER OTP
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_user_verified(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET is_verified = TRUE
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;