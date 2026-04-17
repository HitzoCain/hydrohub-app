# Supabase Migrations

This directory contains SQL migrations for the Aqua In Laba App database schema.

## How to Apply Migrations

### Option 1: Using Supabase Dashboard (Recommended for this project)

1. Go to https://app.supabase.com
2. Select your project: **aqua_in_laba_app**
3. Navigate to **SQL Editor** in the left sidebar
4. Click **New Query**
5. Copy the SQL from the migration file (e.g., `20260416_add_customer_location.sql`)
6. Paste into the editor
7. Click **Run**

### Option 2: Using Supabase CLI (If installed)

```bash
supabase migration up
```

## Migration: 20260416_add_customer_location.sql

**Purpose**: Add GPS coordinates (customer_lat, customer_lng) to the orders table

**Changes**:
- `customer_lat NUMERIC` - Customer delivery location latitude
- `customer_lng NUMERIC` - Customer delivery location longitude
- Both columns are nullable
- Creates index on (customer_lat, customer_lng) for efficient location queries

**Why**: 
- Stores exact GPS coordinates instead of relying on address text alone
- Enables accurate map display and distance calculations
- Allows for location-based queries and analytics
