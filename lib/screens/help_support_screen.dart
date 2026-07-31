import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Help & Support in the shape US marketplace apps use: quick answers first,
/// grouped by what people are trying to do, with a clear way to reach a
/// human at the bottom.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const _FaqGroup(
            header: 'Orders & bookings',
            faqs: [
              _Faq(
                'Where is my order?',
                'Open the Bookings tab. Everything in progress is at the '
                    'top, newest first, with its live status — Placed, '
                    'Preparing, Ready, or Out for delivery. Delivery orders '
                    'show a Track button once a delivery partner is on the '
                    'way.',
              ),
              _Faq(
                'How do I cancel a booking?',
                'You can cancel a service request free of charge any time '
                    'before the business accepts it: open Bookings and tap '
                    'Cancel request on the booking. After a business has '
                    'accepted, contact them directly — their phone number '
                    'is on your booking confirmation messages.',
              ),
              _Faq(
                'What is the delivery OTP?',
                'Delivery orders include a 4-digit code shown in your '
                    'Bookings tab. Share it only with the delivery partner '
                    'when they hand over your order — it confirms the '
                    'delivery reached you.',
              ),
              _Faq(
                'The business declined my request. Was I charged?',
                'No. You never pay in advance on LocalHive, so a declined '
                    'or cancelled booking costs nothing. Pick another '
                    'nearby provider and rebook.',
              ),
            ],
          ),
          const _FaqGroup(
            header: 'Payments & fees',
            faqs: [
              _Faq(
                'How do I pay?',
                'In person, directly to the business, when the job is done '
                    'or the order is handed over — cash or card, whatever '
                    'the business accepts. LocalHive never collects card '
                    'details in the app.',
              ),
              _Faq(
                'What is the platform fee?',
                'A flat 12% platform fee, always itemised at checkout '
                    'before you confirm. The total you see at checkout is '
                    'the total you pay — no surprises on handover.',
              ),
            ],
          ),
          const _FaqGroup(
            header: 'Olivia voice assistant',
            faqs: [
              _Faq(
                'How do I talk to Olivia?',
                'Tap Ask Olivia, allow microphone access when your browser '
                    'asks, then hold the mic button and speak — "find me '
                    'tacos nearby" or "book a cleaner for tomorrow '
                    'morning". Olivia drafts the order and shows you a '
                    'confirmation card; nothing is placed until you '
                    'confirm it.',
              ),
              _Faq(
                'Olivia can\'t hear me.',
                'Check that your browser has microphone permission for '
                    'this site (look for the mic icon in the address bar). '
                    'On iPhone use Safari; on Android use Chrome. If you '
                    'denied permission earlier, re-enable it in site '
                    'settings and reload.',
              ),
            ],
          ),
          const _FaqGroup(
            header: 'For businesses & delivery partners',
            faqs: [
              _Faq(
                'How do I list my business?',
                'Profile → Become a provider. Complete the three-step '
                    'application — service details, availability, and '
                    'verification consents. Once approved, your listing '
                    'goes live and new orders appear on your Dashboard '
                    'tab with the customer\'s details and what to prepare.',
              ),
              _Faq(
                'How do deliveries work?',
                'Switch to delivery mode in Profile. Open jobs appear on '
                    'the Deliveries tab, newest first. Claim a job, pick '
                    'up the order, and confirm handover by entering the '
                    'customer\'s 4-digit OTP. The customer can watch your '
                    'position while you\'re on the way.',
              ),
            ],
          ),
          const SizedBox(height: 8),
          InsetGroup(
            header: 'Still need help?',
            children: const [
              ListTile(
                leading: IconTile(
                    icon: CupertinoIcons.envelope_fill,
                    color: LhColors.blue,
                    size: 32),
                title: Text('Email support',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'support@localhive.app — we reply within one business '
                    'day.',
                    style:
                        TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
              ),
              ListTile(
                leading: IconTile(
                    icon: CupertinoIcons.exclamationmark_shield_fill,
                    color: LhColors.orange,
                    size: 32),
                title: Text('Report a safety concern',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'For urgent safety issues during a service visit or '
                    'delivery, contact local emergency services first, '
                    'then email safety@localhive.app so we can act on the '
                    'account.',
                    style:
                        TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

class _FaqGroup extends StatelessWidget {
  final String header;
  final List<_Faq> faqs;
  const _FaqGroup({required this.header, required this.faqs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(header.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: LhColors.inkSecondary)),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < faqs.length; i++) ...[
                  ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    title: Text(faqs[i].question,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(faqs[i].answer,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: LhColors.inkSecondary)),
                    ],
                  ),
                  if (i != faqs.length - 1)
                    const Padding(
                        padding: EdgeInsets.only(left: 16), child: Divider()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
