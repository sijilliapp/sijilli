import 'package:flutter/material.dart';
import '../../../models/appointment.dart';
import '../../../models/user.dart';
import '../../appointments/services/pb_appointment_browse_service.dart';
import '../../settings/services/pb_user_service.dart';
import '../../profile/providers/moderation_provider.dart';
import '../../../core/providers/global_config_provider.dart';

enum SearchTab { news, follows }

class SearchProvider extends ChangeNotifier {
  final PbAppointmentBrowseService _appointmentService = PbAppointmentBrowseService();
  final PbUserService _userService = PbUserService();

  // --- State ---
  SearchTab _selectedTab = SearchTab.news;
  String _query = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreUsers = false;
  static const int _perPage = 10;
  UserModel? _currentUser;
  ModerationProvider? _moderation;
  GlobalConfigProvider? _config;

  List<Appointment> _exploreAppointments = [];
  List<Appointment> _followedAppointments = [];
  List<UserModel> _userSearchResults = [];
  Map<String, Map<String, dynamic>> _userStatuses = {};

  // --- Getters ---
  SearchTab get selectedTab => _selectedTab;
  String get query => _query;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreUsers => _hasMoreUsers;
  bool get isSearching => _query.trim().isNotEmpty;

  List<Appointment> get exploreAppointments {
    if (_moderation == null) return _exploreAppointments;
    return _exploreAppointments.where((a) => !_moderation!.isUserBlocked(a.hostId)).toList();
  }

  List<Appointment> get followedAppointments {
    if (_moderation == null) return _followedAppointments;
    return _followedAppointments.where((a) => !_moderation!.isUserBlocked(a.hostId)).toList();
  }

  List<UserModel> get userSearchResults {
    if (_moderation == null) return _userSearchResults;
    
    final filtered = _userSearchResults.where((u) {
      final blockedByMe = _moderation!.blockedUserIds.contains(u.id);
      final blockingMe = _moderation!.idsBlockingMe.contains(u.id);
      final isSelf = u.id == _currentUser?.id;
      
      if (blockedByMe) debugPrint('🚫 [SearchFilter] Excluding ${u.name} because YOU blocked them');
      if (blockingMe) debugPrint('⛔ [SearchFilter] Excluding ${u.name} because they blocked YOU');
      if (isSelf) debugPrint('👤 [SearchFilter] Excluding ${u.name} because it is YOU');
      
      return !blockedByMe && !blockingMe && !isSelf;
    }).toList();
    
    return filtered;
  }

  Map<String, dynamic>? getUserStatus(String userId) {
    return _userStatuses[userId];
  }

  // --- Actions ---

  void setTab(SearchTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    _fetchDefaultContent();
    notifyListeners();
  }

  void updateQuery(String newQuery) {
    if (_query == newQuery && _userSearchResults.isNotEmpty) return;
    _query = newQuery;
    debugPrint('🔎 [SearchProvider] Manual Search Submitted: "$_query"');

    if (_query.trim().isEmpty) {
      clearSearch();
    } else {
      _currentPage = 1;
      _userSearchResults = [];
      _userStatuses = {};
      _performSearch(_query);
    }
  }

  void clearSearch() {
    _query = '';
    _userSearchResults = [];
    _userStatuses = {};
    _currentPage = 1;
    _hasMoreUsers = false;
    _fetchDefaultContent();
    notifyListeners();
  }

