import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

/// Three-step "Become a provider" wizard: type → business details → KYC.
/// The KYC step is a placeholder for Stripe Identity + Checkr; the collected
/// fields match what those services will need.
class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  State<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  int _step = 0;
  String? _type;
  final _businessName = TextEditingController();
  final _city = TextEditingController();
  bool _agreeContractor = false;
  bool _agreeKyc = false;

  static const _types = [
    ('home_service', CupertinoIcons.sparkles, LhColors.indigo, 'Home services',
        'Cleaning, handyman work, and other in-home services'),
    ('indian_store', CupertinoIcons.cart_fill, LhColors.green, 'Indian store',
        'Grocery or retail store with pickup / delivery orders'),
    ('food_truck', CupertinoIcons.car_detailed, LhColors.orange, 'Food truck',
        'Mobile food business with live location and pre-orders'),
  ];

  void _next() {
    if (_step == 0 && _type == null) {
      _toast('Choose what you want to offer.');
      return;
    }
    if (_step == 1 && (_businessName.text.trim().isEmpty || _city.text.trim().isEmpty)) {
      _toast('Enter your business name and city.');
      return;
    }
    if (_step == 2) {
      if (!_agreeContractor || !_agreeKyc) {
        _toast('Please review and accept both items to continue.');
        return;
      }
      AppState.instance.submitProviderApplication(
          type: _type!, businessName: _businessName.text.trim());
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(CupertinoIcons.checkmark_seal_fill, color: LhColors.green, size: 44),
          title: const Text('Application submitted'),
          content: const Text(
              'Identity verification and background screening open next. In this demo the '
              'application is marked "in review" — production connects Stripe Identity and Checkr here.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _step++);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Provider')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i <= _step ? LhColors.blue : LhColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_step == 0) ...[
                  const Text('What do you offer?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Pick the category that fits your business.',
                      style: TextStyle(fontSize: 14, color: LhColors.inkSecondary)),
                  const SizedBox(height: 20),
                  ..._types.map((t) {
                    final selected = _type == t.$1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: selected ? LhColors.blue : LhColors.hairline,
                              width: selected ? 2 : 0.5),
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: IconTile(icon: t.$2, color: t.$3),
                          title: Text(t.$4,
                              style:
                                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          subtitle: Text(t.$5,
                              style: const TextStyle(
                                  fontSize: 13, color: LhColors.inkSecondary)),
                          trailing: selected
                              ? const Icon(CupertinoIcons.checkmark_circle_fill,
                                  color: LhColors.blue)
                              : const Icon(CupertinoIcons.circle, color: LhColors.hairline),
                          onTap: () => setState(() => _type = t.$1),
                        ),
                      ),
                    );
                  }),
                ] else if (_step == 1) ...[
                  const Text('Your business',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Shown to customers on your listing.',
                      style: TextStyle(fontSize: 14, color: LhColors.inkSecondary)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _businessName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'Business or display name (e.g., "Maria\'s Cleaning")'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'City, State (e.g., Edison, NJ)'),
                  ),
                ] else ...[
                  const Text('Verification',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                      'US law and LocalHive policy require identity verification before you can accept jobs.',
                      style: TextStyle(fontSize: 14, color: LhColors.inkSecondary)),
                  const SizedBox(height: 20),
                  InsetGroup(
                    header: 'What happens next',
                    children: const [
                      ListTile(
                        leading: IconTile(
                            icon: CupertinoIcons.person_badge_plus_fill,
                            color: LhColors.blue,
                            size: 32),
                        title: Text('Identity check (KYC)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Government ID + selfie via Stripe Identity. Also sets up your secure payout account.',
                            style: TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
                      ),
                      ListTile(
                        leading: IconTile(
                            icon: CupertinoIcons.doc_checkmark_fill,
                            color: LhColors.green,
                            size: 32),
                        title: Text('Background check',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Home-service providers only. FCRA-compliant screening with your written consent.',
                            style: TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _agreeContractor,
                    onChanged: (v) => setState(() => _agreeContractor = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                        'I understand I operate as an independent business, responsible for my own licenses, permits, and taxes.',
                        style: TextStyle(fontSize: 13, height: 1.35)),
                  ),
                  CheckboxListTile(
                    value: _agreeKyc,
                    onChanged: (v) => setState(() => _agreeKyc = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                        'I consent to identity verification and (for home services) a background check.',
                        style: TextStyle(fontSize: 13, height: 1.35)),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _next,
                child: Text(_step == 2 ? 'Submit Application' : 'Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
