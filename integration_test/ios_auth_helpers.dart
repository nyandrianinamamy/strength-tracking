import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const inviteTestProject = 'demo-kotrana-e2e';
const inviteTestPassword = 'isolated-emulator-password';
const inviteTestOptions = FirebaseOptions(
  apiKey: 'fake-api-key',
  appId: '1:1234567890:ios:0123456789abcdef',
  messagingSenderId: '1234567890',
  projectId: inviteTestProject,
);

typedef InviteEmulators = ({FirebaseAuth auth, FirebaseFirestore firestore});
Future<InviteEmulators>? _inviteEmulators;

// The combined suite shares one native Firebase instance. Configure its emulator
// endpoints before first use, once per process; each test still resets its data.
Future<InviteEmulators> connectInviteEmulators() =>
    _inviteEmulators ??= _connectInviteEmulators();

Future<InviteEmulators> _connectInviteEmulators() async {
  final app = await Firebase.initializeApp(options: inviteTestOptions);
  expect(app.options.projectId, inviteTestProject);
  final auth = FirebaseAuth.instance;
  await auth.useAuthEmulator('127.0.0.1', 19099);
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: false);
  firestore.useFirestoreEmulator('127.0.0.1', 18081);
  return (auth: auth, firestore: firestore);
}

Future<void> resetInviteEmulators(FirebaseAuth auth) async {
  await auth.signOut();
  for (final url in [
    'http://127.0.0.1:18081/emulator/v1/projects/$inviteTestProject/databases/(default)/documents',
    'http://127.0.0.1:19099/emulator/v1/projects/$inviteTestProject/accounts',
  ]) {
    expect(
      (await http.delete(Uri.parse(url))).statusCode,
      200,
      reason: 'Isolated emulator reset failed',
    );
  }
}

Future<String> createInviteAccount(
  FirebaseAuth auth,
  String email, {
  bool? allowed,
}) async {
  final credential = await auth.createUserWithEmailAndPassword(
    email: email,
    password: inviteTestPassword,
  );
  if (allowed != null) {
    final response = await http.patch(
      Uri.parse(
        'http://127.0.0.1:18081/v1/projects/$inviteTestProject/databases/(default)/documents/allowedEmails/$email',
      ),
      headers: {
        'Authorization': 'Bearer owner',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fields': {
          'enabled': {'booleanValue': allowed},
        },
      }),
    );
    expect(
      response.statusCode,
      200,
      reason: 'Could not seed the isolated allowlist',
    );
  }
  return credential.user!.uid;
}
