import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String normalizeInviteEmail(String? email) => email?.trim().toLowerCase() ?? '';

class InviteAccess {
  const InviteAccess({required this.email, required this.enabled, this.role});

  factory InviteAccess.fromSnapshot(
    String email,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return InviteAccess(
      email: email,
      enabled: snapshot.exists && data?['enabled'] == true,
      role: data?['role'] as String?,
    );
  }

  final String email;
  final bool enabled;
  final String? role;

  bool get isAllowed => enabled;
}

class InviteAccessDeniedException implements Exception {
  InviteAccessDeniedException(this.email);

  final String email;

  @override
  String toString() => 'Access to Kotrana is invite-only for $email';
}

class InviteAccessService {
  InviteAccessService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<InviteAccess> fetch(String? email) async {
    final normalizedEmail = normalizeInviteEmail(email);
    if (normalizedEmail.isEmpty) {
      return const InviteAccess(email: '', enabled: false);
    }

    final snapshot = await _firestore
        .collection('allowedEmails')
        .doc(normalizedEmail)
        .get();
    return InviteAccess.fromSnapshot(normalizedEmail, snapshot);
  }

  Future<InviteAccess> requireAllowed(User? user) async {
    final access = await fetch(user?.email);
    if (!access.isAllowed) {
      throw InviteAccessDeniedException(access.email);
    }
    return access;
  }
}
