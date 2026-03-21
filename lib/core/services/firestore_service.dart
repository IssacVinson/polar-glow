import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/service_model.dart';
import '../models/booking_model.dart';
import '../models/clock_event_model.dart';
import '../utils/alaska_date_utils.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  // ====================== SERVICES - FULL CRUD ======================
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
  Future<DocumentReference> createBooking(BookingModel booking) async {
    return await _db.collection('bookings').add(booking.toMap());
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
    // Force Alaska day string so clock events group correctly in AKST (prevents any future shifts)
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
    // Force Alaska day string
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
