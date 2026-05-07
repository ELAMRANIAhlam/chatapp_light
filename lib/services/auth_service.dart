import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get currentUserId => _auth.currentUser!.uid;

  // Mise à jour du statut en ligne
  Future<void> updateOnlineStatus(bool isOnline) async {
    await _firestore.collection('users').doc(currentUserId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}