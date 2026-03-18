# Firebase Integration Design — Hosting + Firestore + Auth

**Date:** 2026-03-18
**Goal:** Replace SharedPreferences with Firebase Firestore for per-user cloud storage, add anonymous auth with Google/Apple link, deploy web PWA to Firebase Hosting with CI/CD.

## Authentication

- Anonymous auth by default — user starts immediately, no sign-in
- Link account later — prompt to connect Google or Apple Sign-In for cross-device sync
- Apple Sign-In required alongside Google for App Store compliance
- Auth state persisted by Firebase SDK (survives app restart)

## Data Storage

- Single Firestore document per user: `users/{userId}/state`
- Contains the full AppState JSON (same serialization as current SharedPreferences)
- 1MB Firestore doc limit is sufficient — workout data is lightweight
- Future images stored in Firebase Storage, Firestore doc holds URL references only
- Firestore security rules: users can only read/write their own document

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/state/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Data Migration

- On first launch after update, detect existing SharedPreferences data
- If found, push to Firestore under the anonymous user ID
- Clear SharedPreferences after successful migration
- Seamless, no user action needed

## Repository Layer

- New `FirestoreAppStateRepository` implementing existing `AppStateRepository` interface
- Replaces `SharedPreferencesAppStateRepository` as the default
- Firestore offline persistence enabled (built-in on both iOS and web)
- All controllers and UI code unchanged — only the repository swaps

## Account Linking

- When anonymous user links Google/Apple account, Firebase Auth merges the accounts
- Firestore data stays under the same UID — no data migration needed on link
- If user signs in on a new device with linked account, their data loads from Firestore

## Dependencies

- `firebase_core` — Firebase initialization
- `firebase_auth` — anonymous + linked auth
- `cloud_firestore` — data storage
- `google_sign_in` — Google Sign-In
- `sign_in_with_apple` — Apple Sign-In

## Hosting & Deployment

- Flutter web build deployed to Firebase Hosting
- Manual deploy: `firebase deploy`
- GitHub Actions CI/CD: auto-deploy on push to `main`
- Firebase project config committed (firebase.json, .firebaserc)

## What Stays the Same

- All UI code
- All controllers and business logic
- AppState model and JSON serialization
- Router, theme, shared widgets

## Files Modified/Created

- `pubspec.yaml` — add Firebase dependencies
- `lib/src/data/repository/app_state_repository.dart` — add FirestoreAppStateRepository
- `lib/src/core/app_state_controller.dart` — wire new repository
- `lib/src/app/app.dart` — Firebase initialization
- `lib/main.dart` — Firebase.initializeApp
- `firebase.json`, `.firebaserc` — hosting config
- `firestore.rules` — security rules
- `.github/workflows/deploy.yml` — CI/CD pipeline
- New: `lib/src/features/auth/` — auth service + optional settings UI for account linking
