import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/features/auth/invite_access.dart';

void main() {
  group('normalizeInviteEmail', () {
    test('trims whitespace and lowercases email addresses', () {
      expect(
        normalizeInviteEmail('  App-Review@Mamy-R.Dev  '),
        'app-review@mamy-r.dev',
      );
    });

    test('returns an empty string for missing emails', () {
      expect(normalizeInviteEmail(null), '');
      expect(normalizeInviteEmail('   '), '');
    });
  });

  group('InviteAccess', () {
    test('requires enabled allowlist entry', () {
      expect(
        const InviteAccess(email: 'user@example.com', enabled: true).isAllowed,
        isTrue,
      );
      expect(
        const InviteAccess(email: 'user@example.com', enabled: false).isAllowed,
        isFalse,
      );
    });
  });
}
