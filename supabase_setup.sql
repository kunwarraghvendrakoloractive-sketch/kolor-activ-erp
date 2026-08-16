-- Kolor Activ ERP - Supabase Setup
-- Run this in Supabase SQL Editor

-- Create erp_state table
CREATE TABLE IF NOT EXISTS public.erp_state (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id text UNIQUE NOT NULL,
  state jsonb,
  updated_at timestamptz DEFAULT now(),
  updated_by uuid
);

-- Create kolour_active table
CREATE TABLE IF NOT EXISTS public.kolour_active (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE NOT NULL,
  value jsonb,
  updated_at timestamptz DEFAULT now()
);

-- Enable Realtime on erp_state (CRITICAL for live sync)
ALTER PUBLICATION supabase_realtime ADD TABLE public.erp_state;

-- Enable Row Level Security
ALTER TABLE public.erp_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kolour_active ENABLE ROW LEVEL SECURITY;

-- DROP old policies if exist
DROP POLICY IF EXISTS "allow_all_erp" ON public.erp_state;
DROP POLICY IF EXISTS "allow_anon_read" ON public.erp_state;
DROP POLICY IF EXISTS "allow_auth_write" ON public.erp_state;

-- POLICY 1: Allow ALL users (including anonymous) to READ
CREATE POLICY "allow_all_read" ON public.erp_state
  FOR SELECT USING (true);

-- POLICY 2: Allow ALL authenticated users (including anonymous) to INSERT/UPDATE
CREATE POLICY "allow_auth_write" ON public.erp_state
  FOR ALL USING (auth.role() IN ('authenticated', 'anon'))
  WITH CHECK (auth.role() IN ('authenticated', 'anon'));

-- kolour_active policies
DROP POLICY IF EXISTS "allow_all_kolour" ON public.kolour_active;
CREATE POLICY "allow_all_kolour" ON public.kolour_active
  FOR ALL USING (true) WITH CHECK (true);

-- Insert default rows if not exist
INSERT INTO public.erp_state (app_id, state) 
VALUES ('kolor_store', '{}'), ('kolor_production', '{}')
ON CONFLICT (app_id) DO NOTHING;

-- Verify setup
SELECT app_id, updated_at FROM public.erp_state;
