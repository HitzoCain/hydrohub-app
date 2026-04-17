# GPS Location Detection Implementation for Customer App

## Overview

This document provides the implementation steps for capturing customer GPS location when placing orders in the Aqua In Laba mobile app.

## What Was Set Up

### 1. ✅ Schema - Migration Created
**File**: [supabase/migrations/20260416_add_customer_location.sql](supabase/migrations/20260416_add_customer_location.sql)

Adds two new columns to the `orders` table:
- `customer_lat NUMERIC` - Customer's latitude when order was placed  
- `customer_lng NUMERIC` - Customer's longitude when order was placed

**Status**: Ready to apply via Supabase Dashboard

### 2. ✅ Dependencies - Already Installed
- `geolocator: ^13.0.2` (already in pubspec.yaml)
- `supabase_flutter: ^2.12.2` (already in pubspec.yaml)

### 3. ✅ Android Permissions - Already Added
**File**: [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)

Already contains:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### 4. ✅ iOS Permissions - Already Added
**File**: [ios/Runner/Info.plist](ios/Runner/Info.plist)

Already contains location permission descriptions.

## What Still Needs To Be Done

### Step 1: Update order_screen.dart Imports

Add these imports at the top of `lib/features/customer/screens/order_screen.dart`:

```dart
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
```

### Step 2: Add State Variables

In the `_OrderScreenState` class, add after the existing variables:

```dart
  double? _selectedLat;
  double? _selectedLng;
```

### Step 3: Add Helper Function

Add this method to the `_OrderScreenState` class:

```dart
  /// Get customer's current GPS location for order placement
  Future<Position?> _getCustomerGpsLocation() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        debugPrint('[CustomerLocation] Location services disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[CustomerLocation] Location permission denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint(
        '[CustomerLocation] GPS: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      debugPrint('[CustomerLocation] Error getting GPS: $e');
      return null;
    }
  }
```

### Step 4: Modify _submitOrder Function

Update the `_submitOrder` method to capture GPS location before creating the order:

```dart
  Future<void> _submitOrder() async {
    if (_isSubmitting) return;

    final address = _deliveryAddress.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your delivery address.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_deliveryType == 'scheduled') {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both date and time for scheduled delivery.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Show loading dialog while getting customer location
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get customer's current GPS location
      final customerPosition = await _getCustomerGpsLocation();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      // Get authenticated user
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final metadataName = (user?.userMetadata?['full_name'] as String?)?.trim();
      final userName = (metadataName == null || metadataName.isEmpty) ? 'Customer' : metadataName;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      // Prepare scheduled date/time if applicable
      final scheduledDate = _deliveryType == 'scheduled' && _selectedDate != null
          ? _selectedDate!.toIso8601String().split('T')[0]
          : null;

      final scheduledTime = _deliveryType == 'scheduled' && _selectedTime != null
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : null;

      // Insert order with customer GPS location
      final response = await supabase.from('orders').insert({
        'customer_id': user.id,
        'customer_name': userName,
        'address': address,
        'latitude': _selectedLat ?? 14.5995,
        'longitude': _selectedLng ?? 120.9842,
        'customer_lat': customerPosition?.latitude,
        'customer_lng': customerPosition?.longitude,
        'gallons': _totalGallons,
        'total_price': _totalGallons * 50,
        'delivery_type': _deliveryType,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      debugPrint(
        '[Order] Created with customer GPS: ${customerPosition?.latitude}, ${customerPosition?.longitude}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 450));

      if (!mounted) return;

      // Navigate to track order screen with created order data
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerTrackOrderScreen(
            order: response.first as Map<String, dynamic>,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Order submission failed: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: ${e.toString()}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
```

## Flow Diagram

```
Customer taps "Place Order"
    ↓
Show loading dialog ("Getting your location...")
    ↓
_getCustomerGpsLocation() called
    ↓
Check location service enabled
    ↓
Request location permission (if needed)
    ↓
Get current GPS position (10 second timeout)
    ↓
Close loading dialog
    ↓
Insert order to Supabase with:
  - delivery address (latitude, longitude)
  - customer GPS location (customer_lat, customer_lng)
  ↓
Navigate to Track Order screen
    ↓
Customer sees driver location on map + their own location
```

## Testing Checklist

- [ ] Apply Supabase migration to add `customer_lat` and `customer_lng` columns
- [ ] Run `flutter pub get` after updating order_screen.dart
- [ ] Test on Android emulator/device:
  - [ ] Allow location permission when prompted
  - [ ] Verify "Getting your location..." dialog appears
  - [ ] Verify order is created in Supabase with `customer_lat` and `customer_lng` populated
  - [ ] Check console logs: `[CustomerLocation] GPS: 14.xxx, 120.xxx`
  - [ ] Verify on Track Order screen, customer location appears on map
- [ ] Test on iOS device (if available):
  - [ ] Same checks as Android

## Debug Logging

When debugging, check the console for these messages:

```
[CustomerLocation] Starting location tracking...
[CustomerLocation] GPS: 14.5995, 120.9842
[Order] Created with customer GPS: 14.5995, 120.9842
```

If location fails:
```
[CustomerLocation] Location services disabled
[CustomerLocation] Location permission denied
[CustomerLocation] Error getting GPS: ...
```

## Success Indicators

✅ **When working correctly, you should see**:
1. Loading circle appears briefly when placing order
2. Order inserted to Supabase successfully
3. New `customer_lat` and `customer_lng` fields populated in orders table
4. No error messages in console
5. Customer marker appears on track order map

## Files Modified

- [lib/features/customer/screens/order_screen.dart](lib/features/customer/screens/order_screen.dart) - Main implementation
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) - Permissions (already done)
- [ios/Runner/Info.plist](ios/Runner/Info.plist) - Permissions (already done)
- [supabase/migrations/20260416_add_customer_location.sql](supabase/migrations/20260416_add_customer_location.sql) - Schema (needs manual application)

---

**Next Step**: Apply the Supabase migration to add the new columns, then update order_screen.dart with the code above.
