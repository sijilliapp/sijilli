# Project Structure

## Root Directory Layout

```
sijilli/
├── lib/                    # Main application code
├── assets/                 # Static assets (images, fonts, data)
├── test/                   # Test files
├── android/                # Android platform code
├── ios/                    # iOS platform code
├── web/                    # Web platform code
├── my_data/                # Documentation and project data
├── .kiro/                  # Kiro AI steering rules
└── pubspec.yaml            # Project dependencies
```

## lib/ Directory Structure

### Core Files
- `main.dart` - App entry point, initializes services and runs app

### config/
- `constants.dart` - App-wide constants (URLs, collection names, keys)

### models/
Data models representing database entities:
- `user_model.dart` - User profile data
- `appointment_model.dart` - Appointment/meeting data
- `invitation_model.dart` - Invitation to appointments
- `post_model.dart` - Social posts
- `user_appointment_status_model.dart` - User-specific appointment state

**Model Pattern:**
- Immutable classes with final fields
- `fromJson()` factory constructor for deserialization
- `toJson()` method for serialization
- `fromMap()` and `toMap()` for SQLite operations

### services/
Business logic and data access layer:
- `auth_service.dart` - Authentication, user management, session handling
- `database_service.dart` - Local SQLite/SharedPreferences operations
- `connectivity_service.dart` - Network status monitoring
- `follow_service.dart` - Follow/unfollow operations
- `hijri_service.dart` - Hijri calendar conversions
- `sunset_service.dart` - Prayer times and sunset calculations
- `timezone_service.dart` - Timezone conversions and formatting
- `user_appointment_status_service.dart` - User-appointment relationship management

**Service Pattern:**
- Singleton pattern for all services
- Private constructor with factory method
- Centralized business logic
- Error handling with user-friendly messages in Arabic

### screens/
Full-page UI components:
- `splash_screen.dart` - Initial loading screen
- `login_screen.dart` - User login
- `register_screen.dart` - New user registration
- `forgot_password_screen.dart` - Password reset
- `main_screen.dart` - Bottom navigation container
- `home_screen.dart` - User profile and appointments feed
- `user_profile_screen.dart` - View other user profiles
- `appointment_details_screen.dart` - Detailed appointment view
- `notifications_screen.dart` - Notifications list
- `friends_screen.dart` - Followers/following lists
- `internal_settings_screen.dart` - App settings
- `editable_settings_screen.dart` - Edit user profile
- `draft_forms_screen.dart` - Draft appointments

**Screen Pattern:**
- StatefulWidget for interactive screens
- Scaffold with AppBar
- Bottom navigation in main_screen.dart
- RTL support for Arabic

### widgets/
Reusable UI components:
- `app_logo.dart` - Application logo widget
- `appointment_card.dart` - Appointment display card
- `invitation_card.dart` - Invitation display card

**Widget Pattern:**
- Small, focused, reusable components
- Accept data via constructor parameters
- Callbacks for user interactions
- Const constructors where possible

### utils/
Helper functions and utilities:
- `arabic_search_utils.dart` - Arabic text normalization for search
- `date_converter.dart` - Date format conversions (Gregorian ↔ Hijri)

**Utils Pattern:**
- Static utility classes
- Pure functions without side effects
- Focused on specific tasks

## assets/ Directory

### assets/logo/
- `app_icon.png` - Application icon
- Other logo variations

### assets/fonts/
- Custom fonts (if any)

### assets/data/
- Static data files (e.g., timezone data, prayer times)

## my_data/ Directory

Project documentation and reference materials:
- `sijilli_PRD.txt` - Product Requirements Document (Arabic)
- `home_profile.md` - Home screen specifications
- `pb_schema.json` - PocketBase database schema
- `hijri_date_PRd.txt` - Hijri date feature requirements
- `hijri_date_dev.md` - Hijri date development notes
- `access_rules_documentation.md` - Database access rules
- `card_formats.txt` - UI card design specifications
- `sunrise_sunset_times.csv` - Prayer times data
- Various Arabic documentation files

## test/ Directory

- `widget_test.dart` - Widget tests
- `arabic_search_test.dart` - Arabic search functionality tests
- `timezone_test.dart` - Timezone conversion tests

## Platform Directories

### android/
- Android-specific configuration
- Gradle build files
- AndroidManifest.xml
- Native Android code (if any)

### ios/
- iOS-specific configuration
- Xcode project files
- Info.plist
- Native iOS code (if any)

### web/
- `index.html` - Web entry point
- `manifest.json` - PWA manifest
- `.htaccess` - Server configuration
- `robots.txt` - SEO configuration
- `sitemap.xml` - SEO sitemap
- `sw.js` - Service worker for PWA

## Key Architectural Patterns

### Navigation Flow
```
SplashScreen
    ↓
LoginScreen / RegisterScreen
    ↓
MainScreen (Bottom Navigation)
    ├── HomeScreen (Tab 0)
    ├── SearchScreen (Tab 1)
    ├── AddAppointmentScreen (Tab 2)
    ├── NotificationsScreen (Tab 3)
    └── SettingsScreen (Tab 4)
```

### Data Flow
```
UI (Screens/Widgets)
    ↓
Services (Business Logic)
    ↓
Models (Data Structures)
    ↓
PocketBase API / Local Database
```

### Cache Strategy
```
1. Load from local cache (instant)
2. Display cached data
3. Fetch from server (background)
4. Update cache and UI if changed
```

## File Naming Conventions

- **Screens**: `*_screen.dart` (e.g., `home_screen.dart`)
- **Services**: `*_service.dart` (e.g., `auth_service.dart`)
- **Models**: `*_model.dart` (e.g., `user_model.dart`)
- **Widgets**: `*.dart` (descriptive name, e.g., `appointment_card.dart`)
- **Utils**: `*_utils.dart` or `*_converter.dart`

## Import Organization

Order imports as follows:
1. Dart SDK imports (`dart:*`)
2. Flutter imports (`package:flutter/*`)
3. Third-party packages (`package:*`)
4. Local imports (relative paths)

Example:
```dart
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../config/constants.dart';
```

## State Management Approach

- **Local State**: `StatefulWidget` with `setState()`
- **App State**: Singleton services (e.g., `AuthService`)
- **Persistent State**: `SharedPreferences` for simple data, SQLite for complex data
- **No external state management library** (Provider, Riverpod, Bloc, etc.)

## Error Handling Pattern

```dart
try {
  // Operation
  final result = await service.operation();
  // Success handling
} catch (e) {
  // Error handling
  print('❌ Error: $e');
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('رسالة خطأ بالعربية')),
    );
  }
}
```

## Logging Pattern

Use emoji prefixes for log clarity:
- `✅` - Success
- `❌` - Error
- `🔄` - Loading/Syncing
- `📱` - Local cache operation
- `🌐` - Network operation
- `💾` - Save operation
- `🔍` - Search operation
- `📊` - Data operation
