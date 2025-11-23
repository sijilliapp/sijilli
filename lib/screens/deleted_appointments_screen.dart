import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_appointment_status_service.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/user_appointment_status_model.dart';
import '../models/invitation_model.dart';
import '../config/constants.dart';
import '../widgets/appointment_card.dart';
import 'appointment_details_screen.dart';

class DeletedAppointmentsScreen extends StatefulWidget {
  const DeletedAppointmentsScreen({super.key});

  @override
  State<DeletedAppointmentsScreen> createState() => _DeletedAppointmentsScreenState();
}

class _DeletedAppointmentsScreenState extends State<DeletedAppointmentsScreen> {
  final AuthService _authService = AuthService();
  late final UserAppointmentStatusService _statusService;

  List<AppointmentModel> _deletedAppointments = [];
  Map<String, UserModel> _appointmentHosts = {};
  Map<String, List<UserModel>> _appointmentGuests = {};
  Map<String, List<InvitationModel>> _appointmentInvitations = {};
  Map<String, Map<String, UserAppointmentStatusModel>> _appointmentParticipantsStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _statusService = UserAppointmentStatusService(_authService);
    _loadDeletedAppointments();
  }

  Future<void> _loadDeletedAppointments() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // جلب المواعيد المحذوفة
      final deletedIds = await _statusService.getDeletedAppointmentIdsForCurrentUser();

      if (deletedIds.isEmpty) {
        if (mounted) {
          setState(() {
            _deletedAppointments = [];
            _isLoading = false;
          });
        }
        return;
      }

      final appointmentFilter = deletedIds.map((id) => 'id = "$id"').join(' || ');
      final deletedRecords = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(filter: '($appointmentFilter)');

      final deleted = deletedRecords
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();

      // جلب معلومات المنشئين فقط (بدون ضيوف أو دعوات - غير ضرورية في المحذوفات)
      final uniqueHostIds = deleted.map((a) => a.hostId).toSet().toList();
      if (uniqueHostIds.isNotEmpty) {
        final hostFilter = uniqueHostIds.map((id) => 'id = "$id"').join(' || ');
        final hostRecords = await _authService.pb
            .collection(AppConstants.usersCollection)
            .getFullList(filter: '($hostFilter)');
        
        for (final record in hostRecords) {
          final host = UserModel.fromJson(record.toJson());
          // ربط المنشئ بجميع مواعيده
          for (final appointment in deleted) {
            if (appointment.hostId == host.id) {
              _appointmentHosts[appointment.id] = host;
            }
          }
        }
      }
      
      // جلب حالة المستخدم الحالي فقط لكل موعد
      for (final appointment in deleted) {
        try {
          final userStatus = await _statusService.getUserAppointmentStatus(
            userId: currentUserId,
            appointmentId: appointment.id,
          );
          if (userStatus != null) {
            _appointmentParticipantsStatus[appointment.id] = {
              currentUserId: userStatus,
              if (currentUserId == appointment.hostId) appointment.hostId: userStatus,
            };
          }
        } catch (e) {
          print('⚠️ خطأ في جلب حالة المستخدم للموعد ${appointment.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _deletedAppointments = deleted;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل المحذوفات: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAllPermanently() async {
    // إظهار حوار التأكيد
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تحذير'),
        content: const Text(
          'هل أنت متأكد من حذف جميع المواعيد نهائياً؟\n\nهذا الإجراء لا يمكن التراجع عنه!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // حذف جميع السجلات من user_appointment_status
      final statusRecords = await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .getFullList(
        filter: 'user = "$currentUserId" && status = "deleted"',
      );

      for (final record in statusRecords) {
        await _authService.pb
            .collection(AppConstants.userAppointmentStatusCollection)
            .delete(record.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف جميع المواعيد نهائياً'),
            backgroundColor: Colors.green,
          ),
        );

        // إعادة تحميل القائمة
        _loadDeletedAppointments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في الحذف: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'المحذوفات',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_deletedAppointments.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _deleteAllPermanently,
              tooltip: 'حذف الكل نهائياً',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deletedAppointments.isEmpty
              ? _buildEmptyState()
              : _buildDeletedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مواعيد محذوفة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'المواعيد المحذوفة ستظهر هنا',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedAppointments.length,
      itemBuilder: (context, index) {
        final appointment = _deletedAppointments[index];
        final host = _appointmentHosts[appointment.id];
        final guests = _appointmentGuests[appointment.id] ?? [];
        final invitations = _appointmentInvitations[appointment.id] ?? [];
        final participantsStatus = _appointmentParticipantsStatus[appointment.id];
        
        return AppointmentCard(
          appointment: appointment,
          host: host,
          guests: guests,
          invitations: invitations,
          participantsStatus: participantsStatus,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentDetailsScreen(
                  appointment: appointment,
                  guests: guests,
                  invitations: invitations,
                  host: host,
                  participantsStatus: participantsStatus,
                  isFromArchive: false,
                ),
              ),
            ).then((_) => _loadDeletedAppointments());
          },
        );
      },
    );
  }
}
