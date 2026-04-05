import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  FirebaseAuth get firebaseAuth => _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<User> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  Future<User> linkWithGoogle() async {
    if (kIsWeb) {
      // On web, use popup directly via Firebase Auth
      final provider = GoogleAuthProvider();
      final result = await _auth.currentUser!.linkWithPopup(provider);
      return result.user!;
    }
    // On iOS/Android, use google_sign_in package
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.currentUser!.linkWithCredential(credential);
    return result.user!;
  }

  Future<User> linkWithApple() async {
    if (kIsWeb) {
      final provider = OAuthProvider('apple.com')
        ..addScope('email');
      final result = await _auth.currentUser!.linkWithPopup(provider);
      return result.user!;
    }
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final result = await _auth.currentUser!.linkWithCredential(credential);
    return result.user!;
  }

  Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final result = await _auth.signInWithPopup(provider);
      return result.user!;
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  Future<User> signInWithApple() async {
    if (kIsWeb) {
      final provider = OAuthProvider('apple.com')
        ..addScope('email');
      final result = await _auth.signInWithPopup(provider);
      return result.user!;
    }
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
