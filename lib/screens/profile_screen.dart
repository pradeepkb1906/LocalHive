import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import '../widgets/role_picker.dart';
import 'provider_onboarding_screen.dart';

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
                              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.signedIn ? (s.userName ?? 'Member') : 'Guest',
                                style:
                                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                                s.signedIn
                                    ? (s.userPhone ?? 'Signed in')
                                    : 'Sign in to book services & track orders',
                                style: const TextStyle(
                                    fontSize: 13, color: LhColors.inkSecondary)),
                          ],
                        ),
                      ),
                      if (!s.signedIn)
                        TextButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const SignInScreen())),
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
                  ListTile(
                    leading: const IconTile(
                        icon: CupertinoIcons.briefcase_fill, color: LhColors.indigo, size: 32),
                    title: Text(
                        s.providerKycSubmitted ? 'Provider application' : 'Become a provider',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        s.providerKycSubmitted
                            ? '${s.providerBusinessName} — verification in review'
                            : 'List your services, store, or truck. Get paid securely.',
                        style:
                            const TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
                    trailing: s.providerKycSubmitted
                        ? const Icon(CupertinoIcons.clock, size: 18, color: LhColors.orange)
                        : const Icon(CupertinoIcons.chevron_right,
                            size: 18, color: LhColors.hairline),
                    onTap: s.providerKycSubmitted
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProviderOnboardingScreen())),
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
                        style: TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
                    trailing: const Icon(CupertinoIcons.chevron_right,
                        size: 18, color: LhColors.hairline),
                    onTap: () => showRolePicker(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              InsetGroup(
                header: 'About',
                children: const [
                  _LinkTile(icon: CupertinoIcons.doc_plaintext, title: 'Terms of Service'),
                  _LinkTile(icon: CupertinoIcons.shield_fill, title: 'Privacy Policy'),
                  _LinkTile(icon: CupertinoIcons.question_circle_fill, title: 'Help & Support'),
                ],
              ),
              if (s.signedIn) ...[
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    title: const Center(
                        child: Text('Sign Out',
                            style: TextStyle(
                                color: Color(0xFFFF3B30), fontWeight: FontWeight.w600))),
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
                    style: const TextStyle(fontSize: 12, color: LhColors.inkSecondary)),
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
  const _LinkTile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(icon: icon, color: LhColors.inkSecondary, size: 32),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 18, color: LhColors.hairline),
      onTap: () {},
    );
  }
}

/// Phone sign-in. With Firebase connected this sends a real SMS via
/// Firebase Auth (invisible reCAPTCHA on web); offline it falls back to a
/// demo mode that accepts any 6-digit code.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

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
  bool _registering = true;

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
      if (mounted) Navigator.pop(context);
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
    final err =
        await AppState.instance.verifyCode(_code.text.trim(), _name.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _toast(err);
    } else {
      if (_registering && mounted) {
        // New account: choose how they'll use the app (Airbnb-style).
        await showRolePicker(context, dismissible: false);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = AppState.instance.firebaseReady;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In'), actions: const [LocationChip()]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          const Icon(CupertinoIcons.person_crop_circle_fill, size: 64, color: LhColors.navy),
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
                style: const TextStyle(fontSize: 14, color: LhColors.inkSecondary)),
          ),
          const SizedBox(height: 20),
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Email'), icon: Icon(CupertinoIcons.envelope)),
                ButtonSegment(value: false, label: Text('Phone'), icon: Icon(CupertinoIcons.phone)),
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
              decoration: const InputDecoration(hintText: 'Email (e.g. you@gmail.com)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password (6+ characters)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _emailSubmit,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
              decoration:
                  const InputDecoration(hintText: 'US mobile number, e.g. 732 555 0123'),
            ),
            const SizedBox(height: 8),
            Text(
                connected
                    ? 'We’ll text you a 6-digit verification code.'
                    : 'Offline demo — any 6-digit code will be accepted.',
                style: const TextStyle(fontSize: 12, color: LhColors.inkSecondary)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send Code'),
            ),
          ] else ...[
            Text('Enter the 6-digit code sent to ${_phone.text}',
                style: const TextStyle(fontSize: 14, color: LhColors.inkSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(hintText: '••••••', counterText: ''),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
