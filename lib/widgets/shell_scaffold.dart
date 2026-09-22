import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/users_screen.dart';
import '../screens/bookings_screen.dart';
import '../screens/venues_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/coupons_screen.dart';
import '../screens/support_screen.dart';
import '../screens/content_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/audit_logs_screen.dart';
import '../screens/feature_flags_screen.dart';

class ShellScaffold extends StatefulWidget {
  final Widget body;
  const ShellScaffold({super.key, required this.body});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  _NavItem(this.label, this.icon, this.builder);
}

class _ShellScaffoldState extends State<ShellScaffold> {
  int _selected = 0;

  late final List<_NavItem> _items = [
    _NavItem('Dashboard', Icons.dashboard_outlined, () => const DashboardScreen()),
    _NavItem('Users', Icons.people_outline, () => const UsersScreen()),
    _NavItem('Bookings', Icons.event_note_outlined, () => const BookingsScreen()),
    _NavItem('Venues', Icons.location_city_outlined, () => const VenuesScreen()),
    _NavItem('Payments', Icons.account_balance_wallet_outlined, () => const PaymentsScreen()),
    _NavItem('Coupons', Icons.local_offer_outlined, () => const CouponsScreen()),
    _NavItem('Support', Icons.support_agent_outlined, () => const SupportScreen()),
    _NavItem('Content', Icons.article_outlined, () => const ContentScreen()),
    _NavItem('Notifications', Icons.notifications_outlined, () => const NotificationsScreen()),
    _NavItem('Audit Logs', Icons.history_outlined, () => const AuditLogsScreen()),
    _NavItem('Feature Flags', Icons.toggle_on_outlined, () => const FeatureFlagsScreen()),
  ];

  Future<void> _logout() async {
    await ApiClient.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _items[_selected];
    return Scaffold(
      body: Row(
        children: [
          Material(
            color: const Color(0xFF0F1E2E),
            child: SizedBox(
              width: 240,
              child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: Color(0xFF00B892), size: 28),
                      SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ACTIV', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        Text('Admin Panel', style: TextStyle(color: Color(0xFF8AA0B4), fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1F3A52), height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (int i = 0; i < _items.length; i++)
                        _drawerTile(i),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1F3A52), height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF8AA0B4)),
                  title: const Text('Logout', style: TextStyle(color: Color(0xFF8AA0B4), fontSize: 14)),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          ),
          Expanded(child: current.builder()),
        ],
      ),
    );
  }

  Widget _drawerTile(int index) {
    final item = _items[index];
    final active = index == _selected;
    return ListTile(
      leading: Icon(item.icon, color: active ? const Color(0xFF00B892) : const Color(0xFF8AA0B4), size: 20),
      title: Text(item.label, style: TextStyle(color: active ? Colors.white : const Color(0xFF8AA0B4), fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      selected: active,
      selectedTileColor: const Color(0xFF16293C),
      onTap: () => setState(() => _selected = index),
    );
  }
}