import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _defaultProjectId = 'myappv4';
const _allowlistEntries = <({String email, String role})>[
  (email: 'app-review@mamy-r.dev', role: 'reviewer'),
  (email: 'ramiasamananaando5@gmail.com', role: 'user'),
  (email: 'nyandrianinamamy@gmail.com', role: 'admin'),
];

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final projectId = Platform.environment['KOTRANA_FIREBASE_PROJECT']?.trim();
  final accessToken = Platform.environment['KOTRANA_FIREBASE_ACCESS_TOKEN']
      ?.trim();

  if (dryRun) {
    for (final entry in _allowlistEntries) {
      stdout.writeln('${entry.email} -> ${entry.role}');
    }
    return;
  }

  if (accessToken == null || accessToken.isEmpty) {
    stderr.writeln(
      'Missing KOTRANA_FIREBASE_ACCESS_TOKEN. Generate one with:\n'
      '  gcloud auth print-access-token\n\n'
      'Then run:\n'
      '  KOTRANA_FIREBASE_ACCESS_TOKEN="\$(gcloud auth print-access-token)" '
      'dart run tool/seed_release_access.dart',
    );
    exit(64);
  }

  final resolvedProjectId = projectId == null || projectId.isEmpty
      ? _defaultProjectId
      : projectId;

  for (final entry in _allowlistEntries) {
    await _upsertAllowlistEntry(
      projectId: resolvedProjectId,
      accessToken: accessToken,
      email: entry.email,
      role: entry.role,
    );
    stdout.writeln('Allowlisted ${entry.email} as ${entry.role}');
  }
}

Future<void> _upsertAllowlistEntry({
  required String projectId,
  required String accessToken,
  required String email,
  required String role,
}) async {
  final normalizedEmail = email.trim().toLowerCase();
  final uri = Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$projectId/databases/(default)/documents/allowedEmails/$normalizedEmail',
    {
      'updateMask.fieldPaths': [
        'email',
        'enabled',
        'role',
        'createdAt',
        'updatedAt',
      ],
    },
  );
  final now = DateTime.now().toUtc().toIso8601String();

  final response = await http.patch(
    uri,
    headers: {
      'authorization': 'Bearer $accessToken',
      'content-type': 'application/json',
    },
    body: jsonEncode({
      'fields': {
        'email': {'stringValue': normalizedEmail},
        'enabled': {'booleanValue': true},
        'role': {'stringValue': role},
        'createdAt': {'timestampValue': now},
        'updatedAt': {'timestampValue': now},
      },
    }),
  );

  if (response.statusCode != 200) {
    stderr.writeln('Failed to allowlist $normalizedEmail: ${response.body}');
    exit(1);
  }
}