  Future<void> searchMore() async {
    if (_isLoading || _isLoadingMore || !_hasMoreUsers) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      _currentPage++;
      final moreUsers = await _userService.searchUsers(_query, page: _currentPage, perPage: _perPage);
      
      if (moreUsers.isNotEmpty) {
        _userSearchResults.addAll(moreUsers);
        _hasMoreUsers = moreUsers.length == _perPage;
        
        // Fetch statuses for new users
        final currentUserId = _currentUser?.id;
        if (currentUserId != null) {
          final friendships = await _userService.fetchFriendships(moreUsers.map((u) => u.id).toList());
          for (var record in friendships) {
            final isUserA = record.getStringValue('user_a') == currentUserId;
            final targetId = record.getStringValue(isUserA ? 'user_b' : 'user_a');
            final myStatus = record.getStringValue(isUserA ? 'a_status' : 'b_status');
            final theirStatus = record.getStringValue(isUserA ? 'b_status' : 'a_status');
            _userStatuses[targetId] = {
              'status': myStatus,
              'isFriend': myStatus == 'accepted' && theirStatus == 'accepted',
              'isBeingFollowed': theirStatus == 'accepted' || theirStatus == 'pending',
              'isBlocked': myStatus == 'blocked',
              'isBlockingMe': theirStatus == 'blocked',
            };
          }
        }
      } else {
        _hasMoreUsers = false;
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _fetchDefaultContent();
  }

  Future<void> _fetchDefaultContent() async {
    if (isSearching) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      if (_selectedTab == SearchTab.news) {
        _exploreAppointments = await _appointmentService.getExploreAppointments(
          userRegion: _currentUser?.region,
          contextAdjustment: (_currentUser?.hijriAdjustment ?? 0).toInt(),
        );
      } else {
        _followedAppointments = await _appointmentService.getFollowedAppointments();
      }
    } catch (e) {
      debugPrint('Error fetching default content: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _performSearch(String query) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userSearchResults = await _userService.searchUsers(query, page: _currentPage, perPage: _perPage);
      _hasMoreUsers = _userSearchResults.length == _perPage;
      
      // جلب حالات الاعتماد بالجملة للنتائج
      if (_userSearchResults.isNotEmpty) {
        final currentUserId = _currentUser?.id;
        if (currentUserId != null) {
          final friendships = await _userService.fetchFriendships(_userSearchResults.map((u) => u.id).toList());
          final Map<String, Map<String, dynamic>> statusMap = {};
          
          for (var record in friendships) {
            final isUserA = record.getStringValue('user_a') == currentUserId;
            final targetId = record.getStringValue(isUserA ? 'user_b' : 'user_a');
            
            final myStatus = record.getStringValue(isUserA ? 'a_status' : 'b_status');
            final theirStatus = record.getStringValue(isUserA ? 'b_status' : 'a_status');
            
            statusMap[targetId] = {
              'status': myStatus,
              'isFriend': myStatus == 'accepted' && theirStatus == 'accepted',
              'isBeingFollowed': theirStatus == 'accepted' || theirStatus == 'pending',
              'isBlocked': myStatus == 'blocked',
              'isBlockingMe': theirStatus == 'blocked',
            };
          }
          _userStatuses = statusMap;
        }
      }
      
      if (_userSearchResults.isEmpty) {
        debugPrint('ℹ️ [SearchProvider] No results returned from server for "$query"');
      } else {
        final finalCount = userSearchResults.length;
        debugPrint('✅ [SearchProvider] Found ${_userSearchResults.length} users, showing $finalCount (after filtering)');
      }
    } catch (e) {
      debugPrint('Error performing search: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void update(UserModel? user, ModerationProvider? moderation, GlobalConfigProvider? config) {
    bool userChanged = _currentUser?.id != user?.id || _currentUser?.region != user?.region;
    
    _currentUser = user;
    _moderation = moderation;
    _config = config;
    
    if (user == null) {
      _exploreAppointments = [];
      _followedAppointments = [];
      _userSearchResults = [];
      _userStatuses = {};
      _query = '';
      _currentPage = 1;
      _hasMoreUsers = false;
      notifyListeners();
    } else if (userChanged) {
      debugPrint('🔄 [SearchProvider] User context changed, refreshing content...');
      _fetchDefaultContent();
    }
  }

  Future<void> init() async {
    await _fetchDefaultContent();
  }
}
