import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user =
        context.read<AuthController>().user ?? const <String, dynamic>{};
    _firstName = TextEditingController(
      text: user['first_name'] as String? ?? '',
    );
    _lastName = TextEditingController(text: user['last_name'] as String? ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().api.patch('auth/me/', {
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
      });
      await context.read<AuthController>().refreshProfile();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthController>().user ?? const <String, dynamic>{};
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
      children: [
        const SectionHeading(
          title: 'Settings',
          subtitle: 'Manage your profile and account session.',
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                const Text('Your profile details are private to your account.'),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  readOnly: true,
                  initialValue: user['email'] as String? ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  InlineError(message: _error!),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PrimaryAction(
                    label: 'Save profile',
                    icon: Icons.check_rounded,
                    onPressed: _save,
                    busy: _busy,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Session', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              const Text(
                'Your current sign-in token expires after 14 days. Signing in again starts a fresh session.',
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => context.read<AuthController>().logout(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out of this account'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
