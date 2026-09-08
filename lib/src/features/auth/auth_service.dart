import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(null);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth? _auth;

  bool get isAvailable => _auth != null;

  FirebaseAuth get firebaseAuth => _requireAuth();

  Stream<User?> authStateChanges() =>
      _auth?.authStateChanges() ?? Stream<User?>.value(null);

  User? get currentUser => _auth?.currentUser;

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase authentication is unavailable');
    }
    return auth;
  }

  String get currentProviderId {
    final user = _requireAuth().currentUser;
    if (user == null) throw StateError('No authenticated user');
    final providers = user.providerData.map((data) => data.providerId);
    if (providers.contains('apple.com')) return 'apple.com';
    if (providers.contains('google.com')) return 'google.com';
    if (providers.contains('password')) return 'password';
    throw StateError('Unsupported authentication provider');
  }

  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _requireAuth().signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  Future<User> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw const AuthOperationCancelled();
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _requireAuth().signInWithCredential(credential);
    return result.user!;
  }

  Future<User> signInWithApple() async {
    final auth = _requireAuth();
    final apple = await _requestAppleCredential();
    final result = await auth.signInWithCredential(apple.credential);
    return result.user!;
  }

  Future<void> signOut() async {
    await _requireAuth().signOut();
  }

  Future<void> deleteCurrentUser() async {
    final user = _requireAuth().currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    await user.delete();
  }

  Future<void> reauthenticateWithEmailPassword(String password) async {
    final user = _requireAuth().currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No authenticated email user');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  Future<void> reauthenticateWithGoogle() async {
    final user = _requireAuth().currentUser;
    if (user == null) throw StateError('No authenticated user');
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw const AuthOperationCancelled();
    final googleAuth = await googleUser.authentication;
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );
  }

  /// Returns the fresh Apple authorization code required for token revocation.
  Future<String> reauthenticateWithApple() async {
    final user = _requireAuth().currentUser;
    if (user == null) throw StateError('No authenticated user');
    final apple = await _requestAppleCredential();
    if (apple.authorizationCode.isEmpty) {
      throw StateError('Apple did not return an authorization code');
    }
    await user.reauthenticateWithCredential(apple.credential);
    return apple.authorizationCode;
  }

  Future<({OAuthCredential credential, String authorizationCode})>
  _requestAppleCredential() async {
    final random = Random.secure();
    final rawNonce = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: hashedNonce,
      );
      final idToken = apple.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Apple did not return an identity token');
      }
      return (
        credential: OAuthProvider(
          'apple.com',
        ).credential(idToken: idToken, rawNonce: rawNonce),
        authorizationCode: apple.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthOperationCancelled();
      }
      rethrow;
    }
  }

  Future<void> revokeAppleToken(String authorizationCode) async {
    await _requireAuth().revokeTokenWithAuthorizationCode(authorizationCode);
  }
}

class AuthOperationCancelled implements Exception {
  const AuthOperationCancelled();
}
