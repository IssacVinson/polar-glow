/// Shared delete-vs-anonymize rules for the in-app account deletion path.
///
/// Must stay in lockstep with `functions/index.js` (`deleteOwnAccount`).
class AccountDeletionRules {
  static const anonymizedCustomerId = 'deleted_user';
  static const callableName = 'deleteOwnAccount';

  static const missingCallableCodes = <String>{
    'not-found',
    'unimplemented',
    'unavailable',
  };

  static bool shouldAnonymizeBooking(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final paid = data['paymentStatus'] == 'paid' || data['paid'] == true;
    return paid || status == 'completed';
  }

  static bool isMissingCallable({required String code, String? message}) {
    return missingCallableCodes.contains(code) ||
        (message?.toLowerCase().contains('not found') ?? false);
  }

  static Map<String, Object> anonymizedFields() {
    return {
      'customerId': anonymizedCustomerId,
      'address': '',
      'notes': '',
    };
  }
}
