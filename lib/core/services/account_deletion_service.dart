import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Deletes the signed-in Firebase Auth user and associated Firestore/Storage data.
///
/// Prefers the `deleteOwnAccount` Cloud Function (Admin SDK, bypasses rules).
/// Falls back to a best-effort client-side delete if the function is not deployed.
class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-west1'),
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  Future<void> deleteCurrentAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('You must be signed in to delete your account.');
    }

    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);

    try {
      final callable = _functions.httpsCallable(
        'deleteOwnAccount',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
      final missing = e.code == 'not-found' ||
          e.code == 'unimplemented' ||
          e.code == 'unavailable' ||
          (e.message?.toLowerCase().contains('not found') ?? false);
      if (!missing) {
        rethrow;
      }
      await _deleteClientSide(user);
    } catch (_) {
      await _deleteClientSide(user);
    }

    try {
      await _auth.currentUser?.delete();
    } catch (_) {
      // Cloud Function may already have removed the Auth user.
    }

    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<void> _deleteClientSide(User user) async {
    final uid = user.uid;
    final userDoc = await _db.collection('users').doc(uid).get();
    final username = (userDoc.data()?['username'] as String?)?.toLowerCase();

    await _deleteQuery(
      _db.collection('reviews').where('customerId', isEqualTo: uid),
    );
    await _deleteQuery(
      _db.collection('reimbursements').where('employeeId', isEqualTo: uid),
    );

    final bookings = await _db
        .collection('bookings')
        .where('customerId', isEqualTo: uid)
        .get();
    for (final doc in bookings.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      final paid = data['paymentStatus'] == 'paid' || data['paid'] == true;
      if (paid || status == 'completed') {
        await doc.reference.update({
          'customerId': 'deleted_user',
          'address': '',
          'notes': '',
          'customerDeletedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await doc.reference.delete();
      }
    }

    await _deleteSubcollection(userDoc.reference.collection('clock_events'));
    await _deleteSubcollection(userDoc.reference.collection('availability'));

    if (username != null && username.isNotEmpty) {
      try {
        await _db.collection('usernames').doc(username).delete();
      } catch (_) {
        // Rules may block this until the Cloud Function is deployed.
      }
    }

    try {
      await _storage.ref('reimbursements/$uid').listAll().then((result) async {
        for (final item in result.items) {
          await item.delete();
        }
      });
    } catch (_) {}

    await _db.collection('users').doc(uid).delete();
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    final snap = await query.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _deleteSubcollection(
      CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.limit(200).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    if (snap.docs.length == 200) {
      await _deleteSubcollection(col);
    }
  }
}
