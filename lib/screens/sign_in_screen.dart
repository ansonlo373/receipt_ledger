import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:receipt_ledger/services/auth_service.dart';
import 'package:receipt_ledger/utils/auth_error_messages.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// One screen serves both jobs — the fields are identical, only the button
  /// and the call behind it differ.
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Runs [action], showing a spinner and surfacing any auth failure as
  /// readable text. On success the auth state stream swaps this screen out,
  /// so there's nothing to navigate to here.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } catch (e) {
      if (mounted)
        setState(() => _error = 'Could not sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text;
    final password = _passwordController.text;
    await _run(() async {
      if (_registering) {
        await widget.authService.registerWithEmail(
          email: email,
          password: password,
        );
      } else {
        await widget.authService.signInWithEmail(
          email: email,
          password: password,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Receipt Ledger',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _registering
                          ? 'Create an account to keep your receipts backed up.'
                          : 'Sign in to reach your receipts.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter your email';
                        if (!text.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _busy ? null : _submitEmail(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password';
                        }
                        // Only enforced when creating an account; an existing
                        // short password should still be allowed to sign in.
                        if (_registering && value.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submitEmail,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registering ? 'Create account' : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _registering = !_registering;
                              _error = null;
                            }),
                      child: Text(
                        _registering
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(widget.authService.signInWithGoogle),
                      child: const Text('Continue with Google'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
