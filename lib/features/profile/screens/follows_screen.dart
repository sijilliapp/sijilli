import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/features/settings/services/pb_user_service.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card.dart';
import 'package:sijilli/features/profile/widgets/user_follow_button.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/core/services/pocketbase_client.dart';
import 'package:sijilli/features/home/screens/public_profile_screen.dart';
import 'package:sijilli/core/local/local_db_service.dart';

class FollowsScreen extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const FollowsScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  State<FollowsScreen> createState() => _FollowsScreenState();
}

class UserRequest {
  final UserModel user;
  final String requestId;
  UserRequest(this.user, this.requestId);
}

class _FollowsScreenState extends State<FollowsScreen> {
  final PbUserService _userService = PbUserService();

  List<UserModel> _accredited = [];
  List<UserRequest> _incomingRequests = [];
  List<UserRequest> _outgoingRequests = [];
  List<UserModel> _unansweredFollowers = [];
  List<UserModel> _recentSearches = [];
  List<UserModel> _filteredAccredited = [];
  List<UserRequest> _filteredIncoming = [];
  List<UserRequest> _filteredOutgoing = [];
  List<UserModel> _suggestedUsers = [];
  final Set<String> _dismissedSuggestedIds = {};
  
  bool _isLoading = true;
  bool _isCurrentUser = false;
  bool _isSearchActive = false;
  bool _showAllAccredited = false;
  final TextEditingController _searchController = TextEditingController();

  UnsubscribeFunc? _unsubscribeFunc;

