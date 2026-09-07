-- Add RLS policies to customer_profiles table
-- This ensures users can only view and update their own profiles

-- Enable RLS if not already enabled
ALTER TABLE IF EXISTS public.customer_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.customer_profiles;

-- RLS Policy: Users can only see their own profile
CREATE POLICY "Users can view their own profile" ON public.customer_profiles
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policy: Users can update their own profile (with proper WITH CHECK clause)
CREATE POLICY "Users can update their own profile" ON public.customer_profiles
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can insert their own profile
CREATE POLICY "Users can insert their own profile" ON public.customer_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);
