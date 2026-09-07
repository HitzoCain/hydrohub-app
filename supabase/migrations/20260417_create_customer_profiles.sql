-- Create customer_profiles table to store customer personal information
-- Linked to auth.users via user_id

CREATE TABLE IF NOT EXISTS public.customer_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  phone TEXT,
  address TEXT,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_customer_profiles_user_id ON public.customer_profiles(user_id);

-- Create unique index on user_id
CREATE UNIQUE INDEX IF NOT EXISTS customer_profiles_user_id_key ON public.customer_profiles(user_id);

-- Enable RLS
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see their own profile
CREATE POLICY "Users can view their own profile" ON public.customer_profiles
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile" ON public.customer_profiles
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can insert their own profile
CREATE POLICY "Users can insert their own profile" ON public.customer_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Comments for documentation
COMMENT ON TABLE public.customer_profiles IS 'Stores customer profile information';
COMMENT ON COLUMN public.customer_profiles.user_id IS 'Reference to auth.users(id)';
COMMENT ON COLUMN public.customer_profiles.name IS 'Customer full name';
COMMENT ON COLUMN public.customer_profiles.phone IS 'Customer phone number';
COMMENT ON COLUMN public.customer_profiles.address IS 'Customer delivery address';
COMMENT ON COLUMN public.customer_profiles.email IS 'Customer email address';
