import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/data.dart';
import '../theme.dart';
import 'provider_onboarding_screen.dart';

/// The pitch to someone in San Francisco with a free hour.
///
/// Delivery is the part of LocalHive a neighbour can join today without owning
/// a business — no van, no commercial licence, no inventory. The people who
/// most need groceries brought to them are older or less mobile, and they are
/// the reason the "hand to the door" job pays more than a doorstep drop.
///
/// Everything claimed on this page is something the app actually does, which
/// is why the numbers come from [courierBaseFee] and [courierHelpBonus] rather
/// than from marketing copy that can drift away from the code.
class BecomeCourierScreen extends StatelessWidget {
  const BecomeCourierScreen({super.key});

  static void open(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const BecomeCourierScreen()));

  @override
  Widget build(BuildContext context) {
    final base = courierBaseFee.toStringAsFixed(2);
    final helped = (courierBaseFee + courierHelpBonus).toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(title: const Text('Deliver with LocalHive')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: LhColors.blue.withValues(alpha: 0.10),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.cube_box_fill,
                      size: 34, color: LhColors.blue),
                  const SizedBox(height: 12),
                  const Text('Got a free hour in San Francisco?',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          height: 1.25)),
                  const SizedBox(height: 8),
                  Text(
                      'Carry a grocery order a few blocks and earn \$$base. '
                      'When a neighbour needs the bags brought to their door '
                      '— stairs, heavy shop, or they are simply not steady on '
                      'their feet — the same run pays \$$helped.',
                      style: const TextStyle(fontSize: 14.5, height: 1.45)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          InsetGroup(
            header: 'How it works',
            children: const [
              _Step(
                  n: '1',
                  title: 'Open the job board when you are free',
                  body: 'Jobs appear the moment a store marks an order ready. '
                      'Nothing is assigned to you and nothing is expected of '
                      'you — you claim what suits you and ignore the rest.'),
              _Step(
                  n: '2',
                  title: 'Pick up, then walk, cycle or drive',
                  body: 'These are grocery bags going a few blocks, not a '
                      'cross-town shift. A bike or a pair of shoes is enough.'),
              _Step(
                  n: '3',
                  title: 'Hand over with a 4-digit code',
                  body: 'The customer reads you their code and the job is '
                      'done. It protects them from a wrong doorstep and you '
                      'from a disputed delivery.'),
              _Step(
                  n: '4',
                  title: 'Your fee is logged the moment you deliver',
                  body: 'Every completed job adds to the earnings total on '
                      'your job board, so you can see the day add up.'),
            ],
          ),
          const SizedBox(height: 10),
          InsetGroup(
            header: 'Why the extra for a hand to the door',
            children: [
              ListTile(
                leading: const IconTile(
                    icon: CupertinoIcons.hand_raised_fill,
                    color: LhColors.blue,
                    size: 34),
                title: const Text('An extra \$3.00 on those runs',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'A customer can tick "I need a hand to the door" at '
                    'checkout at no cost to them — the extra comes out of '
                    'LocalHive\'s cut, not their bill. The people most likely '
                    'to need help are the least able to pay more for it. You '
                    'see the request on the job before you claim it, so you '
                    'are never surprised at the door.',
                    style: const TextStyle(
                        fontSize: 13,
                        color: LhColors.inkSecondary,
                        height: 1.35)),
                isThreeLine: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          InsetGroup(
            header: 'What you need',
            children: const [
              _Need(text: '18 or over, and legally able to work in the US'),
              _Need(text: 'A phone with location switched on while delivering'),
              _Need(
                  text: 'Any way of getting around — walking counts in this '
                      'city'),
              _Need(
                  text: 'You work for yourself: you choose your hours, and no '
                      'one schedules you'),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProviderOnboardingScreen())),
            icon: const Icon(CupertinoIcons.arrow_right_circle_fill, size: 18),
            label: const Text('Sign up as a delivery partner'),
          ),
          const SizedBox(height: 12),
          const Text(
              'Delivery partners are independent contractors, not employees. '
              'You are paid per completed delivery. LocalHive does not '
              'guarantee a number of jobs, and there is no minimum shift.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: LhColors.inkSecondary, height: 1.4)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n, title, body;
  const _Step({required this.n, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          radius: 15,
          backgroundColor: LhColors.blue.withValues(alpha: 0.14),
          child: Text(n,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LhColors.blue)),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(body,
            style: const TextStyle(
                fontSize: 13, color: LhColors.inkSecondary, height: 1.35)),
        isThreeLine: true,
      );
}

class _Need extends StatelessWidget {
  final String text;
  const _Need({required this.text});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: const Icon(CupertinoIcons.checkmark_circle_fill,
            size: 19, color: LhColors.green),
        title: Text(text, style: const TextStyle(fontSize: 14, height: 1.3)),
      );
}
