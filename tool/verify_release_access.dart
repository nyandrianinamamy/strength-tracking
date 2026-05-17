import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _defaultProjectId = 'myappv4';
const _reviewEmail = 'app-review@mamy-r.dev';
const _allowlistExpectations = <String, String>{
  'app-review@mamy-r.dev': 'reviewer',
  'ramiasamananaando5@gmail.com': 'user',
  'nyandrianinamamy@gmail.com': 'admin',
};

Future<void> main() async {
  final projectId =
      Platform.environment['KOTRANA_FIREBASE_PROJECT']?.trim().isNotEmpty ==
          true
      ? Platform.environment['KOTRANA_FIREBASE_PROJECT']!.trim()
      : _defaultProjectId;
  final accessToken = Platform.environment['KOTRANA_FIREBASE_ACCESS_TOKEN']
      ?.trim();

  if (accessToken == null || accessToken.isEmpty) {
    stderr.writeln(
      'Missing KOTRANA_FIREBASE_ACCESS_TOKEN. Generate one with:\n'
      '  gcloud auth print-access-token\n\n'
      'Then run:\n'
      '  KOTRANA_FIREBASE_ACCESS_TOKEN="\$(gcloud auth print-access-token)" '
      'dart run tool/verify_release_access.dart',
    );
    exit(64);
  }

  for (final entry in _allowlistExpectations.entries) {
    await _verifyAllowlistEntry(
      projectId: projectId,
      accessToken: accessToken,
      email: entry.key,
      expectedRole: entry.value,
    );
  }

  final reviewerUid = await _lookupReviewerUid(
    projectId: projectId,
    accessToken: accessToken,
  );
  await _verifyReviewerState(
    projectId: projectId,
    accessToken: accessToken,
    reviewerUid: reviewerUid,
  );

  stdout.writeln('Release access verification passed for $projectId');
}

Future<void> _verifyAllowlistEntry({
  required String projectId,
  required String accessToken,
  required String email,
  required String expectedRole,
}) async {
  final normalizedEmail = email.trim().toLowerCase();
  final data = await _getJson(
    Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/allowedEmails/$normalizedEmail',
    ),
    accessToken: accessToken,
  );
  final fields = data['fields'] as Map<String, dynamic>? ?? {};
  final storedEmail =
      (fields['email'] as Map<String, dynamic>?)?['stringValue'];
  final enabled = (fields['enabled'] as Map<String, dynamic>?)?['booleanValue'];
  final role = (fields['role'] as Map<String, dynamic>?)?['stringValue'];

  if (storedEmail != normalizedEmail ||
      enabled != true ||
      role != expectedRole) {
    _fail(
      'Allowlist mismatch for $normalizedEmail: '
      'enabled=$enabled role=$role storedEmail=$storedEmail',
    );
  }
  stdout.writeln('Allowlist OK: $normalizedEmail -> $role');
}

Future<String> _lookupReviewerUid({
  required String projectId,
  required String accessToken,
}) async {
  final response = await http.post(
    Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:lookup'),
    headers: _headers(accessToken, projectId: projectId),
    body: jsonEncode({
      'email': [_reviewEmail],
    }),
  );

  if (response.statusCode != 200) {
    _fail('Reviewer account lookup failed: HTTP ${response.statusCode}');
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final users = body['users'] as List<dynamic>? ?? const [];
  if (users.length != 1) {
    _fail('Expected exactly one reviewer auth user, found ${users.length}');
  }

  final user = users.single as Map<String, dynamic>;
  final email = user['email'] as String?;
  final localId = user['localId'] as String?;
  if (email != _reviewEmail || localId == null || localId.isEmpty) {
    _fail('Reviewer auth user is missing email or uid');
  }

  stdout.writeln('Reviewer Auth OK: $_reviewEmail');
  return localId;
}

Future<void> _verifyReviewerState({
  required String projectId,
  required String accessToken,
  required String reviewerUid,
}) async {
  final data = await _getJson(
    Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/users/$reviewerUid/data/state',
    ),
    accessToken: accessToken,
  );
  final fields = data['fields'] as Map<String, dynamic>? ?? {};
  final exerciseCount = _arrayCount(fields, 'exercises');
  final routineCount = _arrayCount(fields, 'routines');
  final routineGroupCount = _arrayCount(fields, 'routineGroups');
  final sessionCount = _arrayCount(fields, 'sessions');

  if (exerciseCount == 0 ||
      routineCount == 0 ||
      routineGroupCount == 0 ||
      sessionCount == 0) {
    _fail(
      'Reviewer state is not seeded enough: '
      'exercises=$exerciseCount routines=$routineCount '
      'routineGroups=$routineGroupCount sessions=$sessionCount',
    );
  }

  stdout.writeln(
    'Reviewer demo state OK: '
    'exercises=$exerciseCount routines=$routineCount '
    'routineGroups=$routineGroupCount sessions=$sessionCount',
  );
}

Future<Map<String, dynamic>> _getJson(
  Uri uri, {
  required String accessToken,
}) async {
  final response = await http.get(uri, headers: _headers(accessToken));
  if (response.statusCode != 200) {
    _fail('GET ${uri.path} failed: HTTP ${response.statusCode}');
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Map<String, String> _headers(String accessToken, {String? projectId}) {
  final headers = {
    'authorization': 'Bearer $accessToken',
    'content-type': 'application/json',
  };
  if (projectId != null) {
    headers['x-goog-user-project'] = projectId;
  }
  return headers;
}

int _arrayCount(Map<String, dynamic> fields, String name) {
  final field = fields[name] as Map<String, dynamic>?;
  final arrayValue = field?['arrayValue'] as Map<String, dynamic>?;
  final values = arrayValue?['values'] as List<dynamic>?;
  return values?.length ?? 0;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
