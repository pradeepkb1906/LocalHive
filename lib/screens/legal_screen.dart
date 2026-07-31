import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// A titled legal document rendered as scrollable sections — the standard
/// shape of Terms and Privacy pages in US marketplace apps. Content lives in
/// [termsOfServiceSections] and [privacyPolicySections] below so the words
/// can be reviewed and edited without touching layout code.
class LegalScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text('Last updated: $lastUpdated',
              style:
                  const TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
          const SizedBox(height: 20),
          for (final s in sections) ...[
            if (s.heading.isNotEmpty) ...[
              Text(s.heading,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
            ],
            Text(s.body,
                style: const TextStyle(
                    fontSize: 14, height: 1.55, color: LhColors.ink)),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}

const legalLastUpdated = 'July 31, 2026';

/// Terms of Service in the standard language of US food-delivery,
/// home-service and grocery marketplace apps, adapted to how LocalHive
/// actually works: we connect people with independent local businesses, and
/// every payment is made in person, directly to the business.
const termsOfServiceSections = [
  LegalSection(
    '1. Agreement to Terms',
    'These Terms of Service ("Terms") govern your access to and use of the '
        'LocalHive application and related services (collectively, the '
        '"Services"), operated by LocalHive ("LocalHive," "we," "us," or '
        '"our"). By creating an account, placing an order, booking a '
        'service, or otherwise using the Services, you agree to be bound by '
        'these Terms. If you do not agree, do not use the Services.',
  ),
  LegalSection(
    '2. What LocalHive Is (and Is Not)',
    'LocalHive is a technology platform that connects consumers with '
        'independent local businesses — home-service professionals, grocery '
        'and retail stores, food trucks — and with independent delivery '
        'partners. The businesses and delivery partners on LocalHive are '
        'independent third parties. They are not employed by LocalHive, and '
        'LocalHive does not itself provide cleaning, repair, food '
        'preparation, retail, or delivery services. LocalHive does not '
        'guarantee the quality, safety, legality, or timeliness of services '
        'or goods provided by businesses on the platform.',
  ),
  LegalSection(
    '3. Eligibility and Accounts',
    'You must be at least 18 years old to use the Services. You agree to '
        'provide accurate, current, and complete information when creating '
        'an account and to keep it up to date. You are responsible for all '
        'activity that occurs under your account and for keeping your '
        'credentials confidential. Notify us immediately of any '
        'unauthorized use of your account.',
  ),
  LegalSection(
    '4. Orders and Bookings',
    'When you place an order or request a service visit, you are making an '
        'offer to the business, which the business may accept or decline. '
        'A booking is confirmed only when the business accepts it. Quoted '
        'times (preparation, arrival, and delivery windows) are estimates. '
        'You agree to provide a safe, accurate service or delivery address '
        'and to be reachable at the phone number on your account.',
  ),
  LegalSection(
    '5. Payments and Fees',
    'LocalHive does not process payments and does not collect or store '
        'card details. You pay the business directly, in person, when the '
        'job is done or the order is handed over. The total shown at '
        'checkout — including item prices, a 12% platform fee, and any '
        'delivery fee — is the amount you agree to pay the business. '
        'Prices are set by each business and may change; the price shown '
        'when you place an order is the price for that order.',
  ),
  LegalSection(
    '6. Cancellations',
    'You may cancel a service request free of charge at any time before '
        'the business accepts it, directly from the Bookings tab. Once a '
        'business has accepted a booking or begun preparing an order, '
        'cancellation is at the business\'s discretion. Businesses may '
        'decline or cancel a booking, in which case you owe nothing. '
        'Repeated no-shows or abusive cancellations may result in account '
        'suspension.',
  ),
  LegalSection(
    '7. Delivery Orders',
    'Delivery orders may include a one-time confirmation code (OTP) shown '
        'in your Bookings tab. Share it only with the delivery partner at '
        'handover — it is your proof of delivery. You are responsible for '
        'being available at the delivery address; goods left as instructed '
        'or handed over against your OTP are considered delivered.',
  ),
  LegalSection(
    '8. Business Owners and Delivery Partners',
    'If you list a business or deliver through LocalHive, you represent '
        'that you hold all licenses, permits, and insurance required for '
        'your work; that the information in your listing is accurate; and '
        'that you will honor accepted bookings and quoted prices. You are '
        'an independent business, not an employee, agent, or joint '
        'venturer of LocalHive, and you are solely responsible for your '
        'taxes, equipment, and compliance with applicable law, including '
        'food-safety and consumer-protection rules.',
  ),
  LegalSection(
    '9. Verification and Background Checks',
    'LocalHive may verify business identity and may facilitate background '
        'screening of home-service professionals through third-party '
        'services. Verification badges indicate that a check was performed '
        'at a point in time; they are not a guarantee of future conduct. '
        'Always use your own judgment when admitting anyone into your home.',
  ),
  LegalSection(
    '10. Acceptable Use',
    'You agree not to: misrepresent your identity; harass, threaten, or '
        'discriminate against customers, businesses, or delivery partners; '
        'place fraudulent orders; circumvent the platform to avoid fees '
        'after connecting through it; scrape, reverse engineer, or '
        'interfere with the Services; or use the Services for any unlawful '
        'purpose. We may suspend or terminate accounts that violate these '
        'Terms.',
  ),
  LegalSection(
    '11. Communications',
    'By using the Services you consent to receive transactional messages '
        '(SMS, WhatsApp, email, and in-app notifications) about your '
        'orders and bookings — for example when a business accepts your '
        'booking or a delivery is on its way. Message and data rates may '
        'apply. These messages are part of the Services and are not '
        'marketing.',
  ),
  LegalSection(
    '12. Olivia Voice Assistant',
    'Olivia is an AI assistant that can help you find businesses and '
        'assemble orders by voice. Olivia only drafts — no order or '
        'booking is placed until you review and confirm it on screen. '
        'AI responses may contain errors; always check the confirmation '
        'card before confirming.',
  ),
  LegalSection(
    '13. Content and Intellectual Property',
    'The Services, including software, design, text, and logos, are owned '
        'by LocalHive or its licensors and are protected by law. We grant '
        'you a limited, non-exclusive, revocable license to use the app '
        'for personal, non-commercial purposes (or, for businesses, to '
        'manage your listings and orders). Content you submit (such as a '
        'business listing) remains yours; you grant us a license to '
        'display it in the Services.',
  ),
  LegalSection(
    '14. Disclaimers',
    'THE SERVICES ARE PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT '
        'WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING '
        'WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, '
        'AND NON-INFRINGEMENT. LOCALHIVE DOES NOT WARRANT THAT THE '
        'SERVICES WILL BE UNINTERRUPTED OR ERROR-FREE, OR MAKE ANY '
        'WARRANTY AS TO GOODS OR SERVICES PROVIDED BY INDEPENDENT '
        'BUSINESSES.',
  ),
  LegalSection(
    '15. Limitation of Liability',
    'TO THE MAXIMUM EXTENT PERMITTED BY LAW, LOCALHIVE WILL NOT BE LIABLE '
        'FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE '
        'DAMAGES, OR FOR ANY LOSS ARISING FROM GOODS OR SERVICES PROVIDED '
        'BY INDEPENDENT BUSINESSES OR DELIVERY PARTNERS. IN NO EVENT WILL '
        'LOCALHIVE\'S TOTAL LIABILITY FOR ANY CLAIM EXCEED THE GREATER OF '
        'ONE HUNDRED DOLLARS (\$100) OR THE PLATFORM FEES YOU PAID IN THE '
        'SIX MONTHS BEFORE THE CLAIM AROSE. Some jurisdictions do not '
        'allow certain limitations, so parts of this section may not apply '
        'to you.',
  ),
  LegalSection(
    '16. Indemnification',
    'You agree to indemnify and hold harmless LocalHive and its officers, '
        'employees, and agents from claims arising out of your use of the '
        'Services, your violation of these Terms, or your violation of any '
        'law or the rights of a third party.',
  ),
  LegalSection(
    '17. Dispute Resolution and Governing Law',
    'These Terms are governed by the laws of the State of New Jersey, '
        'without regard to conflict-of-law rules. Before filing a claim, '
        'you agree to contact us through Help & Support and give us 30 '
        'days to work with you to resolve the dispute informally. Any '
        'dispute that cannot be resolved informally will be brought in the '
        'state or federal courts located in New Jersey, and you consent to '
        'their jurisdiction. Nothing in this section prevents either party '
        'from bringing a qualifying claim in small-claims court.',
  ),
  LegalSection(
    '18. Changes and Termination',
    'We may update these Terms from time to time; the "Last updated" date '
        'above reflects the current version. Material changes will be '
        'communicated in the app, and continued use after changes take '
        'effect constitutes acceptance. You may stop using the Services or '
        'delete your account at any time; we may suspend or terminate '
        'access for violations of these Terms.',
  ),
  LegalSection(
    '19. Contact',
    'Questions about these Terms? Reach us any time through Help & '
        'Support in the app or by email at support@localhive.app.',
  ),
];

/// Privacy Policy in the standard shape of US marketplace apps, describing
/// only what LocalHive actually collects and does. No ads, no selling data.
const privacyPolicySections = [
  LegalSection(
    '',
    'This Privacy Policy explains what information LocalHive ("we," "us") '
        'collects when you use our app and services, how we use and share '
        'it, and the choices you have. By using LocalHive you agree to the '
        'practices described here.',
  ),
  LegalSection(
    '1. Information We Collect',
    'Account information — your name, email address, phone number, and '
        'password (stored in hashed form by our authentication provider).\n\n'
        'Order and booking details — the items you order, services you '
        'book, service and delivery addresses you enter, chosen dates and '
        'times, and your order history.\n\n'
        'Location — with your permission, your device\'s approximate or '
        'precise location, used to show nearby businesses, set your '
        'location chip, and (for delivery partners who opt in) share live '
        'position with the customer during an active delivery. If you '
        'decline, we fall back to an approximate location based on your '
        'network.\n\n'
        'Microphone and voice — if you use Olivia, audio is captured only '
        'while you hold the talk button, converted to text to understand '
        'your request, and used to respond. We do not use your voice for '
        'advertising and we do not sell it.\n\n'
        'Device and usage information — basic technical data such as app '
        'version, device type, and diagnostic logs that help us keep the '
        'Services working.',
  ),
  LegalSection(
    '2. How We Use Information',
    'We use your information to: create and secure your account; show you '
        'nearby businesses; place and manage your orders and bookings; '
        'send transactional notifications (SMS, WhatsApp, email, in-app) '
        'about your orders; enable delivery handoff and tracking; provide '
        'customer support; prevent fraud and abuse; and improve the '
        'Services. We do not use your personal information for '
        'third-party advertising, and we do not sell it.',
  ),
  LegalSection(
    '3. How We Share Information',
    'With businesses and delivery partners — to fulfill your order we '
        'share what they need to do the job: your name, the order '
        'contents, the service or delivery address, and a contact phone '
        'number. Delivery partners see the delivery address and order '
        'contents but not what you paid.\n\n'
        'With service providers — we use trusted vendors to run the '
        'platform: Google Firebase (authentication, database, hosting), '
        'Twilio (SMS and WhatsApp notifications), Cloudflare (secure '
        'relay for Olivia), Groq (processing of Olivia voice requests), '
        'and OpenStreetMap services (maps, geocoding, and nearby-places '
        'search). These providers process data only to provide their '
        'service to us.\n\n'
        'For legal reasons — we may disclose information if required by '
        'law, or to protect the rights, safety, or property of users, '
        'LocalHive, or the public.\n\n'
        'We never sell your personal information, and we do not share it '
        'with data brokers.',
  ),
  LegalSection(
    '4. Your Choices',
    'Location and microphone permissions can be granted or revoked at any '
        'time in your device or browser settings; the app keeps working '
        'with reduced functionality. You can review your bookings and '
        'order history in the app. To access, correct, or delete your '
        'account data, contact us through Help & Support — we will '
        'respond within 30 days.',
  ),
  LegalSection(
    '5. Data Retention and Security',
    'We keep your account data while your account is active, and order '
        'records as needed for support, dispute resolution, and legal '
        'compliance. We protect data in transit with encryption (HTTPS) '
        'and restrict access with per-user security rules; API keys for '
        'AI processing are held server-side and never shipped in the app. '
        'No system is perfectly secure — please use a strong, unique '
        'password.',
  ),
  LegalSection(
    '6. Children',
    'LocalHive is not directed to children, and you must be 18 or older '
        'to use it. We do not knowingly collect personal information from '
        'children under 13. If you believe a child has provided us '
        'personal information, contact us and we will delete it.',
  ),
  LegalSection(
    '7. Your State Privacy Rights',
    'Depending on where you live (for example, California, Colorado, '
        'Connecticut, Texas, or Virginia), you may have rights to know '
        'what personal information we hold about you, to correct or '
        'delete it, and to opt out of its sale or sharing for targeted '
        'advertising. LocalHive does not sell personal information or '
        'share it for targeted advertising. To exercise any right, '
        'contact us through Help & Support; we will not discriminate '
        'against you for doing so.',
  ),
  LegalSection(
    '8. Changes to This Policy',
    'We may update this Privacy Policy from time to time. The "Last '
        'updated" date above reflects the current version, and material '
        'changes will be communicated in the app.',
  ),
  LegalSection(
    '9. Contact Us',
    'Privacy questions or requests: Help & Support in the app, or email '
        'privacy@localhive.app.',
  ),
];
