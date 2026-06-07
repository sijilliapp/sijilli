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
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sijilli/features/appointments/services/pb_invitation_service.dart';
import 'package:flutter/foundation.dart';

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
  final PbInvitationService _invitationService = PbInvitationService(); // Add this
  final LocalDbService _localDb = LocalDbService.instance;
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _users = [];
  List<UserModel> _followedUsers = [];
  List<Contact> _allContacts = []; // Cache for all phone contacts
  List<Contact> _filteredLocalContacts = []; // Contacts matching search
  Set<String> _conflictingUserIds = {};
  bool _isLoading = false;
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _checkAndLoadContacts(); // Try loading contacts in background
  }

  Future<void> _checkAndLoadContacts() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await FastContacts.getAllContacts();
      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _contactsLoaded = true;
        });
      }
    } catch (e) {
      print('⚠️ Failed to load contacts: $e');
    }
  }

  Future<void> _loadInitialData() async {
    final localFollowed = await _localDb.getFollowedUsers();
    
    // Filter out existing participants
    final participantsIds = widget.appointment.participants?.map((p) => p.userId).toSet() ?? {};
    final filteredFollowed = localFollowed.where((u) => !participantsIds.contains(u.id) && u.id != widget.appointment.hostId).toList();

    setState(() {
      _followedUsers = filteredFollowed;
      _users = filteredFollowed; 
    });

    try {
      final pb = PocketBaseClient.instance.pb;
      final remoteFollowed = pb.authStore.isValid 
          ? await _userService.getFollowedUsers() 
          : <UserModel>[];
      
      if (remoteFollowed.isNotEmpty && mounted) {
        await _localDb.saveFollowedUsers(remoteFollowed);
        
        final filteredRemote = remoteFollowed.where((u) => !participantsIds.contains(u.id) && u.id != widget.appointment.hostId).toList();
        
        if (_searchController.text.isEmpty) {
          setState(() {
            _followedUsers = filteredRemote;
            _users = filteredRemote;
          });
        } else {
          setState(() => _followedUsers = filteredRemote);
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

        final participantsIds = widget.appointment.participants?.map((p) => p.userId).toSet() ?? {};
        final invitedPhones = widget.appointment.participants
            ?.where((p) => p.invitedPhone != null)
            .map((p) => _normalizePhone(p.invitedPhone!))
            .toSet() ?? {};

        final filteredResults = results.where((user) {
          if (participantsIds.contains(user.id)) return false;
          if (user.id == widget.appointment.hostId) return false;
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

        // Unified search: Filter local contacts too
        List<Contact> localMatches = [];
        if (_contactsLoaded) {
          localMatches = _allContacts.where((contact) {
            // Filter out if already invited by phone
            bool alreadyInvited = contact.phones.any((p) => invitedPhones.contains(_normalizePhone(p.number)));
            if (alreadyInvited) return false;

            final q = ArabicSearch.normalize(query);
            final nameMatch = ArabicSearch.smartMatch(contact.displayName, query);
            final phoneMatch = contact.phones.any((p) => p.number.contains(query));
            final emailMatch = contact.emails.any((e) => ArabicSearch.normalize(e.address).contains(q));
            return nameMatch || phoneMatch || emailMatch;
          }).toList();
        }

        if (mounted) {
          setState(() {
            _users = filteredResults;
            _filteredLocalContacts = localMatches;
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

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  Future<void> _pickFromContacts() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الوصول لجهات الاتصال متاح فقط على الهواتف.')),
      );
      return;
    }
    
    final status = await Permission.contacts.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.dataError),
            content: const Text('يرجى تفعيل صلاحية الوصول لجهات الاتصال من إعدادات النظام لتتمكن من استخدام هذه الميزة.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.detailsUndo)),
              TextButton(onPressed: () => openAppSettings(), child: Text(context.l10n.settings)),
            ],
          ),
        );
      }
      return;
    }

    if (!status.isGranted) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      if (!_contactsLoaded) {
        await _loadContacts();
      }
      final contacts = _allContacts;
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد جهات اتصال متاحة.')));
        return;
      }

      final invitedPhones = widget.appointment.participants
            ?.where((p) => p.invitedPhone != null)
            .map((p) => _normalizePhone(p.invitedPhone!))
            .toSet() ?? {};

      // Show a picker dialog
      final selectedContact = await showModalBottomSheet<Contact>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (ctx) => _ContactPickerSheet(contacts: contacts, invitedPhones: invitedPhones),
      );

      if (selectedContact != null && selectedContact.phones.isNotEmpty) {
        final phone = selectedContact.phones.first.number;
        final name = selectedContact.displayName;

        if (mounted) {
          final phoneUser = UserModel(
            id: 'phone_$phone',
            username: name,
            email: '',
            name: name,
            phone: phone,
            created: DateTime.now(),
            updated: DateTime.now(),
            joiningDate: DateTime.now(),
          );
          Navigator.pop(context); // Close the invitee sheet
          widget.onUserSelected(phoneUser);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Contacts error: $e');
    }
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
          const SizedBox(height: 12),
          
          // Pick from Contacts Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickFromContacts,
              icon: const Icon(Icons.contacts, size: 18),
              label: const Text('دعوة من جهات الاتصال', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : (_users.isEmpty && _filteredLocalContacts.isEmpty)
                ? Center(
                    child: Text(
                      context.l10n.noResultsFound,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length + _filteredLocalContacts.length,
                    itemBuilder: (context, index) {
                      if (index < _users.length) {
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
                             if (!isFollowed && !isHost) {
                                 _userService.accreditUser(user.id).catchError((_) {});
                             }
                             widget.onUserSelected(user);
                          },
                        );
                      } else {
                        final contact = _filteredLocalContacts[index - _users.length];
                        return _ContactTile(
                          contact: contact,
                          onSelected: (phone, name) {
                            final phoneUser = UserModel(
                              id: 'phone_$phone',
                              username: name,
                              email: '',
                              name: name,
                              phone: phone,
                              created: DateTime.now(),
                              updated: DateTime.now(),
                              joiningDate: DateTime.now(),
                            );
                            Navigator.pop(context); // Close sheet
                            widget.onUserSelected(phoneUser);
                          },
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final Function(String phone, String name) onSelected;

  const _ContactTile({required this.contact, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'لا يوجد رقم';
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.person, color: Colors.grey),
      ),
      title: Text(
        contact.displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: TextButton(
        onPressed: contact.phones.isNotEmpty 
            ? () => onSelected(phone, contact.displayName)
            : null,
        child: const Text('استضافة ضيف'),
      ),
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;
  final Set<String> invitedPhones;

  const _ContactPickerSheet({required this.contacts, required this.invitedPhones});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  late List<Contact> _filteredContacts;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts.where((c) {
      if (c.phones.isEmpty) return false;
      final normalized = _normalizePhone(c.phones.first.number);
      return !widget.invitedPhones.contains(normalized);
    }).toList();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = widget.contacts.where((c) {
        if (c.phones.isEmpty) return false;
        
        final normalized = _normalizePhone(c.phones.first.number);
        if (widget.invitedPhones.contains(normalized)) return false;

        final q = ArabicSearch.normalize(query);
        final nameMatch = ArabicSearch.smartMatch(c.displayName, query);
        final phoneMatch = c.phones.any((p) => p.number.contains(query));
        final emailMatch = c.emails.any((e) => ArabicSearch.normalize(e.address).contains(q));
        return nameMatch || phoneMatch || emailMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('اختر جهة اتصال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: 'بحث في جهات الاتصال (اسم، رقم، بريد)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredContacts.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
              itemBuilder: (ctx, index) {
                final c = _filteredContacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(c.displayName.isNotEmpty ? c.displayName[0] : '?', style: const TextStyle(color: AppColors.primary)),
                  ),
                  title: Text(c.displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.phones.first.number),
                      if (c.emails.isNotEmpty) 
                        Text(c.emails.first.address, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  onTap: () => Navigator.pop(ctx, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
