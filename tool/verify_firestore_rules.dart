import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _projectId = 'myappv4';
const _authEmulatorHost = '127.0.0.1:9099';
const _firestoreEmulatorHost = '127.0.0.1:8081';

Future<void> main() async {
  await _resetEmulators();

  final allowed = await _createUser('allowed@example.com');
  final denied = await _createUser('denied@example.com');

  await _adminSetDocument('allowedEmails/allowed@example.com', {
    'email': {'stringValue': 'allowed@example.com'},
    'enabled': {'booleanValue': true},
    'role': {'stringValue': 'user'},
  });

  await _expectStatus(
    'allowed user reads own allowlist entry',
    () => _getDocument(
      'allowedEmails/allowed@example.com',
      idToken: allowed.idToken,
    ),
    200,
  );
  await _expectStatus(
    'denied user cannot create app state',
    () => _patchDocument(
      'users/${denied.localId}/data/state',
      idToken: denied.idToken,
      fields: _minimalStateFields(),
    ),
    403,
  );
  await _expectStatus(
    'allowed user writes own app state',
    () => _patchDocument(
      'users/${allowed.localId}/data/state',
      idToken: allowed.idToken,
      fields: _minimalStateFields(),
    ),
    200,
  );
  await _expectStatus(
    'allowed user cannot write another user state',
    () => _patchDocument(
      'users/${denied.localId}/data/state',
      idToken: allowed.idToken,
      fields: _minimalStateFields(),
    ),
    403,
  );
  await _expectStatus(
    'client cannot create allowlist entry',
    () => _patchDocument(
      'allowedEmails/denied@example.com',
      idToken: allowed.idToken,
      fields: {
        'email': {'stringValue': 'denied@example.com'},
        'enabled': {'booleanValue': true},
      },
    ),
    403,
  );

  stdout.writeln('Firestore rules verifier passed.');
}

Future<void> _resetEmulators() async {
  await http.delete(
    Uri.http(
      _firestoreEmulatorHost,
      '/emulator/v1/projects/$_projectId/databases/(default)/documents',
    ),
  );
  await http.delete(
    Uri.http(_authEmulatorHost, '/emulator/v1/projects/$_projectId/accounts'),
  );
}

Future<_AuthUser> _createUser(String email) async {
  final response = await http.post(
    Uri.http(
      _authEmulatorHost,
      '/identitytoolkit.googleapis.com/v1/accounts:signUp',
      {'key': 'owner'},
    ),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': 'Password123!',
      'returnSecureToken': true,
    }),
  );
  if (response.statusCode != 200) {
    throw StateError('Failed to create $email: ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return _AuthUser(
    email: email,
    idToken: body['idToken'] as String,
    localId: body['localId'] as String,
  );
}

Future<void> _adminSetDocument(
  String documentPath,
  Map<String, dynamic> fields,
) async {
  final response = await _patchDocument(
    documentPath,
    idToken: 'owner',
    fields: fields,
  );
  if (response.statusCode != 200) {
    throw StateError('Admin write failed: ${response.body}');
  }
}

Future<http.Response> _getDocument(
  String documentPath, {
  required String idToken,
}) {
  return http.get(
    _documentUri(documentPath),
    headers: {'authorization': 'Bearer $idToken'},
  );
}

Future<http.Response> _patchDocument(
  String documentPath, {
  required String idToken,
  required Map<String, dynamic> fields,
}) {
  return http.patch(
    _documentUri(documentPath),
    headers: {
      'authorization': 'Bearer $idToken',
      'content-type': 'application/json',
    },
    body: jsonEncode({'fields': fields}),
  );
}

Uri _documentUri(String documentPath) {
  return Uri.http(
    _firestoreEmulatorHost,
    '/v1/projects/$_projectId/databases/(default)/documents/$documentPath',
  );
}

Map<String, dynamic> _minimalStateFields() {
  return {
    'userName': {'stringValue': 'Rules Test'},
    'preferredUnit': {'stringValue': 'kg'},
  };
}

Future<void> _expectStatus(
  String label,
  Future<http.Response> Function() request,
  int expectedStatus,
) async {
  final response = await request();
  if (response.statusCode != expectedStatus) {
    throw StateError(
      '$label expected HTTP $expectedStatus but got '
      '${response.statusCode}: ${response.body}',
    );
  }
  stdout.writeln('ok: $label');
}

class _AuthUser {
  const _AuthUser({
    required this.email,
    required this.idToken,
    required this.localId,
  });

  final String email;
  final String idToken;
  final String localId;
}
