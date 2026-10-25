import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../ui.dart';
import '../validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _isSignUp = false;
  bool _busy = false;
  bool _hidePassword = true;
  // Show errors live only after the first submit attempt.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  String _role = 'user';
  String _vendorType = 'canteen';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_isSignUp) {
        await AuthService.instance.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          role: _role,
          vendorType: _vendorType,
        );
      } else {
        await AuthService.instance.signIn(_email.text, _password.text);
      }
    } on FirebaseAuthException catch (e) {
      _snack(_authMessage(e));
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Turns Firebase error codes into plain-language messages.
  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Try signing in.';
      case 'weak-password':
        return 'That password is too weak. Choose a stronger one.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  void _toggleMode() {
    _formKey.currentState?.reset();
    _confirm.clear();
    setState(() {
      _isSignUp = !_isSignUp;
      _autovalidate = AutovalidateMode.disabled;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.volunteer_activism, size: 56, color: cs.primary),
                    const SizedBox(height: 8),
                    Text('FoodLink',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Rescue surplus food near you',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 28),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _name,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        maxLength: 50,
                        decoration: fieldDeco('Name / Outlet name',
                                hint: 'e.g. Priya Sharma or Hostel Mess',
                                icon: Icons.person_outline)
                            .copyWith(counterText: ''),
                        validator: (v) =>
                            Validators.text(v, field: 'Name', min: 2, max: 50),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                      decoration: fieldDeco('Email',
                          hint: 'name@example.com', icon: Icons.email_outlined),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction:
                          _isSignUp ? TextInputAction.next : TextInputAction.done,
                      autofillHints: [
                        _isSignUp ? AutofillHints.newPassword : AutofillHints.password
                      ],
                      onFieldSubmitted: (_) {
                        if (!_isSignUp && !_busy) _submit();
                      },
                      decoration: fieldDeco(
                        'Password',
                        hint: _isSignUp ? 'Create a password' : 'Enter your password',
                        helper: _isSignUp
                            ? 'At least 8 characters, with a letter and a number'
                            : null,
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          tooltip: _hidePassword ? 'Show password' : 'Hide password',
                          icon: Icon(_hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: _isSignUp
                          ? Validators.newPassword
                          : Validators.passwordPresent,
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _hidePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_busy) _submit();
                        },
                        decoration: fieldDeco('Confirm password',
                            hint: 'Re-enter your password', icon: Icons.lock_outline),
                        validator: (v) => Validators.confirmPassword(v, _password.text),
                      ),
                    ],
                    if (_isSignUp) ...[
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'user',
                              label: Text('I want food'),
                              icon: Icon(Icons.person)),
                          ButtonSegment(
                              value: 'vendor',
                              label: Text('I have surplus'),
                              icon: Icon(Icons.storefront)),
                        ],
                        selected: {_role},
                        onSelectionChanged: (s) => setState(() => _role = s.first),
                      ),
                      if (_role == 'vendor') ...[
                        const SizedBox(height: 12),
                        DropdownMenu<String>(
                          initialSelection: _vendorType,
                          expandedInsets: EdgeInsets.zero,
                          label: const Text('Vendor type'),
                          dropdownMenuEntries: const [
                            DropdownMenuEntry(value: 'canteen', label: 'College canteen / mess'),
                            DropdownMenuEntry(value: 'restaurant', label: 'Restaurant'),
                            DropdownMenuEntry(value: 'bakery', label: 'Bakery'),
                            DropdownMenuEntry(value: 'dairy', label: 'Dairy / store'),
                          ],
                          onSelected: (v) => setState(() => _vendorType = v ?? 'canteen'),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isSignUp ? 'Create account' : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _toggleMode,
                      child: Text(_isSignUp
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account'),
                    ),
                  ],
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
