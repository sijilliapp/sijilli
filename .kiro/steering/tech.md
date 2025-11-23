# Technology Stack

## Framework & Language

- **Flutter** (SDK >=3.9.0 <4.0.0)
- **Dart** programming language
- **Material Design 3** (useMaterial3: true)

## Backend & Database

- **PocketBase** (v0.23.0+1) - Backend as a Service
  - Hosted at: `https://sijilli.pockethost.io`
  - Authentication, database, file storage
  - Real-time subscriptions
- **SQLite** (sqflite v2.4.2) - Local database for mobile/desktop
- **SharedPreferences** (v2.5.3) - Local storage for web and simple data

## Key Dependencies

### Core Services
- `pocketbase: ^0.23.0+1` - Backend client
- `sqflite: ^2.4.2` - Local database
- `shared_preferences: ^2.5.3` - Local key-value storage
- `connectivity_plus: ^6.1.0` - Network connectivity detection

### Date & Time
- `hijri: ^3.0.0` - Hijri calendar support
- `timezone: ^0.10.1` - Timezone handling
- `intl: ^0.20.1` - Internationalization

### Media & Files
- `image_picker: ^1.2.0` - Image selection
- `path: ^1.9.1` - Path manipulation

### Development
- `flutter_lints: ^5.0.0` - Linting rules
- `flutter_launcher_icons: ^0.14.4` - App icon generation

## Architecture Patterns

### Singleton Pattern
- All services use singleton pattern (e.g., `AuthService._instance`)
- Ensures single instance across the app

### Local-First Architecture
- **Cache-First Strategy**: Load from local storage immediately
- **Background Sync**: Update from server without blocking UI
- **Offline Support**: Full functionality with cached data
- **Optimistic Updates**: Update UI immediately, sync later

### Service Layer
- Separate service classes for each domain:
  - `AuthService` - Authentication and user management
  - `DatabaseService` - Local database operations
  - `ConnectivityService` - Network status monitoring
  - `FollowService` - Follow/unfollow operations
  - `HijriService` - Hijri calendar conversions
  - `SunsetService` - Prayer times and sunset calculations
  - `TimezoneService` - Timezone conversions
  - `UserAppointmentStatusService` - User-specific appointment states

### Model Layer
- Immutable model classes with `fromJson` and `toJson` methods
- Models: `UserModel`, `AppointmentModel`, `InvitationModel`, `PostModel`, `UserAppointmentStatusModel`

## Database Schema

### Collections (PocketBase)

1. **users** (auth collection)
   - Fields: id, username, name, email, avatar, bio, social_link, phone, role, hijri_adjustment, isPublic
   - Roles: user, approved, admin
   - Auth: email/username + password

2. **appointments**
   - Fields: id, title, region, building, privacy, status, appointment_date, date_type, host, duration, hijri_day, hijri_month, hijri_year
   - Privacy: public, private
   - Status: active, deleted, archived, cancelled, cancelled_by_host

3. **invitations**
   - Fields: id, appointment, guest, status, respondedAt
   - Status: invited, accepted, rejected, deleted_after_accept

4. **follows**
   - Fields: id, follower, following, status
   - Status: approved, pending, block

5. **posts**
   - Fields: id, content, author, likes_count, comments_count, images, is_public

6. **user_appointment_status**
   - Fields: id, user, appointment, status, deleted_at, my_note
   - Status: active, deleted, archived
   - Tracks individual user's relationship with appointments

7. **visits**
   - Fields: id, visitor, visited, date_time, profile_section, visit_type, is_read

## Common Commands

### Development
```bash
# Run app
flutter run

# Run on specific device
flutter run -d chrome
flutter run -d windows
flutter run -d android

# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
```

### Build
```bash
# Build APK (Android)
flutter build apk --release

# Build App Bundle (Android)
flutter build appbundle --release

# Build iOS
flutter build ios --release

# Build Web
flutter build web --release

# Build Windows
flutter build windows --release
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/arabic_search_test.dart
```

### Maintenance
```bash
# Get dependencies
flutter pub get

# Update dependencies
flutter pub upgrade

# Clean build
flutter clean

# Check for issues
flutter doctor

# Analyze code
flutter analyze
```

### Icons
```bash
# Generate app icons
flutter pub run flutter_launcher_icons
```

## Code Style Guidelines

### Naming Conventions
- **Classes**: PascalCase (e.g., `UserModel`, `AuthService`)
- **Files**: snake_case (e.g., `auth_service.dart`, `user_model.dart`)
- **Variables/Functions**: camelCase (e.g., `currentUser`, `getUserById`)
- **Constants**: camelCase with const (e.g., `pocketbaseUrl`)
- **Private members**: prefix with underscore (e.g., `_database`, `_initAuth`)

### File Organization
- Models in `lib/models/`
- Services in `lib/services/`
- Screens in `lib/screens/`
- Widgets in `lib/widgets/`
- Utils in `lib/utils/`
- Config in `lib/config/`

### Best Practices
- Use `const` constructors where possible
- Prefer `final` over `var`
- Use `??` and `?.` for null safety
- Always handle errors with try-catch
- Use `async`/`await` for asynchronous operations
- Dispose controllers and timers in `dispose()`
- Use `mounted` check before `setState()` after async operations

### Arabic Support
- Use `TextDirection.rtl` for Arabic text
- Normalize Arabic text for search using `ArabicSearchUtils`
- Support both Arabic and English in UI
- Handle Arabic date formats (Hijri calendar)

### Performance
- Use `ListView.builder` for long lists
- Implement pagination for large datasets
- Cache images and data locally
- Use `RepaintBoundary` for complex widgets
- Avoid rebuilding entire widget trees

### State Management
- Use `StatefulWidget` for local state
- Use `setState()` for UI updates
- Services hold app-wide state (singleton pattern)
- Use `SharedPreferences` for persistent state

## Platform-Specific Notes

### Web
- Uses `SharedPreferences` instead of SQLite
- No file system access
- CORS considerations for API calls

### Mobile (Android/iOS)
- Uses SQLite for local database
- File system access available
- Image picker for camera/gallery

### Desktop (Windows/macOS/Linux)
- Uses SQLite for local database
- File system access available
- Window management considerations
