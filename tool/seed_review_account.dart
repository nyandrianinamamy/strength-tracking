import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';

const _firebaseApiKey = 'AIzaSyDyZ5pUeLVRJ8W60SVL2CRkmm98DvjLOFU';
const _projectId = 'myappv4';

Future<void> main(List<String> args) async {
  final email = _readEnv('KOTRANA_REVIEW_EMAIL');
  final password = _readEnv('KOTRANA_REVIEW_PASSWORD');

  final auth = await _signIn(email: email, password: password);
  final demoState = DemoSeedData.initialState().toJson();
  await _writeFirestoreState(
    idToken: auth.idToken,
    uid: auth.localId,
    state: demoState,
  );

  stdout.writeln('Seeded review account $email (${auth.localId})');
}

String _readEnv(String name) {
  final value = Platform.environment[name]?.trim();
  if (value == null || value.isEmpty) {
    stderr.writeln('Missing required environment variable: $name');
    exit(64);
  }
  return value;
}

Future<_FirebaseAuthResult> _signIn({
  required String email,
  required String password,
}) async {
  final uri = Uri.https(
    'identitytoolkit.googleapis.com',
    '/v1/accounts:signInWithPassword',
    {'key': _firebaseApiKey},
  );
  final response = await http.post(
    uri,
    headers: {'content-type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  if (response.statusCode != 200) {
    stderr.writeln('Firebase Auth sign-in failed: ${response.body}');
    exit(1);
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return _FirebaseAuthResult(
    idToken: body['idToken'] as String,
    localId: body['localId'] as String,
  );
}

Future<void> _writeFirestoreState({
  required String idToken,
  required String uid,
  required Map<String, dynamic> state,
}) async {
  final uri = Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$_projectId/databases/(default)/documents/users/$uid/data/state',
  );
  final response = await http.patch(
    uri,
    headers: {
      'authorization': 'Bearer $idToken',
      'content-type': 'application/json',
    },
    body: jsonEncode({'fields': _encodeFields(state)}),
  );
  if (response.statusCode != 200) {
    stderr.writeln('Firestore seed write failed: ${response.body}');
    exit(1);
  }
}

Map<String, dynamic> _encodeFields(Map<String, dynamic> map) {
  return map.map((key, value) => MapEntry(key, _encodeValue(value)));
}

Map<String, dynamic> _encodeValue(Object? value) {
  if (value == null) return {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is num) return {'doubleValue': value.toDouble()};
  if (value is String) return {'stringValue': value};
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(_encodeValue).toList()},
    };
  }
  if (value is Map<String, dynamic>) {
    return {
      'mapValue': {'fields': _encodeFields(value)},
    };
  }
  if (value is Map) {
    return {
      'mapValue': {
        'fields': value.map(
          (key, nested) => MapEntry('$key', _encodeValue(nested)),
        ),
      },
    };
  }
  return {'stringValue': '$value'};
}

class _FirebaseAuthResult {
  const _FirebaseAuthResult({required this.idToken, required this.localId});

  final String idToken;
  final String localId;
}
