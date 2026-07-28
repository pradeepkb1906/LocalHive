import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
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
              Text('Profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -0.5)),
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
  bool _codeSent = false;
  bool _busy = false;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = AppState.instance.firebaseReady;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
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
          const Center(
            child: Text('Sign in with your phone number',
                style: TextStyle(fontSize: 14, color: LhColors.inkSecondary)),
          ),
          const SizedBox(height: 28),
          if (!_codeSent) ...[
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
