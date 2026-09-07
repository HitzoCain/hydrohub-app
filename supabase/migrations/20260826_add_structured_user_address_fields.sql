-- Add structured Philippine administrative fields while preserving legacy address data.
ALTER TABLE user_addresses
  ADD COLUMN IF NOT EXISTS region text,
  ADD COLUMN IF NOT EXISTS region_code text,
  ADD COLUMN IF NOT EXISTS province text,
  ADD COLUMN IF NOT EXISTS province_code text,
  ADD COLUMN IF NOT EXISTS city_municipality text,
  ADD COLUMN IF NOT EXISTS city_municipality_code text,
  ADD COLUMN IF NOT EXISTS barangay text,
  ADD COLUMN IF NOT EXISTS barangay_code text,
  ADD COLUMN IF NOT EXISTS street text,
  ADD COLUMN IF NOT EXISTS house_number text,
  ADD COLUMN IF NOT EXISTS landmark text;

CREATE INDEX IF NOT EXISTS idx_user_addresses_barangay_code
  ON user_addresses (barangay_code);
CREATE INDEX IF NOT EXISTS idx_user_addresses_city_municipality_code
  ON user_addresses (city_municipality_code);
