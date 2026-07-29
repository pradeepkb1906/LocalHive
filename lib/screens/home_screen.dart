import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import 'delivery_jobs_screen.dart';
import 'provider_dashboard_screen.dart';
import 'provider_list_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  String _lastRole = 'customer';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final role = AppState.instance.role;
        if (role != _lastRole) {
          // Business users land on their dashboard; partners on deliveries.
          _lastRole = role;
          _tab = role == 'customer' ? 0 : 1;
        }
        final pages = switch (role) {
          'provider' => const [
              HomeTab(),
              ProviderDashboardScreen(),
              BookingsScreen(),
              ProfileScreen()
            ],
          'delivery' => const [
              HomeTab(),
              DeliveryJobsScreen(),
              BookingsScreen(),
              ProfileScreen()
            ],
          _ => const [HomeTab(), BookingsScreen(), ProfileScreen()],
        };
        if (_tab >= pages.length) _tab = 0;
        final roleTab = switch (role) {
          'provider' => NavigationDestination(
              icon: StreamBuilder<int>(
                stream: FirebaseService.instance.pendingOwnerJobsCount(),
                builder: (context, snap) => Badge(
                  isLabelVisible: (snap.data ?? 0) > 0,
                  label: Text('${snap.data ?? 0}'),
                  child: const Icon(CupertinoIcons.tray_full),
                ),
              ),
              selectedIcon: const Icon(CupertinoIcons.tray_full_fill),
              label: 'Dashboard',
            ),
          'delivery' => const NavigationDestination(
              icon: Icon(CupertinoIcons.cube_box),
              selectedIcon: Icon(CupertinoIcons.cube_box_fill),
              label: 'Deliveries',
            ),
          _ => null,
        };
        return Scaffold(
          body: pages[_tab],
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  const NavigationDestination(
                      icon: Icon(CupertinoIcons.house),
                      selectedIcon: Icon(CupertinoIcons.house_fill),
                      label: 'Home'),
                  if (roleTab != null) roleTab,
                  const NavigationDestination(
                      icon: Icon(CupertinoIcons.doc_text),
                      selectedIcon: Icon(CupertinoIcons.doc_text_fill),
                      label: 'Bookings'),
                  const NavigationDestination(
                      icon: Icon(CupertinoIcons.person),
                      selectedIcon: Icon(CupertinoIcons.person_fill),
                      label: 'Profile'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  void _open(BuildContext context, String category, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProviderListScreen(category: category, title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('LocalHive',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const Spacer(),
              const LocationChip(),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Trusted local services, stores & food.',
              style: TextStyle(color: LhColors.inkSecondary, fontSize: 15)),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search cleaners, groceries, biryani',
              prefixIcon: Icon(CupertinoIcons.search, color: LhColors.inkSecondary, size: 20),
            ),
            onTap: () {},
          ),
          const SizedBox(height: 16),
          // Owner call-to-action: signed-in providers see their live order
          // count and a one-tap path to the dashboard.
          StreamBuilder<int>(
            stream: FirebaseService.instance.pendingOwnerJobsCount(),
            builder: (context, snap) {
              final n = snap.data ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: LhColors.navy,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProviderDashboardScreen())),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: LhColors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$n',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    n == 1
                                        ? 'You have 1 order waiting!'
                                        : 'You have $n orders waiting!',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                const Text(
                                    'Tap to open your Provider Dashboard',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(CupertinoIcons.arrow_right_circle_fill,
                              color: Colors.white, size: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _CategoryCard(
            icon: CupertinoIcons.sparkles,
            tint: LhColors.indigo,
            title: 'Home Services',
            subtitle: 'Cleaners & handymen, background-checked. Book 3–4 hour visits.',
            onTap: () => _open(context, 'home_service', 'Home Services'),
          ),
          const SizedBox(height: 12),
          _CategoryCard(
            icon: CupertinoIcons.cart_fill,
            tint: LhColors.green,
            title: 'Indian Stores',
            subtitle: 'Groceries & essentials. Order ahead for pickup or delivery.',
            onTap: () => _open(context, 'indian_store', 'Indian Stores'),
          ),
          const SizedBox(height: 12),
          _CategoryCard(
            icon: CupertinoIcons.car_detailed,
            tint: LhColors.orange,
            title: 'Food Trucks',
            subtitle: 'Live locations. Skip the line with pre-orders.',
            onTap: () => _open(context, 'food_truck', 'Food Trucks'),
          ),
          const SizedBox(height: 28),
          InsetGroup(
            header: 'Why LocalHive',
            children: const [
              _TrustTile(
                  icon: CupertinoIcons.checkmark_seal_fill,
                  color: LhColors.blue,
                  title: 'Verified providers',
                  subtitle: 'Every provider is ID-verified; home-service pros are background-checked.'),
              _TrustTile(
                  icon: CupertinoIcons.lock_fill,
                  color: LhColors.green,
                  title: 'Protected payments',
                  subtitle: 'Your payment is held securely until the job is done.'),
              _TrustTile(
                  icon: CupertinoIcons.percent,
                  color: LhColors.navy,
                  title: 'Transparent pricing',
                  subtitle: 'A flat 12% platform fee, always shown before you pay.'),
            ],
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) {
              final s = AppState.instance;
              if (s.signedIn) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Sign in to book services and track orders.',
                            style: TextStyle(fontSize: 14, color: LhColors.inkSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SignInScreen())),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title, subtitle;
  final VoidCallback onTap;
  const _CategoryCard(
      {required this.icon, required this.tint, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconTile(icon: icon, color: tint),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(color: LhColors.inkSecondary, fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_right, size: 18, color: LhColors.hairline),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  const _TrustTile({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(icon: icon, color: color, size: 32),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 13, color: LhColors.inkSecondary, height: 1.3)),
    );
  }
}
