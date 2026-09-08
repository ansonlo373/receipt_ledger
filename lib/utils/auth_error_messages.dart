import 'package:firebase_auth/firebase_auth.dart';

/// Turns a [FirebaseAuthException] into something worth showing a person.
///
/// Firebase's own `e.message` is written for developers ("The supplied auth
/// credential is malformed or has expired."), so the common cases get their
/// own wording. Anything unrecognised falls through to Firebase's text
/// rather than a useless generic — an unfamiliar-but-specific message beats
/// "Something went wrong".
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      // Deliberately identical for all three: saying "no account with that
      // email" would confirm to a stranger which emails are registered.
      return 'Wrong email or password.';
    case 'email-already-in-use':
      return 'That email already has an account. Try signing in.';
    case 'weak-password':
      return 'Use a password of at least 6 characters.';
    case 'invalid-email':
      return 'That does not look like an email address.';
    case 'network-request-failed':
      return 'No connection. Check your network and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a moment and try again.';
    case 'user-disabled':
      return 'This account has been disabled.';
    default:
      return e.message ?? 'Could not sign in. Please try again.';
  }
}
