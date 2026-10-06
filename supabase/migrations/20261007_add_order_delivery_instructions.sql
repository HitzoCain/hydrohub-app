ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_instructions TEXT;