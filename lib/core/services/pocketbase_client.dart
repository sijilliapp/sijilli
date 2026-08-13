// 📍 lib/core/services/pocketbase_client.dart
// 🔌 العميل الموحد للاتصال بـ PocketBase

import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../../models/user.dart';
import '../local/persistent_auth_store.dart';

class PocketBaseClient {
  static PocketBaseClient? _instance;
  static PocketBaseClient get instance => _instance ??= PocketBaseClient._();
  
  PocketBaseClient._();
  
  static const String _defaultUrl = 'https://sijilli.pockethost.io';
  late PocketBase pb;
  late PersistentAuthStore _store;
  
  Future<void> initialize({String? customUrl}) async {
    _store = PersistentAuthStore();
    await _store.load();
    pb = PocketBase(
      customUrl ?? _defaultUrl,
      authStore: _store,
      httpClientFactory: () => PocketBaseHttpClient(),
    );
  }

  /// الحصول على المستخدم الحالي من الـ AuthStore
  UserModel? get currentUser {
    if (!pb.authStore.isValid) return null;
    try {
      final record = pb.authStore.record;
      if (record != null) {
        return UserModel.fromJson(record.toJson(), token: pb.authStore.token);
      }
    } catch (e) {
      print('❌ Error parsing current user: $e');
    }
    return null;
  }

  /// قطع كافة الاتصالات اللحظية (مهم عند تسجيل الخروج لمنع أخطاء 403)
  Future<void> disconnectRealtime() async {
    try {
      await pb.realtime.unsubscribe();
      print('🔌 [PocketBaseClient] Realtime disconnected and unsubscribed from all.');
    } catch (e) {
      print('⚠️ [PocketBaseClient] Error during realtime disconnect: $e');
    }
  }
}

/// عميل HTTP مخصص يقوم بإيقاظ خادم PocketBase تلقائياً إذا كان في حالة إسبات (Cold Start)
/// ويعيد محاولة الطلبات الآمنة (GET) لضمان عدم فشل العمليات بعد فترات الخمول الطويلة.
class PocketBaseHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  static DateTime _lastSuccessTime = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _isWakingUp = false;
  bool _isClosed = false;

  @override
  void close() {
    _isClosed = true;
    _inner.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isClosed) {
      throw http.ClientException('Client closed', request.url);
    }

    final now = DateTime.now();
    final needsWakeup = now.difference(_lastSuccessTime) > const Duration(minutes: 5);

    if (needsWakeup && !_isWakingUp) {
      // Run proactive wake up ping in the background without blocking the original request
      _wakeUpServer(request.url.origin).catchError((e) {
        print('⚠️ [PocketBaseHttpClient] Proactive wake up ping failed: $e');
      });
    }

    int attempts = 3;
    while (attempts > 0) {
      if (_isClosed) {
        throw http.ClientException('Client closed', request.url);
      }
      try {
        final clonedRequest = await _cloneRequest(request);
        final response = await _inner.send(clonedRequest);
        
        if (response.statusCode < 500) {
          _lastSuccessTime = DateTime.now();
          return response;
        }

        // إذا كان خطأ خادم (500+) وكان الطلب للقراءة (GET) فنعيد المحاولة
        final isGet = request.method == 'GET' || request.method == 'HEAD';
        if (!isGet || _isClosed || attempts == 1) {
          return response;
        }

        print('⚠️ [PocketBaseHttpClient] GET request failed with status ${response.statusCode}, retrying...');
      } catch (e) {
        final isGet = request.method == 'GET' || request.method == 'HEAD';
        if (!isGet || _isClosed || attempts == 1) {
          rethrow;
        }
        print('⚠️ [PocketBaseHttpClient] Request connection failed, retrying GET request: $e');
        await _wakeUpServer(request.url.origin);
      }
      attempts--;
      if (attempts > 0 && !_isClosed) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return _inner.send(request);
  }

  Future<http.BaseRequest> _cloneRequest(http.BaseRequest request) async {
    if (request is http.Request) {
      return http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..maxRedirects = request.maxRedirects
        ..followRedirects = request.followRedirects
        ..persistentConnection = request.persistentConnection
        ..bodyBytes = request.bodyBytes;
    }
    return request;
  }

  Future<void> _wakeUpServer(String origin) async {
    if (_isWakingUp) {
      int waitAttempts = 5;
      while (_isWakingUp && waitAttempts > 0) {
        await Future.delayed(const Duration(seconds: 1));
        waitAttempts--;
      }
      return;
    }

    _isWakingUp = true;
    final healthUrl = Uri.parse('$origin/api/health');
    int retries = 5;
    try {
      while (retries > 0 && !_isClosed) {
        try {
          print('⏰ [PocketBaseHttpClient] Sending wake up ping to $healthUrl (retries left: $retries)...');
          final res = await _inner.get(healthUrl).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            print('✅ [PocketBaseHttpClient] Server is awake and healthy!');
            _lastSuccessTime = DateTime.now();
            return;
          }
        } catch (e) {
          print('⏳ [PocketBaseHttpClient] Wake up ping failed, retrying in 1.5s: $e');
        }
        retries--;
        if (retries > 0 && !_isClosed) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    } finally {
      _isWakingUp = false;
    }
  }
}
