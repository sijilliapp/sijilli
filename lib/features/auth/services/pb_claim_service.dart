import '../../../core/services/pocketbase_client.dart';
import '../../appointments/services/pb_invitation_service.dart';

class PbClaimService {
  final _pb = PocketBaseClient.instance.pb;
  final _invitationService = PbInvitationService();

  /// Claims all pending invitations for the current user based on their verified phone number.
  /// This should be called after a user is verified (is_verified = true).
  Future<void> claimInvitationsByPhone(String userId, String phone) async {
    if (phone.isEmpty) return;

    try {
      // 1. Find all invitations where invited_phone equals the user's phone and user is null
      // We search for invitations where 'user' is empty and 'invited_phone' matches.
      // Note: We might need to normalize the phone number for matching.
      final normalizedPhone = _normalizePhone(phone);
      
      final results = await _pb.collection('invitations').getFullList(
        filter: 'user = null && invited_phone != ""',
      );

      final toClaim = results.where((inv) {
        final invPhone = _normalizePhone(inv.getStringValue('invited_phone'));
        return invPhone.isNotEmpty && (invPhone == normalizedPhone || normalizedPhone.endsWith(invPhone) || invPhone.endsWith(normalizedPhone));
      }).toList();

      if (toClaim.isEmpty) return;

      print('🔄 Found ${toClaim.length} invitations to claim for $phone');

      for (final inv in toClaim) {
        await _pb.collection('invitations').update(inv.id, body: {
          'user': userId,
          'invited_phone': '', // Clear placeholder
          'invited_name': '',  // Clear placeholder
        });
        
        // Trigger confirmation evaluation for the appointment
        final apptId = inv.getStringValue('appointment');
        if (apptId.isNotEmpty) {
           await _invitationService.evaluateAppointmentConfirmation(apptId);
        }
      }
    } catch (e) {
      print('❌ Error claiming invitations: $e');
    }
  }

  String _normalizePhone(String phone) {
    // Basic normalization: remove non-digits
    return phone.replaceAll(RegExp(r'\D'), '');
  }
}
