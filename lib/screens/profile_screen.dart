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
                          s.signedIn ? s.userName!.substring(0, 1).toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.signedIn ? s.userName! : 'Guest',
                                style:
                                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                                s.signedIn
                                    ? s.userPhone!
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
              const Center(
                child: Text('LocalHive 0.1.0 · Made in the USA',
                    style: TextStyle(fontSize: 12, color: LhColors.inkSecondary)),
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

/// Mock phone sign-in. Swapped for Firebase Auth phone verification in the
/// production milestone; the two-step UX (phone → code) stays identical.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _codeSent = false;
  final _code = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
              decoration: const InputDecoration(hintText: 'Mobile number'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter your name and phone number.')));
                  return;
                }
                setState(() => _codeSent = true);
              },
              child: const Text('Continue'),
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
            const SizedBox(height: 8),
            const Text('Demo: any 6 digits work. Real SMS verification arrives with Firebase.',
                style: TextStyle(fontSize: 12, color: LhColors.inkSecondary)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (_code.text.trim().length != 6) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Enter the 6-digit code.')));
                  return;
                }
                AppState.instance.signIn(_name.text.trim(), _phone.text.trim());
                Navigator.pop(context);
              },
              child: const Text('Verify & Sign In'),
            ),
          ],
        ],
      ),
    );
  }
}
