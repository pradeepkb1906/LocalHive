import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../demo_accounts.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import 'legal_screen.dart';
import 'help_support_screen.dart';
import '../widgets/location_chip.dart';
import '../widgets/role_picker.dart';
import 'provider_onboarding_screen.dart';
import 'system_check_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final s = AppState.instance;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Row(
                children: [
                  Text('Profile',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5)),
                  const Spacer(),
                  const LocationChip(),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: LhColors.navy,
                        child: Text(
                          s.signedIn && (s.userName?.isNotEmpty ?? false)
                              ? s.userName!.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                s.signedIn ? (s.userName ?? 'Member') : 'Guest',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                                s.signedIn
                                    ? (s.userPhone ?? 'Signed in')
                                    : 'Sign in to book services & track orders',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: LhColors.inkSecondary)),
                          ],
                        ),
                      ),
                      if (!s.signedIn)
                        TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignInScreen())),
                          child: const Text('Sign In'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              InsetGroup(
                header: 'Earn with LocalHive',
                children: [
                  // Live application status straight from the review queue.
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: FirebaseService.instance.myApplicationStream(),
                    builder: (context, snap) {
                      final app = snap.data;
                      final status = app?['status'] as String?;
                      final (icon, color, title, sub) = switch (status) {
                        'approved' => (
                            CupertinoIcons.checkmark_seal_fill,
                            LhColors.green,
                            'Application approved',
                            '${app!['businessName']} is live — customers can book you.'
                          ),
                        'rejected' => (
                            CupertinoIcons.xmark_seal_fill,
                            const Color(0xFFFF3B30),
                            'Application declined',
                            '${app!['reviewNote'] ?? 'See message'} — tap to reapply.'
                          ),
                        'in_review' => (
                            CupertinoIcons.clock_fill,
                            LhColors.orange,
                            'Application under review',
                            '${app!['businessName']} — our team is verifying your details.'
                          ),
                        _ => (
                            CupertinoIcons.briefcase_fill,
                            LhColors.indigo,
                            'Become a provider',
                            'List your services, store, or truck. Get paid securely.'
                          ),
                      };
                      final canApply = status == null || status == 'rejected';
                      return ListTile(
                        leading: IconTile(icon: icon, color: color, size: 32),
                        title: Text(title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text(sub,
                            style: const TextStyle(
                                fontSize: 13, color: LhColors.inkSecondary)),
                        trailing: canApply
                            ? const Icon(CupertinoIcons.chevron_right,
                                size: 18, color: LhColors.hairline)
                            : null,
                        onTap: canApply
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ProviderOnboardingScreen()))
                            : null,
                      );
                    },
                  ),
                  ListTile(
                    leading: const IconTile(
                        icon: CupertinoIcons.arrow_2_squarepath,
                        color: LhColors.blue,
                        size: 32),
                    title: Text(
                        'Account type: ${switch (s.role) {
                          'provider' => 'Business owner',
                          'delivery' => 'Delivery partner',
                          _ => 'Customer',
                        }}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Switch between customer, business, and delivery modes.',
                        style: TextStyle(
                            fontSize: 13, color: LhColors.inkSecondary)),
                    trailing: const Icon(CupertinoIcons.chevron_right,
                        size: 18, color: LhColors.hairline),
                    onTap: () => showRolePicker(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              InsetGroup(
                header: 'About',
                children: [
                  _LinkTile(
                    icon: CupertinoIcons.doc_plaintext,
                    title: 'Terms of Service',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalScreen(
                          title: 'Terms of Service',
                          lastUpdated: legalLastUpdated,
                          sections: termsOfServiceSections,
                        ),
                      ),
                    ),
                  ),
                  _LinkTile(
                    icon: CupertinoIcons.shield_fill,
                    title: 'Privacy Policy',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalScreen(
                          title: 'Privacy Policy',
                          lastUpdated: legalLastUpdated,
                          sections: privacyPolicySections,
                        ),
                      ),
                    ),
                  ),
                  _LinkTile(
                    icon: CupertinoIcons.question_circle_fill,
                    title: 'Help & Support',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen()),
                    ),
                  ),
                  const _SystemCheckTile(),
                ],
              ),
              if (s.signedIn) ...[
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    title: const Center(
                        child: Text('Sign Out',
                            style: TextStyle(
                                color: Color(0xFFFF3B30),
                                fontWeight: FontWeight.w600))),
                    onTap: () => s.signOut(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: Text(
                    s.firebaseReady
                        ? 'LocalHive 0.2.0 · Connected'
                        : 'LocalHive 0.2.0 · Offline demo mode',
                    style: const TextStyle(
                        fontSize: 12, color: LhColors.inkSecondary)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  const _LinkTile({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(icon: icon, color: LhColors.inkSecondary, size: 32),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(CupertinoIcons.chevron_right,
          size: 18, color: LhColors.hairline),
      onTap: onTap,
    );
  }
}

/// Phone sign-in. With Firebase connected this sends a real SMS via
/// Firebase Auth (invisible reCAPTCHA on web); offline it falls back to a
/// demo mode that accepts any 6-digit code.
class SignInScreen extends StatefulWidget {
  /// Opens straight onto the Create Account form. Everywhere the user tapped
  /// something called "Sign In" this stays false — landing a returning user on
  /// a registration form is the wrong default, and it hides the demo logins.
  final bool startRegistering;
  const SignInScreen({super.key, this.startRegistering = false});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _emailMode = true;
  late bool _registering = widget.startRegistering;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _emailSubmit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (!email.contains('@') || pass.length < 6) {
      _toast('Enter a valid email and a password of at least 6 characters.');
      return;
    }
    if (_registering && _name.text.trim().isEmpty) {
      _toast('Enter your name.');
      return;
    }
    setState(() => _busy = true);
    final err = _registering
        ? await AppState.instance.signUpEmail(email, pass, _name.text.trim())
        : await AppState.instance.signInEmail(email, pass);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _toast(err);
    } else {
      if (_registering && mounted) {
        // New account: choose how they'll use the app (Airbnb-style).
        await showRolePicker(context, dismissible: false);
      }
      // Pushed as a dialog this closes itself; as the app's front door there
      // is nothing to pop — the root swaps to the app when auth changes.
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  Future<void> _forgotPassword() async {
    final ctl = TextEditingController(text: _email.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(CupertinoIcons.lock_rotation,
            color: LhColors.blue, size: 40),
        title: const Text('Reset your password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'We\'ll email you a secure link to choose a new password.',
                style: TextStyle(fontSize: 13.5, color: LhColors.inkSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Your email address'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: dialogButtonStyle(),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send Reset Link')),
        ],
      ),
    );
    if (ok != true) return;
    final email = ctl.text.trim();
    if (!email.contains('@')) {
      _toast('Enter a valid email address.');
      return;
    }
    setState(() => _busy = true);
    final err = await AppState.instance.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(err ??
        'If an account exists for $email, a reset link is on its way. '
            'Check your inbox and spam folder.');
  }

  Future<void> _sendCode() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      _toast('Enter your name and phone number.');
      return;
    }
    setState(() => _busy = true);
    final err = await AppState.instance.sendCode(_phone.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _toast(err);
    } else {
      setState(() => _codeSent = true);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      _toast('Enter the 6-digit code.');
      return;
    }
    setState(() => _busy = true);
    final err = await AppState.instance
        .verifyCode(_code.text.trim(), _name.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _toast(err);
    } else {
      if (_registering && mounted) {
        // New account: choose how they'll use the app (Airbnb-style).
        await showRolePicker(context, dismissible: false);
      }
      // Pushed as a dialog this closes itself; as the app's front door there
      // is nothing to pop — the root swaps to the app when auth changes.
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = AppState.instance.firebaseReady;
    return Scaffold(
      appBar:
          AppBar(title: const Text('Sign In'), actions: const [LocationChip()]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          const Icon(CupertinoIcons.person_crop_circle_fill,
              size: 64, color: LhColors.navy),
          const SizedBox(height: 12),
          const Center(
            child: Text('Welcome to LocalHive',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
                _emailMode
                    ? 'Use your email (e.g. Gmail) and a password you set'
                    : 'Sign in with your phone number',
                style: const TextStyle(
                    fontSize: 14, color: LhColors.inkSecondary)),
          ),
          const SizedBox(height: 20),
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('Email'),
                    icon: Icon(CupertinoIcons.envelope)),
                ButtonSegment(
                    value: false,
                    label: Text('Phone'),
                    icon: Icon(CupertinoIcons.phone)),
              ],
              selected: {_emailMode},
              onSelectionChanged: (s) => setState(() => _emailMode = s.first),
            ),
          ),
          const SizedBox(height: 20),
          if (_emailMode) ...[
            if (_registering) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Full name'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(hintText: 'Email (e.g. you@gmail.com)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration:
                  const InputDecoration(hintText: 'Password (6+ characters)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _emailSubmit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_registering ? 'Create Account' : 'Sign In'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _registering = !_registering),
              child: Text(_registering
                  ? 'Already have an account? Sign in'
                  : 'New here? Create an account'),
            ),
            if (!_registering)
              TextButton(
                onPressed: _busy ? null : _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            if (kShowDemoAccounts && !_registering) ...[
              const SizedBox(height: 18),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('TRY A DEMO ACCOUNT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: LhColors.inkSecondary)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 4),
              const Text(
                  'Tap Use to fill the form, then Sign In. Each login opens '
                  'the app in that role.',
                  style: TextStyle(fontSize: 12, color: LhColors.inkSecondary)),
              const SizedBox(height: 10),
              for (final a in demoAccounts)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        IconTile(icon: a.icon, color: a.color, size: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.label,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 1),
                              Text(a.description,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: LhColors.inkSecondary)),
                              const SizedBox(height: 3),
                              Text('${a.email}  ·  ${a.password}',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: LhColors.ink)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 66,
                          height: 34,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _email.text = a.email;
                                      _password.text = a.password;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                '${a.label} credentials filled — tap Sign In.'),
                                            duration:
                                                const Duration(seconds: 2)));
                                  },
                            style: compactButtonStyle(),
                            child: const Text('Use'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                  'Demo logins are shared test accounts — remove them before '
                  'launching publicly.',
                  style: TextStyle(fontSize: 11, color: LhColors.inkSecondary)),
            ],
          ] else if (!_codeSent) ...[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  hintText: 'US mobile number, e.g. 732 555 0123'),
            ),
            const SizedBox(height: 8),
            Text(
                connected
                    ? 'We’ll text you a 6-digit verification code.'
                    : 'Offline demo — any 6-digit code will be accepted.',
                style: const TextStyle(
                    fontSize: 12, color: LhColors.inkSecondary)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send Code'),
            ),
          ] else ...[
            Text('Enter the 6-digit code sent to ${_phone.text}',
                style: const TextStyle(
                    fontSize: 14, color: LhColors.inkSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration:
                  const InputDecoration(hintText: '••••••', counterText: ''),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify & Sign In'),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _codeSent = false),
              child: const Text('Change number'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SystemCheckTile extends StatelessWidget {
  const _SystemCheckTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const IconTile(
          icon: CupertinoIcons.checkmark_shield,
          color: LhColors.green,
          size: 32),
      title: const Text('System check',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: const Text('Verify the app is connected and every flow works',
          style: TextStyle(fontSize: 12.5, color: LhColors.inkSecondary)),
      trailing: const Icon(CupertinoIcons.chevron_right,
          size: 18, color: LhColors.hairline),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SystemCheckScreen())),
    );
  }
}
