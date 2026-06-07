import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../../core/widgets/pulse_avatar.dart';
import '../../appointments/services/pb_appointment_browse_service.dart';
import '../../../models/appointment.dart';

class UserStatusProvider extends ChangeNotifier {
  final Map<String, AvatarStatus> _statuses = {};
  final Set<String> _fetchingIds = {};
  final Queue<String> _requestQueue = Queue<String>();
  bool _isProcessing = false;
  
  final PbAppointmentBrowseService _apptService = PbAppointmentBrowseService();

  AvatarStatus getStatus(String userId) {
    return _statuses[userId] ?? AvatarStatus.none;
  }

  /// Fetch status for a user sequentially to prevent 429 Too Many Requests
  Future<void> fetchStatus(String userId, {bool force = false}) async {
    if (!force && _statuses.containsKey(userId)) return;
    if (_fetchingIds.contains(userId) || _requestQueue.contains(userId)) return;

    _requestQueue.add(userId);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_requestQueue.isNotEmpty) {
      final userId = _requestQueue.removeFirst();
      _fetchingIds.add(userId);
      
      try {
        final appointments = await _apptService.getPublicAppointments(userId);
        AvatarStatus newStatus = AvatarStatus.none;
        if (appointments.any((a) => a.isNow)) {
          newStatus = AvatarStatus.active;
        } else if (appointments.any((a) => a.isUpcoming)) {
          newStatus = AvatarStatus.upcoming;
        }
        
        _statuses[userId] = newStatus;
        notifyListeners();
      } catch (e) {
        print('Error fetching status for $userId: $e');
      } finally {
        _fetchingIds.remove(userId);
      }
      
      // Small delay to prevent API rate limits on PocketHost
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _isProcessing = false;
  }

  void updateStatus(String userId, AvatarStatus status) {
    _statuses[userId] = status;
    notifyListeners();
  }

  void clear() {
    _statuses.clear();
    _fetchingIds.clear();
    _requestQueue.clear();
    _isProcessing = false;
    notifyListeners();
  }
}
