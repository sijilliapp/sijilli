import 'package:flutter/material.dart';
import '../../../../models/user.dart';
import '../../../../models/appointment.dart';
import '../../settings/services/pb_user_service.dart';
import '../../appointments/services/pb_appointment_browse_service.dart';

class PublicProfileProvider extends ChangeNotifier {
  final PbUserService _userService = PbUserService();
  final PbAppointmentBrowseService _appointmentBrowseService = PbAppointmentBrowseService();

  UserModel? _user;
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFriend = false;
  String? _error;

  UserModel? get user => _user;
  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  bool get isFollowing => _isFollowing;
  bool get isFriend => _isFriend;
  String? get error => _error;

  Future<void> fetchData(String usernameOrId, {String? currentUserId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _userService.getPublicProfile(usernameOrId);
      
      if (user == null) {
        _error = 'المستخدم غير موجود';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _user = user;
      
      // 2. Fetch Relationship Status and Appointments Concurrently
      final isSelf = user.id == currentUserId;
      final int hijriAdj = (user.hijriAdjustment ?? 0).toInt();

      Future<Map<String, dynamic>> statusFuture = isSelf || currentUserId == null 
          ? Future.value({'status': 'none', 'isFriend': false}) 
          : _userService.getAccreditationStatus(user.id);
          
      // Fetch both public and follower appointments. 
      // We will filter out follower ones later if not a friend in memory.
      Future<List<Appointment>> apptsFuture = _appointmentBrowseService.getPublicAppointments(
        user.id,
        viewerId: currentUserId,
        includeFollowers: true, // Fetch optimistically
        includePrivate: isSelf,
        contextAdjustment: hijriAdj,
      );

      final results = await Future.wait([statusFuture, apptsFuture]);
      final statusData = results[0] as Map<String, dynamic>;
      final allAppts = results[1] as List<Appointment>;

      _isFollowing = statusData['status'] == 'accepted';
      _isFriend = isSelf ? true : (statusData['isFriend'] as bool);
      
      List<Appointment> appts = [];
      
      if (user.isPublic || _isFollowing || isSelf) {
        // Filter out followers-only appointments if not a friend
        if (!_isFriend && !isSelf) {
          appts = allAppts.where((a) => a.privacy != 'followers' || a.privacy == 'public').toList();
        } else {
          appts = allAppts;
        }
      }

      // Priority sorting: Now > Upcoming > Past
      appts.sort((a, b) {
        int score(Appointment app) {
          if (app.isNow) return 0;
          if (app.isUpcoming) return 1;
          return 2;
        }
        
        int sA = score(a);
        int sB = score(b);
        if (sA != sB) return sA.compareTo(sB);
        
        if (sA == 2) {
          return b.fullDateTime.compareTo(a.fullDateTime);
        }
        return a.fullDateTime.compareTo(b.fullDateTime);
      });

      _appointments = appts;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ في جلب البيانات';
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _user = null;
    _appointments = [];
    _isLoading = true;
    _isFollowing = false;
    _isFriend = false;
    _error = null;
  }
}
