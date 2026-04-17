-- Add customer location columns to orders table
-- This migration adds GPS coordinates for customer delivery location
-- Replaces reliance on address text alone

ALTER TABLE orders
ADD COLUMN customer_lat NUMERIC,
ADD COLUMN customer_lng NUMERIC;

-- Add index for location-based queries (optional, for performance)
CREATE INDEX idx_orders_customer_location ON orders(customer_lat, customer_lng)
WHERE customer_lat IS NOT NULL AND customer_lng IS NOT NULL;

-- Comments for documentation
COMMENT ON COLUMN orders.customer_lat IS 'Customer delivery location latitude (GPS)';
COMMENT ON COLUMN orders.customer_lng IS 'Customer delivery location longitude (GPS)';
