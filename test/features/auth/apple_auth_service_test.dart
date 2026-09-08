import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';

// These are platform/auth boundary fakes; no Apple or Firebase request is sent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const appleChannel = MethodChannel(
    'com.aboutyou.dart_packages.sign_in_with_apple',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Auth auth;
  late AuthService service;
  late List<Map<dynamic, dynamic>> requests;
  String? identityToken;
  String? authorizationCode;
  PlatformException? platformError;

  setUp(() {
    auth = _Auth();
    service = AuthService(auth);
    requests = [];
    identityToken = 'isolated-apple-id-token';
    authorizationCode = null;
    platformError = null;
    messenger.setMockMethodCallHandler(appleChannel, (call) async {
      expect(call.method, 'performAuthorizationRequest');
      final request =
          (call.arguments as List<dynamic>).single as Map<dynamic, dynamic>;
      requests.add(request);
      if (platformError != null) throw platformError!;
      return {
        'type': 'appleid',
        'userIdentifier': 'isolated-apple-user',
        'email': 'apple@example.invalid',
        'identityToken': identityToken,
        'authorizationCode':
            authorizationCode ?? 'isolated-code-${requests.length}',
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(appleChannel, null));

  for (final reauthenticate in [false, true]) {
    final flow = reauthenticate ? 'reauthentication' : 'sign-in';
    test(
      '$flow binds each Firebase credential to a fresh Apple nonce',
      () async {
        for (var attempt = 1; attempt <= 2; attempt++) {
          if (reauthenticate) {
            expect(
              await service.reauthenticateWithApple(),
              'isolated-code-$attempt',
            );
          } else {
            expect(await service.signInWithApple(), same(auth.user));
          }
        }
        final credentials = reauthenticate
            ? auth.user.credentials
            : auth.credentials;
        expect(credentials, hasLength(2));
        expect(requests, hasLength(2));
        final nonces = <String>{};
        for (var index = 0; index < 2; index++) {
          final credential = credentials[index] as OAuthCredential;
          expect(credential.providerId, 'apple.com');
          expect(credential.idToken, identityToken);
          expect(
            credential.accessToken,
            isNull,
            reason: 'An authorization code is not an access token.',
          );
          final rawNonce = credential.rawNonce!;
          expect(rawNonce.length, greaterThanOrEqualTo(32));
          expect(
            requests[index]['nonce'],
            sha256.convert(utf8.encode(rawNonce)).toString(),
          );
          expect(requests[index]['scopes'], ['email']);
          nonces.add(rawNonce);
        }
        expect(
          nonces,
          hasLength(2),
          reason: 'Do not reuse a nonce between authorization requests.',
        );
        expect(
          reauthenticate ? auth.credentials : auth.user.credentials,
          isEmpty,
        );
      },
    );

    test(
      '$flow reports cancellation consistently without contacting Firebase',
      () async {
        platformError = PlatformException(
          code: 'authorization-error/canceled',
          message: 'Cancelled',
        );
        await expectLater(
          reauthenticate
              ? service.reauthenticateWithApple()
              : service.signInWithApple(),
          throwsA(isA<AuthOperationCancelled>()),
        );
        expect(auth.credentials, isEmpty);
        expect(auth.user.credentials, isEmpty);
        expect(auth.currentUser, same(auth.user));
      },
    );

    for (final missingToken in <String?>[null, '']) {
      test(
        '$flow rejects ${missingToken == null ? 'null' : 'empty'} identity token before Firebase',
        () async {
          identityToken = missingToken;
          await expectLater(
            reauthenticate
                ? service.reauthenticateWithApple()
                : service.signInWithApple(),
            throwsA(isA<StateError>()),
          );
          expect(auth.credentials, isEmpty);
          expect(auth.user.credentials, isEmpty);
        },
      );
    }
  }

  test(
    'reauthentication requires the authorization code needed for revocation',
    () async {
      authorizationCode = '';
      await expectLater(
        service.reauthenticateWithApple(),
        throwsA(isA<StateError>()),
      );
      expect(auth.user.credentials, isEmpty);
    },
  );

  test(
    'unavailable Firebase does not open the Apple authorization sheet',
    () async {
      await expectLater(
        AuthService(null).signInWithApple(),
        throwsA(isA<StateError>()),
      );
      expect(requests, isEmpty);
    },
  );
}

class _Auth implements FirebaseAuth {
  final user = _User();
  final credentials = <AuthCredential>[];
  @override
  User? get currentUser => user;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credentials.add(credential);
    return _UserCredential(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  final credentials = <AuthCredential>[];
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    credentials.add(credential);
    return _UserCredential(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UserCredential implements UserCredential {
  _UserCredential(this.user);
  @override
  final User user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
