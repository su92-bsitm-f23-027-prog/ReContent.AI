import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/api_client.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  bool _isRegistering = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthController>();
      if (_isRegistering) {
        await auth.register(
          email: _email.text,
          password: _password.text,
          firstName: _firstName.text,
          lastName: _lastName.text,
        );
      } else {
        await auth.login(_email.text, _password.text);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not connect. Check the API address and try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().signInWithGoogle();
    } on ApiException catch (error) {
      if (mounted) {
        final status =
            error.statusCode == null ? '' : ' (HTTP ${error.statusCode})';
        setState(
            () => _error = 'Server sign-in failed$status: ${error.message}');
      }
    } on FirebaseAuthException catch (error) {
      final code = error.code.toLowerCase();
      final message = code.contains('api-key-not-valid') ||
              code.contains('invalid-api-key')
          ? 'Firebase rejected the web API key. Use the exact apiKey from Project settings → General → your Web app, then restart Flutter.'
          : switch (error.code) {
              'popup-closed-by-user' => 'Google sign-in was cancelled.',
              'operation-not-allowed' =>
                'Enable Google as a sign-in provider in Firebase Authentication.',
              'unauthorized-domain' =>
                'Add this app address to Firebase Authentication’s authorized domains.',
              _ =>
                'Google sign-in failed (${error.code}): ${error.message ?? 'No details returned.'}',
            };
      if (mounted) setState(() => _error = message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Row(
          children: [
            if (wide) const Expanded(flex: 6, child: _WelcomePanel()),
            Expanded(
              flex: wide ? 5 : 1,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 32,
                    ),
                    child: _form(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (MediaQuery.sizeOf(context).width < 850) ...[
              const _BrandMark(),
              const SizedBox(height: 38),
            ],
            Text(
              _isRegistering ? 'Create your workspace' : 'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _isRegistering
                  ? 'Start turning your ideas into content.'
                  : 'Sign in to pick up where you left off.',
            ),
            const SizedBox(height: 28),
            if (_isRegistering) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              autofillHints: _isRegistering
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Enter your password.';
                if (_isRegistering && value.length < 10)
                  return 'Use at least 10 characters.';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegistering ? 'Create account' : 'Sign in'),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _signInWithGoogle,
                icon: const Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                label: const Text('Continue with Google'),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _isRegistering = !_isRegistering;
                          _error = null;
                        }),
                child: Text(
                  _isRegistering
                      ? 'Already have an account? Sign in'
                      : 'New to ReContent? Create an account',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF292545), Color(0xFF51499C), Color(0xFF7567DB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandMark(light: true),
          const Spacer(),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'One idea.\nMore ways to share.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Turn a video, conversation, or note into thoughtful content for every channel.',
            style: TextStyle(
              color: Colors.white.withOpacity(.78),
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 36),
          const _WorkflowPreview(),
          const Spacer(),
          Text(
            'Your content, organized around your ideas.',
            style: TextStyle(
              color: Colors.white.withOpacity(.65),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowPreview extends StatelessWidget {
  const _WorkflowPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        border: Border.all(color: Colors.white.withOpacity(.16)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          _WorkflowItem(icon: Icons.description_outlined, label: 'Source'),
          Expanded(
            child: Divider(color: Colors.white38, indent: 8, endIndent: 8),
          ),
          _WorkflowItem(icon: Icons.auto_awesome_outlined, label: 'Create'),
          Expanded(
            child: Divider(color: Colors.white38, indent: 8, endIndent: 8),
          ),
          _WorkflowItem(icon: Icons.send_outlined, label: 'Share'),
        ],
      ),
    );
  }
}

class _WorkflowItem extends StatelessWidget {
  const _WorkflowItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  light ? Colors.white.withOpacity(.15) : AppColors.violetSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: light ? Colors.white : AppColors.violet,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'ReContent',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: light ? Colors.white : AppColors.ink,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: light ? Colors.white70 : AppColors.violet,
            ),
          ),
        ],
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF9E3544), fontSize: 13),
        ),
      );
}
