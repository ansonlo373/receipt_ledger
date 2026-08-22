import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/utils/auth_error_messages.dart';

void main() {
  test('explains a wrong password without leaking which field was wrong', () {
    final message = authErrorMessage(
      FirebaseAuthException(code: 'invalid-credential'),
    );

    expect(message, 'Wrong email or password.');
  });

  test('gives the same message for a non-existent account', () {
    // Must not differ from the wrong-password message — a different reply
    // would tell a stranger which email addresses have accounts.
    final message = authErrorMessage(
      FirebaseAuthException(code: 'user-not-found'),
    );

    expect(message, 'Wrong email or password.');
  });

  test('tells the user to sign in when the email is already registered', () {
    final message = authErrorMessage(
      FirebaseAuthException(code: 'email-already-in-use'),
    );

    expect(message, 'That email already has an account. Try signing in.');
  });

  test('says what a strong enough password looks like', () {
    final message = authErrorMessage(
      FirebaseAuthException(code: 'weak-password'),
    );

    expect(message, 'Use a password of at least 6 characters.');
  });

  test('names the network as the problem when the request never lands', () {
    final message = authErrorMessage(
      FirebaseAuthException(code: 'network-request-failed'),
    );

    expect(message, 'No connection. Check your network and try again.');
  });

  test('falls back to Firebase own message for unrecognised codes', () {
    final message = authErrorMessage(
      FirebaseAuthException(code: 'something-new', message: 'Specific detail.'),
    );

    expect(message, 'Specific detail.');
  });

  test('falls back to a generic message when Firebase gives no message', () {
    final message = authErrorMessage(
      FirebaseAuthException(code: 'something-new'),
    );

    expect(message, 'Could not sign in. Please try again.');
  });
}