  Future<void> _loadLocalAccredited() async {
    try {
      final cached = await LocalDbService.instance.getFollowedUsers();
      final cachedRequests = await LocalDbService.instance.getPendingRequests();
      final cachedSuggestions = await LocalDbService.instance.getSuggestedUsers();
      final lastVisits = await LocalDbService.instance.getUserLastVisits();
      
      final List<UserRequest> cachedIncoming = [];
      for (var item in cachedRequests['incoming'] ?? []) {
        if (item['user'] != null) {
          cachedIncoming.add(UserRequest(
            UserModel.fromJson(Map<String, dynamic>.from(item['user'] as Map)),
            item['friendshipId'] as String? ?? '',
          ));
        }
      }

      final List<UserRequest> cachedOutgoing = [];
      for (var item in cachedRequests['outgoing'] ?? []) {
        if (item['user'] != null) {
          cachedOutgoing.add(UserRequest(
            UserModel.fromJson(Map<String, dynamic>.from(item['user'] as Map)),
            item['friendshipId'] as String? ?? '',
          ));
        }
      }

      final List<UserModel> cachedSuggested = [];
      for (var item in cachedSuggestions) {
        cachedSuggested.add(UserModel.fromJson(item));
      }

      if (cached.isNotEmpty) {
        cached.sort((a, b) {
          final aTime = lastVisits[a.id] ?? 0;
          final bTime = lastVisits[b.id] ?? 0;
          
          if (aTime != bTime) {
            return bTime.compareTo(aTime);
          }
          
          final aApproved = a.isApproved || a.isAdmin;
          final bApproved = b.isApproved || b.isAdmin;
          if (aApproved && !bApproved) return -1;
          if (!aApproved && bApproved) return 1;
          
          return a.name.compareTo(b.name);
        });
      }

      if (mounted) {
        setState(() {
          _accredited = cached;
          _incomingRequests = cachedIncoming;
          _outgoingRequests = cachedOutgoing;
          _suggestedUsers = cachedSuggested;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading local accredited users and requests: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _isCurrentUser = widget.userId == authProvider.user?.id;
    if (_isCurrentUser) {
      _loadLocalAccredited();
      _subscribeToRealtime();
    }
    _fetchAll();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final recent = await LocalDbService.instance.getRecentSearches();
    if (mounted) setState(() => _recentSearches = recent);
  }

  Future<void> _saveRecentSearch(UserModel user) async {
    await LocalDbService.instance.saveRecentSearch(user);
    _loadRecentSearches();
  }

  Future<void> _subscribeToRealtime() async {
    try {
      final pb = PocketBaseClient.instance.pb;
      _unsubscribeFunc = await pb.collection('friendship').subscribe('*', (e) {
        final record = e.record;
        if (record != null) {
          final userA = record.getStringValue('user_a');
          final userB = record.getStringValue('user_b');
          if (userA == widget.userId || userB == widget.userId) {
            _fetchAll(silent: true);
          }
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to friendship realtime: $e');
    }
  }

  Future<void> _fetchAll({bool silent = false}) async {
    final bool useSilent = silent || (_isCurrentUser && _accredited.isNotEmpty);
    if (!useSilent) setState(() => _isLoading = true);
    if (mounted) {
      setState(() {
        _showAllAccredited = false;
      });
    }
    try {
      final pb = PocketBaseClient.instance.pb;
      
      final allFriendships = await pb.collection('friendship').getFullList(
        filter: 'user_a = "${widget.userId}" || user_b = "${widget.userId}"',
        expand: 'user_a,user_b',
      );

      final accreditedList = <UserModel>[];
      final incomingList = <UserRequest>[];
      final outgoingList = <UserRequest>[];

      for (var record in allFriendships) {
        final userAId = record.getStringValue('user_a');
        final isUserA = userAId == widget.userId;
        
        final myStatus = record.getStringValue(isUserA ? 'a_status' : 'b_status');
        final theirStatus = record.getStringValue(isUserA ? 'b_status' : 'a_status');
        
        if (myStatus == 'blocked' || theirStatus == 'blocked') continue;

        final targetUserJson = record.expand[isUserA ? 'user_b' : 'user_a']?.first.toJson();
        if (targetUserJson == null) continue;
        final targetUser = UserModel.fromJson(targetUserJson);

        if (myStatus == 'accepted' && theirStatus == 'accepted') {
          accreditedList.add(targetUser);
        } else if (theirStatus == 'pending' || theirStatus == 'accepted') {
          // طلبات واردة: الطرف الآخر طلب التواصل أو يتابعني بالفعل
          incomingList.add(UserRequest(targetUser, record.id));
        } else if (myStatus == 'pending' || myStatus == 'accepted') {
          // طلبات صادرة: أنا طلبت التواصل أو أتابعهم
          outgoingList.add(UserRequest(targetUser, record.id));
        }
      }

      // جلب تواريخ آخر زيارة للملفات الشخصية لترتيب المعتمدين
      final lastVisits = await LocalDbService.instance.getUserLastVisits();
      
      // ترتيب المعتمدين: الأحدث زيارة أولاً، ثم المعتمدين/المشرفين أولاً، ثم الترتيب الأبجدي
      accreditedList.sort((a, b) {
        final aTime = lastVisits[a.id] ?? 0;
        final bTime = lastVisits[b.id] ?? 0;
        
        if (aTime != bTime) {
          return bTime.compareTo(aTime); // تنازلي (الأحدث زيارة أولاً)
        }
        
        final aApproved = a.isApproved || a.isAdmin;
        final bApproved = b.isApproved || b.isAdmin;
        
        if (aApproved && !bApproved) return -1;
        if (!aApproved && bApproved) return 1;
        
        return a.name.compareTo(b.name);
      });

      // جلب الحسابات المقترحة المعلمة كاقتراح (is_suggested = true)
      List<UserModel> suggestions = [];
      try {
        final currentUserId = pb.authStore.record?.id;
        if (currentUserId != null) {
          final records = await pb.collection('users').getFullList(
            filter: 'is_suggested = true && id != "$currentUserId"',
          );
          final allApproved = records.map((r) => UserModel.fromJson(r.toJson())).toList();

          // تحميل المعرفات المحذوفة محلياً من قاعدة البيانات Hive لضمان استمراريتها
          final localDismissed = await LocalDbService.instance.getDismissedSuggestionIds();
          _dismissedSuggestedIds.addAll(localDismissed);

          // فلترة المعتمدين والطلبات الحالية لمنع تكرارهم في الاقتراحات
          final existingIds = <String>{};
          for (var u in accreditedList) {
            existingIds.add(u.id);
          }
          for (var r in incomingList) {
            existingIds.add(r.user.id);
          }
          for (var r in outgoingList) {
            existingIds.add(r.user.id);
          }

          suggestions = allApproved.where((u) => !existingIds.contains(u.id) && !_dismissedSuggestedIds.contains(u.id)).toList();
        }
      } catch (e) {
        debugPrint('Error fetching suggested users: $e');
      }

      if (mounted) {
        setState(() {
          _accredited = accreditedList;
          _incomingRequests = incomingList;
          _outgoingRequests = outgoingList;
          _suggestedUsers = suggestions;
          _isLoading = false;
        });

        // 💾 Save to local DB cache for next launches
        if (_isCurrentUser) {
          LocalDbService.instance.saveFollowedUsers(accreditedList);
          
          final incomingJson = incomingList.map((r) => {
            'friendshipId': r.requestId,
            'user': r.user.toJson(),
          }).toList();

          final outgoingJson = outgoingList.map((r) => {
            'friendshipId': r.requestId,
            'user': r.user.toJson(),
          }).toList();

          LocalDbService.instance.savePendingRequests(
            incoming: incomingJson,
            outgoing: outgoingJson,
          );

          final suggestionsJson = suggestions.map((u) => u.toJson()).toList();
          LocalDbService.instance.saveSuggestedUsers(suggestionsJson);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _filteredAccredited = [];
        _filteredIncoming = [];
        _filteredOutgoing = [];
      });
      return;
    }
    
    setState(() {
      _filteredAccredited = _accredited.where((u) {
        final name = u.name.toLowerCase();
        final username = u.username.toLowerCase();
        return name.contains(q) || username.contains(q);
      }).toList();

      _filteredIncoming = _incomingRequests.where((r) {
        final name = r.user.name.toLowerCase();
        final username = r.user.username.toLowerCase();
        return name.contains(q) || username.contains(q);
      }).toList();

      _filteredOutgoing = _outgoingRequests.where((r) {
        final name = r.user.name.toLowerCase();
        final username = r.user.username.toLowerCase();
        return name.contains(q) || username.contains(q);
      }).toList();
    });
  }

  Future<void> _respondToRequest(String requestId, bool accept) async {
    try {
      if (accept) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.accreditEntity),
            content: Text(
              context.l10n.accreditDesc,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.close)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.confirm)),
            ],
          ),
        );
        if (confirm != true) return;
      }

      // Optimistic Update
      setState(() {
        _incomingRequests.removeWhere((r) => r.requestId == requestId);
      });

      await _userService.respondToFollowRequest(requestId, accept);
      _fetchAll(silent: true);
    } catch (e) {
      if (mounted) {
        _fetchAll(silent: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorProcessingRequest)),
        );
      }
    }
  }

  Future<void> _cancelRequest(String targetUserId) async {
    try {
       final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.withdrawRequest),
            content: Text(context.l10n.withdrawDesc),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.keepRequest)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.yes)),
            ],
          ),
        );
        if (confirm != true) return;

      setState(() {
        _outgoingRequests.removeWhere((r) => r.user.id == targetUserId);
      });

      await _userService.unfollowUser(targetUserId);
      _fetchAll(silent: true);
    } catch (e) {
      if (mounted) _fetchAll(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearchActive 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.searchUsers,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: _onSearchChanged,
            )
          : Text(context.l10n.accreditations),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.primary,
        elevation: 0,
        centerTitle: !_isSearchActive,
        actions: [
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearchActive) {
                  _searchController.clear();
                  _filteredAccredited = [];
                  _filteredIncoming = [];
                  _filteredOutgoing = [];
                }
                _isSearchActive = !_isSearchActive;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAll,
              child: _isSearchActive ? _buildSearchResults() : _buildMainList(),
            ),
    );
  }

  Widget _buildSearchResults() {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      if (_recentSearches.isEmpty) {
        return Center(child: Text(context.l10n.searchUsers));
      }
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(context.l10n.recentSearches, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._recentSearches.map((u) => _buildUserSearchCard(u)),
        ],
      );
    }

    if (_filteredAccredited.isEmpty && _filteredIncoming.isEmpty && _filteredOutgoing.isEmpty) {
      return Center(child: Text(context.l10n.noResults));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_filteredIncoming.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(context.l10n.waitingYourAccreditation, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._filteredIncoming.map((r) => _buildIncomingSearchCard(r)),
        ],
        if (_filteredAccredited.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(context.l10n.accreditedEntities, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._filteredAccredited.map((u) => _buildUserSearchCard(u)),
        ],
        if (_filteredOutgoing.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(context.l10n.waitingTheirAccreditation, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._filteredOutgoing.map((r) => _buildOutgoingSearchCard(r)),
        ],
      ],
    );
  }

  Widget _buildIncomingSearchCard(UserRequest request) {
    return UserCard(
      user: request.user,
      mode: UserCardMode.followList,
      actionWidget: ElevatedButton(
        onPressed: () => _respondToRequest(request.requestId, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(80, 32),
        ),
        child: Text(context.l10n.accreditAction),
      ),
    );
  }

  Widget _buildOutgoingSearchCard(UserRequest request) {
    return UserCard(
      user: request.user,
      mode: UserCardMode.followList,
      actionWidget: OutlinedButton(
        onPressed: () => _cancelRequest(request.user.id),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(80, 32),
        ),
        child: Text(context.l10n.waitingAction),
      ),
    );
  }

  Widget _buildUserSearchCard(UserModel user) {
    return UserCard(
      user: user,
      mode: UserCardMode.followList,
      onTap: () {
        _saveRecentSearch(user);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PublicProfileScreen(usernameOrId: user.id)),
        );
      },
    );
  }

  Widget _buildMainList() {
    final bool isEmpty = _incomingRequests.isEmpty && _outgoingRequests.isEmpty && _accredited.isEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_incomingRequests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(context.l10n.waitingYourAccreditation, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._buildIncomingItems(),
        ],
        if (_accredited.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(context.l10n.accreditedEntities, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          if (_accredited.length <= 15 || _showAllAccredited) ...[
            ..._buildAccreditedItems(),
          ] else ...[
            ..._buildAccreditedItems().take(15),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllAccredited = true;
                  });
                },
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text(
                  context.l10n.localeName == 'ar' ? 'المزيد..' : 'more..',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
        if (_outgoingRequests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(context.l10n.waitingTheirAccreditation, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._buildOutgoingItems(),
        ],

        if (isEmpty) ...[
          const SizedBox(height: 48),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.people_outline_rounded,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.localeName == 'ar'
                      ? 'لا يوجد جهات اتصال معتمدة لديك.'
                      : 'You have no accredited contacts.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // تباعد يعادل نصف الصفحة لوضع قسم الاقتراحات في النصف السفلي
          const SizedBox(height: 140),
        ] else ...[
          // إذا لم تكن القائمة فارغة، نضع فاصلاً لطيفاً قبل قسم الاقتراحات
          if (_suggestedUsers.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.3), indent: 16, endIndent: 16),
            const SizedBox(height: 16),
          ],
        ],

        if (_suggestedUsers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.localeName == 'ar' ? 'حسابات مقترحة لك..' : 'Suggested accounts for you..',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
          ),
          ..._buildSuggestedItems(),
        ],
      ],
    );
  }

  List<Widget> _buildSuggestedItems() {
    return _suggestedUsers.map((user) {
      bool isAccrediting = false;
      return StatefulBuilder(
        builder: (context, setCardState) {
          return UserCard(
            user: user,
            mode: UserCardMode.followList,
            actionWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                isAccrediting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          setCardState(() {
                            isAccrediting = true;
                          });
                          try {
                            await _userService.accreditUser(user.id, isSuggested: true);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم اعتماد الحساب بنجاح! 🎉'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _fetchAll(silent: true);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('فشل الاعتماد: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setCardState(() {
                                isAccrediting = false;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(80, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(context.l10n.localeName == 'ar' ? 'اعتماد' : 'Accredit'),
                      ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () async {
                    setState(() {
                      _dismissedSuggestedIds.add(user.id);
                      _suggestedUsers.removeWhere((u) => u.id == user.id);
                    });
                    // حفظ عملية الحذف محلياً في Hive لكي لا يتم عرض هذا الحساب مجدداً نهائياً
                    await LocalDbService.instance.saveDismissedSuggestionId(user.id);
                  },
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildIncomingItems() {
    return _incomingRequests.map((request) {
      return UserCard(
        user: request.user,
        mode: UserCardMode.followList,
        actionWidget: ElevatedButton(
          onPressed: () => _respondToRequest(request.requestId, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(80, 32),
          ),
          child: Text(context.l10n.accreditAction),
        ),
      );
    }).toList();
  }

  List<Widget> _buildOutgoingItems() {
    return _outgoingRequests.map((request) {
      return UserCard(
        user: request.user,
        mode: UserCardMode.followList,
        actionWidget: OutlinedButton(
          onPressed: () => _cancelRequest(request.user.id),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(80, 32),
          ),
          child: Text(context.l10n.waitingAction),
        ),
      );
    }).toList();
  }

  List<Widget> _buildAccreditedItems() {
    return _accredited.map((user) {
      return UserCard(
        user: user,
        mode: UserCardMode.followList,
        actionWidget: UserFollowButton(
          userId: user.id,
          isCompact: true,
          initialStatusData: const {
            'status': 'accepted',
            'isFriend': true,
            'isBeingFollowed': true,
          },
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _unsubscribeFunc?.call();
    super.dispose();
  }
}
