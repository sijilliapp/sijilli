import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/broadcast.dart';
import '../services/pb_broadcast_service.dart';

class BroadcastProvider extends ChangeNotifier {
  final PbBroadcastService _service = PbBroadcastService();

  List<Broadcast> _broadcasts = [];
  bool _isLoading = false;
  Set<String> _readBroadcastIds = {};

  List<Broadcast> get broadcasts => _broadcasts;
  bool get isLoading => _isLoading;
  Set<String> get readBroadcastIds => _readBroadcastIds;

  static const String keyReadBroadcasts = 'read_broadcast_ids';

  BroadcastProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadReadStatus();
    await fetchBroadcasts();
  }

  Future<void> _loadReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(keyReadBroadcasts) ?? [];
      _readBroadcastIds = list.toSet();
      notifyListeners();
    } catch (e) {
      print('⚠️ Failed to load read broadcasts status: $e');
    }
  }

  /// جلب النشرات من قاعدة البيانات
  Future<void> fetchBroadcasts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _broadcasts = await _service.fetchActiveBroadcasts();
    } catch (e) {
      print('⚠️ Error in BroadcastProvider fetchBroadcasts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تصفية النشرات حسب دور المستخدم (إذا كانت الأدوار المستهدفة فارغة تظهر للجميع)
  List<Broadcast> getFilteredBroadcasts(String? userRole, {String? type}) {
    var filtered = _broadcasts;
    if (userRole != null && userRole.isNotEmpty) {
      filtered = filtered.where((b) {
        if (b.targetRoles.isEmpty) return true;
        return b.targetRoles.contains(userRole);
      }).toList();
    }
    
    if (type != null) {
      filtered = filtered.where((b) => b.type == type).toList();
    }
    
    return filtered;
  }

  /// تحديد النشرة كـ "مقروءة" محلياً
  Future<void> markAsRead(String id) async {
    if (_readBroadcastIds.contains(id)) return;
    _readBroadcastIds.add(id);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(keyReadBroadcasts, _readBroadcastIds.toList());
    } catch (e) {
      print('⚠️ Failed to save read broadcast status: $e');
    }
  }

  /// التحقق مما إذا كان هناك مقالات نظام غير مقروءة للمستخدم الحالي
  bool hasUnreadArticles(String? userRole) {
    final articles = getFilteredBroadcasts(userRole, type: 'article');
    return articles.any((a) => !_readBroadcastIds.contains(a.id));
  }

  /// إنشاء نشرة عامة (خاص بالمشرف)
  Future<bool> createBroadcast({
    required String title,
    required String content,
    required String type,
    DateTime? expiresAt,
    required List<String> targetRoles,
  }) async {
    final result = await _service.createBroadcast(
      title: title,
      content: content,
      type: type,
      expiresAt: expiresAt,
      targetRoles: targetRoles,
    );

    if (result != null) {
      await fetchBroadcasts(); // إعادة التحميل لتحديث القائمة
      return true;
    }
    return false;
  }

  /// حذف نشرة عامة (خاص بالمشرف)
  Future<bool> deleteBroadcast(String id) async {
    final success = await _service.deleteBroadcast(id);
    if (success) {
      await fetchBroadcasts(); // إعادة التحميل لتحديث القائمة
      return true;
    }
    return false;
  }
}
