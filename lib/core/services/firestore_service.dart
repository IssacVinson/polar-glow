// lib/core/services/firestore_service.dart
// FINAL VERSION: YTD hours include ALL hours this year (paid + unpaid)
// All methods required by admin_finance_screen.dart are present

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

  // ====================== USERS ======================
  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDocument(doc);
  }

  Future<void> updateUserHourlyRate(String uid, double hourlyRate) async {
    await _db.collection('users').doc(uid).update({'hourlyRate': hourlyRate});
  }

  // ====================== DYNAMIC PAYROLL ======================
  Future<Map<String, dynamic>> calculateEmployeePay(
      String employeeId, DateTime now) async {
    final user = await getUser(employeeId);
    final rate = user?.hourlyRate ?? 0.0;

    // Last payout date
    final payoutSnap = await _db
        .collection('wage_payouts')
        .where('employeeId', isEqualTo: employeeId)
        .get();

    final allPayouts = payoutSnap.docs
        .map((doc) => WagePayoutModel.fromMap(doc.data(), doc.id))
        .toList();

    DateTime lastPayoutDate = DateTime(now.year, 1, 1);
    if (allPayouts.isNotEmpty) {
      allPayouts.sort((a, b) => b.paidAt.compareTo(a.paidAt));
      lastPayoutDate = allPayouts.first.paidAt;
    }

    // YTD Pay
    final yearStart = DateTime(now.year, 1, 1);
    final ytdPay = allPayouts
        .where((p) => !p.paidAt.isBefore(yearStart))
        .fold<double>(0.0, (sum, p) => sum + p.grossPay);

    // Clock events
    final clockSnap = await _db
        .collection('users')
        .doc(employeeId)
        .collection('clock_events')
        .get();

    double unpaidHours = 0.0;
    double ytdHours = 0.0;
    DateTime? openIn;

    for (var doc in clockSnap.docs) {
      final data = doc.data();
      final type = (data['type'] as String?)?.toLowerCase() ?? '';
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final eventDate = AlaskaDateUtils.toAlaskaDayKey(timestamp);

      // Unpaid hours (since last payout, not already paid out)
      if (data['payoutId'] == null && !eventDate.isBefore(lastPayoutDate)) {
        if (type == 'in' || type == 'clock_in') {
          openIn = timestamp;
        } else if ((type == 'out' || type == 'clock_out') && openIn != null) {
          unpaidHours += timestamp.difference(openIn).inMinutes / 60.0;
          openIn = null;
        }
      }

      // YTD hours (ALL hours this year)
      if (!eventDate.isBefore(yearStart)) {
        if (type == 'in' || type == 'clock_in') {
          openIn = timestamp;
        } else if ((type == 'out' || type == 'clock_out') && openIn != null) {
          ytdHours += timestamp.difference(openIn).inMinutes / 60.0;
          openIn = null;
        }
      }
    }

    if (openIn != null) {
      final nowAlaska = AlaskaDateUtils.toAlaskaDayKey(DateTime.now());
      if (!nowAlaska.isBefore(lastPayoutDate)) {
        unpaidHours += DateTime.now().difference(openIn).inMinutes / 60.0;
      }
      if (!nowAlaska.isBefore(yearStart)) {
        ytdHours += DateTime.now().difference(openIn).inMinutes / 60.0;
      }
    }

    return {
      'unpaidHours': unpaidHours,
      'ytdHours': ytdHours,
      'ytdPay': ytdPay,
      'hourlyRate': rate,
      'projectedPayout': unpaidHours * rate,
      'lastPayoutDate': lastPayoutDate,
    };
  }

  // ====================== WAGE PAYOUTS ======================
  Future<String> createWagePayout(WagePayoutModel payout) async {
    final docRef = await _db.collection('wage_payouts').add(payout.toMap());
    return docRef.id;
  }

  Future<String> payEmployeeHours({
    required String employeeId,
    required String adminId,
  }) async {
    final payData = await calculateEmployeePay(employeeId, DateTime.now());

    final payout = WagePayoutModel(
      id: '',
      employeeId: employeeId,
      totalHours: payData['unpaidHours'],
      hourlyRate: payData['hourlyRate'],
      grossPay: payData['projectedPayout'],
      periodStart: payData['lastPayoutDate'],
      periodEnd: DateTime.now(),
      paidAt: DateTime.now(),
      paidBy: adminId,
    );

    final payoutId = await createWagePayout(payout);

    // Mark clock events as paid
    final clockSnap = await _db
        .collection('users')
        .doc(employeeId)
        .collection('clock_events')
        .get();

    final batch = _db.batch();
    for (var doc in clockSnap.docs) {
      if (doc.data()['payoutId'] == null) {
        batch.update(doc.reference, {'payoutId': payoutId});
      }
    }
    await batch.commit();

    // Mark approved reimbursements as paid
    final reimbSnap = await _db
        .collection('reimbursements')
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: 'approved')
        .get();

    for (var doc in reimbSnap.docs) {
      await doc.reference.update({
        'status': 'paid',
        'paidAt': Timestamp.fromDate(DateTime.now()),
        'paidBy': adminId,
      });
    }

    return payoutId;
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

  Future<void> approveReimbursement(
      {required String reimbursementId, required String adminId}) async {
    await _db.collection('reimbursements').doc(reimbursementId).update({
      'status': 'approved',
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminId,
    });
  }

  Future<void> denyReimbursement(
      {required String reimbursementId, required String adminId}) async {
    await _db.collection('reimbursements').doc(reimbursementId).update({
      'status': 'denied',
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'approvedBy': adminId,
    });
  }

  Future<void> markReimbursementPaid(
      {required String reimbursementId, required String adminId}) async {
    await _db.collection('reimbursements').doc(reimbursementId).update({
      'status': 'paid',
      'paidAt': Timestamp.fromDate(DateTime.now()),
      'paidBy': adminId,
    });
  }

  // ====================== REMAINING METHODS (unchanged) ======================
  // services, bookings, stripe, clock events, etc.

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

  Future<DocumentReference> createBookingWithPaymentMethod(
      BookingModel booking) async {
    return await _db.collection('bookings').add(booking.toMap());
  }

  Future<void> markBookingCompleted(
      {required String bookingId, required String employeeId}) async {
    await _db.collection('bookings').doc(bookingId).update({
      'completedAt': Timestamp.fromDate(DateTime.now()),
      'completedBy': employeeId,
      'status': 'completed',
    });
  }

  Future<void> markCashBookingPaid(
      {required String bookingId, required String employeeId}) async {
    await _db.collection('bookings').doc(bookingId).update({
      'paymentStatus': 'paid',
      'paidAt': Timestamp.fromDate(DateTime.now()),
      'paidBy': employeeId,
    });
  }

  Future<Map<String, dynamic>> createPaymentIntent(
      {required String bookingId, required double amount}) async {
    final callable = _functions.httpsCallable('createPaymentIntent');
    final result = await callable
        .call({'bookingId': bookingId, 'amount': (amount * 100).round()});
    return result.data as Map<String, dynamic>;
  }

  Future<void> confirmStripePayment(
      {required String bookingId, required String paymentIntentId}) async {
    await _db.collection('bookings').doc(bookingId).update({
      'paymentStatus': 'paid',
      'paymentIntentId': paymentIntentId,
      'paidAt': Timestamp.fromDate(DateTime.now()),
      'paidBy': 'stripe',
    });
  }

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
