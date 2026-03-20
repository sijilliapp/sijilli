import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/user.dart';
import '../../../settings/services/pb_user_service.dart';
import '../../../appointments/services/pb_appointment_service.dart';
import '../../../../core/local/local_db_service.dart';
import '../../../../core/services/pocketbase_client.dart';
import '../../../../models/appointment.dart';
import '../../../../core/utils/arabic_search.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class UserInviteeSheet extends StatefulWidget {
  final Appointment appointment;
  final Function(UserModel) onUserSelected;

  const UserInviteeSheet({
    super.key, 
    required this.appointment,
    required this.onUserSelected
  });

  @override
  State<UserInviteeSheet> createState() => _UserInviteeSheetState();
}

class _UserInviteeSheetState extends State<UserInviteeSheet> {
  final PbUserService _userService = PbUserService();
  final PbAppointmentService _appointmentService = PbAppointmentService();
  final LocalDbService _localDb = LocalDbService.instance;
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _users = [];
  List<UserModel> _followedUsers = [];
  Set<String> _conflictingUserIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final localFollowed = await _localDb.getFollowedUsers();
    setState(() {
      _followedUsers = localFollowed;
      _users = localFollowed; 
    });

    try {
      final pb = PocketBaseClient.instance.pb;
      final remoteFollowed = pb.authStore.isValid 
          ? await _userService.getFollowedUsers() 
          : <UserModel>[];
      
      if (remoteFollowed.isNotEmpty && mounted) {
        await _localDb.saveFollowedUsers(remoteFollowed);
        if (_searchController.text.isEmpty) {
          setState(() {
            _followedUsers = remoteFollowed;
            _users = remoteFollowed;
          });
        } else {
          setState(() => _followedUsers = remoteFollowed);
        }
      }
      
      if (_users.isNotEmpty && mounted) {
        _checkConflicts(_users);
      }
    } catch (e) {
      print('⚠️ Initial data load error: $e');
    }
  }

  Future<void> _checkConflicts(List<UserModel> users) async {
    final userIds = users.map((u) => u.id).toList();
    final conflicts = await _appointmentService.getConflictingUserIds(
      userIds, 
      widget.appointment.startAt, 
      widget.appointment.duration
    );
    if (mounted) {
      setState(() => _conflictingUserIds = conflicts);
    }
  }

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _users = _followedUsers; 
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) setState(() => _isLoading = true);
      
      try {
        final results = await _userService.searchUsers(query);
        
        if (!mounted) return;

        final filteredResults = results.where((user) {
          return ArabicSearch.smartMatch(user.name ?? '', query) || 
                 ArabicSearch.smartMatch(user.username, query);
        }).toList();

        final followedIds = _followedUsers.map((u) => u.id).toSet();
        filteredResults.sort((a, b) {
          final aFollowed = followedIds.contains(a.id);
          final bFollowed = followedIds.contains(b.id);
          if (aFollowed && !bFollowed) return -1;
          if (!aFollowed && bFollowed) return 1;
          return 0;
        });

        if (mounted) {
           await _checkConflicts(filteredResults);
        }

        if (mounted) {
          setState(() {
            _users = filteredResults;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        print('Search error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            context.l10n.hostAFriend,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: context.l10n.searchUserHint,
              hintStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.noResultsFound,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final bool hasConflict = _conflictingUserIds.contains(user.id);
                      final bool isHost = user.id == widget.appointment.hostId;
                      final bool isFollowed = _followedUsers.any((u) => u.id == user.id);

                      return UserCard(
                        user: user,
                        mode: UserCardMode.selection,
                        hasConflict: hasConflict,
                        isHost: isHost,
                        isFollowed: isFollowed,
                        onSelected: () {
                           // Dual-action: Host AND Connect (Accredit) if not followed
                           if (!isFollowed && !isHost) {
                               _userService.accreditUser(user.id).catchError((_) {});
                           }
                           widget.onUserSelected(user);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
