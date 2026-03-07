import 'package:flutter/material.dart';
import '../../../models/appointment.dart';
import '../../../models/user.dart';
import '../../appointments/services/pb_appointment_browse_service.dart';
import '../../settings/services/pb_user_service.dart';

enum SearchTab { news, follows }

class SearchProvider extends ChangeNotifier {
  final PbAppointmentBrowseService _appointmentService = PbAppointmentBrowseService();
  final PbUserService _userService = PbUserService();

  // --- State ---
  SearchTab _selectedTab = SearchTab.news;
  String _query = '';
  bool _isLoading = false;

  List<Appointment> _exploreAppointments = [];
  List<Appointment> _followedAppointments = [];
  List<UserModel> _userSearchResults = [];

  // --- Getters ---
  SearchTab get selectedTab => _selectedTab;
  String get query => _query;
  bool get isLoading => _isLoading;
  bool get isSearching => _query.trim().isNotEmpty;

  List<Appointment> get exploreAppointments => _exploreAppointments;
  List<Appointment> get followedAppointments => _followedAppointments;
  List<UserModel> get userSearchResults => _userSearchResults;

  // --- Actions ---

  void setTab(SearchTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    notifyListeners();
    _fetchDefaultContent();
  }

  void updateQuery(String newQuery) {
    _query = newQuery;
    if (_query.trim().isEmpty) {
      _userSearchResults = [];
      _fetchDefaultContent();
    } else {
      _performSearch(_query);
    }
    notifyListeners();
  }

  Future<void> init() async {
    await _fetchDefaultContent();
  }

  Future<void> refresh() async {
    await _fetchDefaultContent();
  }

  // --- Private Helpers ---

  Future<void> _fetchDefaultContent() async {
    if (isSearching) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      if (_selectedTab == SearchTab.news) {
        _exploreAppointments = await _appointmentService.getExploreAppointments();
      } else {
        _followedAppointments = await _appointmentService.getFollowedAppointments();
      }
    } catch (e) {
      debugPrint('Error fetching search tab content: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _performSearch(String query) async {
    _isLoading = true;
    notifyListeners();

    try {
      // For now, search focuses on users, but can be expanded to appointments
      _userSearchResults = await _userService.searchUsers(query);
    } catch (e) {
      debugPrint('Error performing search: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
