import 'package:hive_flutter/hive_flutter.dart';

class AppointmentDraftService {
  static const String boxName = 'appointment_drafts';
  static const String draftKey = 'current_draft';

  Future<void> saveDraft(Map<String, dynamic> data) async {
    final box = await Hive.openBox(boxName);
    await box.put(draftKey, data);
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final box = await Hive.openBox(boxName);
    final data = box.get(draftKey);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<void> clearDraft() async {
    final box = await Hive.openBox(boxName);
    await box.delete(draftKey);
  }
}
