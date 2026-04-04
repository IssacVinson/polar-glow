// lib/core/services/firestore_service.dart
// FIXED: calculateEmployeePay now uses in-memory filtering (bypasses stuck index)
// All other finance queries unchanged and consistent

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/app_user.dart';
import '../models/service_model.dart';
import '../models/booking_model.dart';
import '../models/clock_event_model.dart';
import '../models/reimbursement_model.dart';
import '../models/wage_payout_model.dart';
import '../utils/alaska_date_utils.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  // ====================== CALENDAR COUNT HELPERS ======================
  Future<Map<DateTime, int>> getEmployeeBookingCounts(
      String uid, DateTime start, DateTime end) async {
    final counts = <DateTime, int>{};

    final snap = await _db
        .collection('bookings')
        .where('assignedDetailerId', isEqualTo: uid)
        .where('date',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(AlaskaDateUtils.toAlaskaStorageDate(start)))
        .where('date',
            isLessThanOrEqualTo:
                Timestamp.fromDate(AlaskaDateUtils.toAlaskaStorageDate(end)))
        .get();

    for (var doc in snap.docs) {
      final data = doc.data();
      final ts = (data['date'] as Timestamp?)?.toDate();
      if (ts == null) continue;

      final alaskaDay = AlaskaDateUtils.toAlaskaDayKey(ts);
      final dayKey = DateTime(alaskaDay.year, alaskaDay.month, alaskaDay.day);
      counts[dayKey] = (counts[dayKey] ?? 0) + 1;
    }
    return counts;
  }

  // ====================== USERS ======================
  Future<String> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['role'] as String?)?.toLowerCase() ?? 'customer';
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDocument(doc);
  }

  Future<void> updateUserHourlyRate(String uid, double hourlyRate) async {
    await _db.collection('users').doc(uid).update({'hourlyRate': hourlyRate});
  }

  /// FIXED: In-memory filtering (no index required)
  Future<Map<String, dynamic>> calculateEmployeePay(
      String employeeId, DateTime startDate, DateTime endDate) async {
    final snap = await _db
        .collection('users')
        .doc(employeeId)
        .collection('clock_events')
        .get(); // no where / orderBy → no index needed

    double totalHours = 0.0;
    DateTime? clockInTime;

    final start = AlaskaDateUtils.toAlaskaDayKey(startDate);
    final end = AlaskaDateUtils.toAlaskaDayKey(endDate);

    for (var doc in snap.docs) {
      final data = doc.data();
      final type = (data['type'] as String?)?.toLowerCase() ?? '';
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final eventDate = AlaskaDateUtils.toAlaskaDayKey(timestamp);

      // Only count events inside the requested range
      if (eventDate.isBefore(start) || eventDate.isAfter(end)) continue;

      if (type == 'clock_in' || type == 'in') {
        clockInTime = timestamp;
      } else if ((type == 'clock_out' || type == 'out') &&
          clockInTime != null) {
        final duration = timestamp.difference(clockInTime).inMinutes / 60.0;
        totalHours += duration;
        clockInTime = null;
      }
    }

    final user = await getUser(employeeId);
    final rate = user?.hourlyRate ?? 0.0;
    final grossPay = totalHours * rate;

    return {
      'totalHours': totalHours,
      'hourlyRate': rate,
      'grossPay': grossPay,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  // ====================== WAGE PAYOUTS ======================
  Future<String> createWagePayout(WagePayoutModel payout) async {
    final docRef = await _db.collection('wage_payouts').add(payout.toMap());
    return docRef.id;
  }

  Future<List<WagePayoutModel>> getEmployeePayoutHistory(
      String employeeId) async {
    final snap = await _db
        .collection('wage_payouts')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('paidAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => WagePayoutModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<WagePayoutModel>> getAllPayoutsForAdmin() async {
    final snap = await _db
        .collection('wage_payouts')
        .orderBy('paidAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => WagePayoutModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> payEmployeeHours({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
    required String adminId,
  }) async {
    final payData = await calculateEmployeePay(employeeId, startDate, endDate);

    final payout = WagePayoutModel(
      id: '',
      employeeId: employeeId,
      totalHours: payData['totalHours'],
      hourlyRate: payData['hourlyRate'],
      grossPay: payData['grossPay'],
      periodStart: startDate,
      periodEnd: endDate,
      paidAt: DateTime.now(),
      paidBy: adminId,
    );

    return await createWagePayout(payout);
  }

  // ====================== SERVICES ======================
  Future<List<ServiceModel>> getServices() async {
    final snapshot = await _db.collection('services').get();
    return snapshot.docs
        .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> addService(ServiceModel service) async {
    await _db.collection('services').add(service.toMap());
  }

  Future<void> updateService(String id, ServiceModel service) async {
    await _db.collection('services').doc(id).update(service.toMap());
  }

  Future<void> deleteService(String id) async {
    await _db.collection('services').doc(id).delete();
  }

  // ====================== BOOKINGS ======================
  Future<DocumentReference> createBookingWithPaymentMethod(
      BookingModel booking) async {
    return await _db.collection('bookings').add(booking.toMap());
  }

  Future<void> markBookingCompleted({
    required String bookingId,
    required String employeeId,
  }) async {
    await _db.collection('bookings').doc(bookingId).update({
      'completedAt': Timestamp.fromDate(DateTime.now()),
      'completedBy': employeeId,
      'status': 'completed',
    });
  }

  Future<void> markCashBookingPaid({
    required String bookingId,
    required String employeeId,
  }) async {
    await _db.collection('bookings').doc(bookingId).update({
      'paymentStatus': 'paid',
      'paidAt': Timestamp.fromDate(DateTime.now()),
      'paidBy': employeeId,
    });
  }

  // ====================== STRIPE ======================
  Future<Map<String, dynamic>> createPaymentIntent({
    required String bookingId,
    required double amount,
  }) async {
    final callable = _functions.httpsCallable('createPaymentIntent');
    final result = await callable.call({
      'bookingId': bookingId,
      'amount': (amount * 100).round(),
    });
    return result.data as Map<String, dynamic>;
  }

  Future<void> confirmStripePayment({
    required String bookingId,
    required String paymentIntentId,
  }) async {
    await _db.collection('bookings').doc(bookingId).update({
      'paymentStatus': 'paid',
      'paymentIntentId': paymentIntentId,
      'paidAt': Timestamp.fromDate(DateTime.now()),
      'paidBy': 'stripe',
    });
  }

  // ====================== REIMBURSEMENTS ======================
  Future<String> submitReimbursement(ReimbursementModel reimbursement) async {
    final docRef =
        await _db.collection('reimbursements').add(reimbursement.toMap());
    return docRef.id;
  }

  Future<List<ReimbursementModel>> getEmployeeReimbursements(
      String employeeId) async {
    final snap = await _db
        .collection('reimbursements')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('dateSubmitted', descending: true)
        .get();

    return snap.docs
        .map((doc) => ReimbursementModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<ReimbursementModel>> getAllReimbursementsForAdmin() async {
    final snap = await _db
        .collection('reimbursements')
        .orderBy('dateSubmitted', descending: true)
        .get();

    return snap.docs
        .map((doc) => ReimbursementModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> approveReimbursement({
    required String reimbursementId,
    required String adminId,
  }) async {
    await _db.collection('reimbursements').doc(reimbursementId).update({
      'status': 'approved',
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminId,
    });
  }

  Future<void> denyReimbursement({
    required String reimbursementId,
    required String adminId,
  }) async {
    await _db.collection('reimbursements').doc(reimbursementId).update({
      'status': 'denied',
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminId,
    });
  }

  Future<void> markReimbursementPaid({
    required String reimbursementId,
    required String adminId,
  }) async {
    await _db.collection('reimbursements').doc(reimbursementId).update({
      'status': 'paid',
      'paidAt': Timestamp.fromDate(DateTime.now()),
      'paidBy': adminId,
    });
  }

  // ====================== CLOCK EVENTS ======================
  Future<List<ClockEventModel>> getClockEventsFuture(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('clock_events')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .get();
    return snapshot.docs
        .map((doc) => ClockEventModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> addClockEvent(String uid, String type) async {
    final now = DateTime.now();
    final alaskaDay = AlaskaDateUtils.toAlaskaDayKey(now);
    final dateStr = AlaskaDateUtils.toDateString(alaskaDay);

    await _db.collection('users').doc(uid).collection('clock_events').add({
      'type': type,
      'timestamp': Timestamp.fromDate(now),
      'date': dateStr,
    });
  }

  Future<void> updateClockEventTimestamp(
      String uid, String docId, DateTime newTimestamp) async {
    final alaskaDay = AlaskaDateUtils.toAlaskaDayKey(newTimestamp);
    final dateStr = AlaskaDateUtils.toDateString(alaskaDay);

    await _db
        .collection('users')
        .doc(uid)
        .collection('clock_events')
        .doc(docId)
        .update({
      'timestamp': Timestamp.fromDate(newTimestamp),
      'date': dateStr,
    });
  }
}
