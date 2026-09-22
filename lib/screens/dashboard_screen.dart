import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _revenue = [];
  List<Map<String, dynamic>> _bookingsByDay = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final overview = await AdminApi.getDashboardOverview();
      final revenue = await AdminApi.getDashboardRevenue();
      final bookings = await AdminApi.getDashboardBookings();
      if (mounted) {
        setState(() {
          _overview = overview as Map<String, dynamic>;
          _revenue = (revenue as List).cast<Map<String, dynamic>>();
          _bookingsByDay = (bookings as List).cast<Map<String, dynamic>>();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _rupees(BigInt paise) {
    final rupees = paise / BigInt.from(100);
    return '₹$rupees';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(children: [PageHeader(title: 'Dashboard', subtitle: 'Business overview'), Expanded(child: ErrorBox(message: _error!, onRetry: _load))]);
    }
    if (_overview == null) {
      return Column(children: [PageHeader(title: 'Dashboard', subtitle: 'Business overview'), const Expanded(child: LoadingBox())]);
    }
    final totals = _overview!['totals'] as Map<String, dynamic>;
    final revenue = totals['revenuePaise'] is BigInt ? totals['revenuePaise'] as BigInt : BigInt.parse(totals['revenuePaise'].toString());
    final refunds = totals['refundsPaise'] is BigInt ? totals['refundsPaise'] as BigInt : BigInt.parse(totals['refundsPaise'].toString());

    return Column(
      children: [
        const PageHeader(title: 'Dashboard', subtitle: 'Business overview'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: StatCard(label: 'Revenue', value: _rupees(revenue), icon: Icons.payments_outlined, color: const Color(0xFF00B892))),
                  const SizedBox(width: 14),
                  Expanded(child: StatCard(label: 'Users', value: totals['users'].toString(), icon: Icons.people_outline, color: const Color(0xFF2563EB))),
                  const SizedBox(width: 14),
                  Expanded(child: StatCard(label: 'Bookings', value: totals['bookings'].toString(), icon: Icons.event_note_outlined, color: const Color(0xFF7C3AED))),
                  const SizedBox(width: 14),
                  Expanded(child: StatCard(label: 'Venues', value: totals['venues'].toString(), icon: Icons.location_city_outlined, color: const Color(0xFFF59E0B))),
                  const SizedBox(width: 14),
                  Expanded(child: StatCard(label: 'Open Tickets', value: totals['openTickets'].toString(), icon: Icons.support_agent, color: const Color(0xFFD32F2F))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: StatCard(label: 'Active Users', value: totals['activeUsers'].toString(), icon: Icons.person_pin, color: const Color(0xFF0EA5E9))),
                  const SizedBox(width: 14),
                  Expanded(child: StatCard(label: 'Activities', value: totals['activities'].toString(), icon: Icons.fitness_center, color: const Color(0xFF14B8A6))),
                  const SizedBox(width: 14),
                  Expanded(child: StatCard(label: 'Refunds', value: _rupees(refunds), icon: Icons.currency_rupee, color: const Color(0xFFF97316))),
                  const SizedBox(width: 14),
                  Expanded(child: StatCard(label: 'Current Admin', value: ApiClient.adminEmail ?? '-', icon: Icons.admin_panel_settings, color: const Color(0xFF6366F1))),
                ],
              ),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: _RevenueChart(revenue: _revenue)),
                const SizedBox(width: 14),
                Expanded(child: _BookingSummary(data: _bookingsByDay)),
              ]),
              const SizedBox(height: 14),
              _RecentBookings(items: (_overview!['recentBookings'] as List).cast<Map<String, dynamic>>()),
            ]),
          ),
        ),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> revenue;
  const _RevenueChart({required this.revenue});

  @override
  Widget build(BuildContext context) {
    final values = revenue.map((e) => BigInt.parse(e['revenuePaise'].toString())).toList();
    final maxV = values.isEmpty ? BigInt.one : values.reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Revenue (last 30 days)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F1E2E))),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: revenue.isEmpty
                ? const Center(child: Text('No captured payments yet', style: TextStyle(color: Color(0xFF5A6B7B))))
                : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final v in values)
                      Expanded(
                        child: Tooltip(
                          message: '₹${(v / BigInt.from(100)).toString()}',
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B892).withValues(alpha: 0.75),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                            height: maxV == BigInt.zero ? 2.0 : (v * BigInt.from(170) / maxV).toDouble(),
                          ),
                        ),
                      ),
                  ]),
          ),
        ],
      ),
    ));
  }
}

class _BookingSummary extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _BookingSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final byStatus = <String, int>{};
    for (final row in data) {
      byStatus[row['status'] as String] = (byStatus[row['status'] as String] ?? 0) + row['count'] as int;
    }
    final statuses = byStatus.keys.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bookings by status (30d)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F1E2E))),
          const SizedBox(height: 14),
          if (statuses.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('No bookings yet', style: TextStyle(color: Color(0xFF5A6B7B)))))
          else
            for (final s in statuses)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  StatusBadge(status: s),
                  Text(byStatus[s].toString(), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F1E2E))),
                ]),
              ),
        ]),
      ),
    );
  }
}

class _RecentBookings extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _RecentBookings({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recent bookings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F1E2E))),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No bookings yet', style: TextStyle(color: Color(0xFF5A6B7B)))))
          else
            for (final item in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined, color: Color(0xFF00B892)),
                title: Text('${item['publicCode']}  •  ${item['venue']}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F1E2E))),
                subtitle: Text(item['userName'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B7B))),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('₹${(BigInt.parse(item['totalPaise'].toString()) / BigInt.from(100)).toString()}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F1E2E))),
                  const SizedBox(width: 10),
                  StatusBadge(status: item['status'] as String),
                ]),
              ),
        ]),
      ),
    );
  }
}