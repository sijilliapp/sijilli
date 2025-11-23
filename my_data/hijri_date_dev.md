# 📅 Hijri Date System - Developer Guide

## 🎯 Core Concept: "Green Door Logic"

**Think of user adjustment like painting a door green:**
- User paints their door green **once** → Door becomes permanently green
- All visitors see the green door → No need to repaint for each visitor
- If user wants to change color → Paint it **once** again

**In code terms:**
- User sets adjustment **once** → All dates become adjusted
- All screens show adjusted dates → No dynamic adjustment needed
- If user changes adjustment → Recalculate all dates **once**

## 🏢 Architecture: Central Operations Room

### Core Service: `HijriService`
```dart
class HijriService {
  static final HijriService _instance = HijriService._internal();
  factory HijriService() => _instance;
  
  final AuthService _authService = AuthService();
  int? _temporaryAdjustment; // For preview during editing only
}
```

**Key Principle:** All Hijri operations go through this single service.

## 🔧 Core Methods

### 1. Adjustment Management
```dart
// Get user's permanent adjustment
int get currentUserAdjustment => _authService.currentUser?.hijriAdjustment ?? 0;

// Get effective adjustment (temporary override or permanent)
int get currentAdjustment => _temporaryAdjustment ?? currentUserAdjustment;

// Set temporary adjustment (for preview during editing)
void setTemporaryAdjustment(int adjustment) => _temporaryAdjustment = adjustment;

// Clear temporary adjustment
void clearTemporaryAdjustment() => _temporaryAdjustment = null;
```

### 2. Core Conversion Engine
```dart
// Main conversion: Gregorian → Hijri (with adjustment)
HijriCalendar convertGregorianToHijri(DateTime gregorianDate) {
  final adjustment = currentAdjustment;
  final adjustedDate = gregorianDate.add(Duration(days: adjustment));
  return HijriCalendar.fromDate(adjustedDate);
}

// Reverse conversion: Hijri → Gregorian (with reverse adjustment)
DateTime convertHijriToGregorian(int year, int month, int day) {
  final hijriCalendar = HijriCalendar();
  final gregorianDate = hijriCalendar.hijriToGregorian(year, month, day);
  final adjustment = currentAdjustment;
  return gregorianDate.subtract(Duration(days: adjustment));
}
```

### 3. Utility Methods
```dart
// Format Hijri date as Arabic text
String formatHijriDate(HijriCalendar hijriDate) {
  const months = ['محرم', 'صفر', 'ربيع الأول', ...];
  final monthName = months[hijriDate.hMonth - 1];
  return '${hijriDate.hDay} $monthName ${hijriDate.hYear} هـ';
}

// Get today's Hijri date (with adjustment)
HijriCalendar getTodayHijri() => convertGregorianToHijri(DateTime.now());

// Get today's Hijri as formatted string
String getTodayHijriString() => formatHijriDate(getTodayHijri());
```

## 📱 Usage Patterns

### In Draft/Add Forms
```dart
class AppointmentForm extends StatefulWidget {
  final HijriService _hijriService = HijriService();
  
  void _updateDate() {
    // Always use HijriService for conversions
    final hijriDate = _hijriService.convertGregorianToHijri(_selectedDate);
    final formattedDate = _hijriService.formatHijriDate(hijriDate);
  }
}
```

### In Settings Screen
```dart
class SettingsScreen extends StatefulWidget {
  void _onAdjustmentChanged(int newAdjustment) {
    // Set temporary adjustment for preview
    _hijriService.setTemporaryAdjustment(newAdjustment);
    setState(() {}); // Refresh UI
  }
  
  void _saveSettings() {
    // Save to database via AuthService
    await _authService.updateUser(hijriAdjustment: _hijriAdjustment);
    // Clear temporary adjustment
    _hijriService.clearTemporaryAdjustment();
  }
  
  void _cancelSettings() {
    // Just clear temporary adjustment
    _hijriService.clearTemporaryAdjustment();
  }
}
```

## 🗄️ Database Schema

### User Table
```sql
users {
  id: string
  hijri_adjustment: number (-2 to +2)
  -- other fields...
}
```

### Appointment Table (Future)
```sql
appointments {
  id: string
  primary_date_type: string ('hijri' | 'gregorian')
  primary_date: datetime
  -- other fields...
}
```

## 🔄 Data Flow

### 1. User Changes Adjustment
```
User clicks +/- → setTemporaryAdjustment() → UI updates with preview
User saves → AuthService.updateUser() → Database updated
User cancels → clearTemporaryAdjustment() → UI reverts
```

### 2. Date Conversion
```
Any screen needs date → HijriService.convertGregorianToHijri()
→ Gets currentAdjustment → Applies adjustment → Returns HijriCalendar
```

### 3. Display
```
HijriCalendar object → HijriService.formatHijriDate()
→ Returns Arabic formatted string → Display in UI
```

## 🎯 Key Programming Principles

### 1. Single Responsibility
- **HijriService**: Only handles Hijri conversions and adjustments
- **AuthService**: Only handles user data and authentication
- **UI Components**: Only handle display and user interaction

### 2. Dependency Injection
```dart
class MyScreen extends StatefulWidget {
  final HijriService _hijriService = HijriService(); // Singleton
}
```

### 3. Immutable Operations
```dart
// Don't modify existing dates
final adjustedDate = originalDate.add(Duration(days: adjustment));

// Don't modify HijriCalendar objects
final newHijri = HijriCalendar.fromDate(adjustedDate);
```

### 4. Clear State Management
```dart
// Temporary state (for preview)
int? _temporaryAdjustment;

// Permanent state (from database)
int get currentUserAdjustment => _authService.currentUser?.hijriAdjustment ?? 0;
```

## 🧪 Testing Strategy

### Unit Tests
```dart
test('convertGregorianToHijri with adjustment', () {
  final service = HijriService();
  service.setTemporaryAdjustment(1);
  
  final result = service.convertGregorianToHijri(DateTime(2025, 1, 1));
  // Assert result is one day ahead
});
```

### Integration Tests
```dart
testWidgets('settings adjustment preview', (tester) async {
  // Test that UI updates when adjustment changes
  // Test that temporary adjustment is applied
  // Test that save/cancel works correctly
});
```

## 🚀 Future Enhancements

### 1. Caching
```dart
final Map<String, HijriCalendar> _conversionCache = {};

HijriCalendar convertGregorianToHijri(DateTime date) {
  final key = '${date.millisecondsSinceEpoch}_$currentAdjustment';
  return _conversionCache[key] ??= _performConversion(date);
}
```

### 2. Error Handling
```dart
HijriCalendar convertGregorianToHijri(DateTime date) {
  try {
    // conversion logic
  } catch (e) {
    // Log error and return fallback
    return HijriCalendar.now();
  }
}
```

### 3. Validation
```dart
void setTemporaryAdjustment(int adjustment) {
  if (adjustment < -2 || adjustment > 2) {
    throw ArgumentError('Adjustment must be between -2 and +2');
  }
  _temporaryAdjustment = adjustment;
}
```

## 📋 Checklist for New Developers

- [ ] Understand the "Green Door" concept
- [ ] Know that HijriService is the single source of truth
- [ ] Always use HijriService for any date conversion
- [ ] Understand temporary vs permanent adjustments
- [ ] Know the difference between preview and save operations
- [ ] Test with different adjustment values (-2 to +2)
- [ ] Verify that canceling reverts to original state

## 🔗 Dependencies

```yaml
dependencies:
  hijri: ^3.0.0  # Core Hijri calendar library
```

**Key External Methods Used:**
- `HijriCalendar.fromDate(DateTime)` - Convert Gregorian to Hijri
- `HijriCalendar.hijriToGregorian(year, month, day)` - Convert Hijri to Gregorian
- `HijriCalendar.now()` - Get current Hijri date

---

**Remember: Keep it simple, keep it central, keep it consistent!** 🎯
