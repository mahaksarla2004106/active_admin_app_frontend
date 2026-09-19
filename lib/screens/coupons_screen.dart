import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  String? _status;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, String>{'page': '$_page', 'limit': '15'};
      if (_status != null) query['status'] = _status!;
      final result = await ApiClient.request('GET', '/admin/coupons', query: query);
      final data = result as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _items = (data['items'] as List).cast<Map<String, dynamic>>();
          _total = data['total'] as int;
          _totalPages = data['totalPages'] as int;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _setStatus(Map<String, dynamic> coupon, String status) async {
    try {
      await ApiClient.request('PATCH', '/admin/coupons/${coupon['id']}/status', body: {'status': status});
      showSnack(context, 'Coupon ${status == 'ACTIVE' ? 'activated' : 'deactivated'}');
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, error: true);
    }
  }

  void _create() {
    final code = TextEditingController();
    final percent = TextEditingController();
    final amount = TextEditingController();
    final maxRedemptions = TextEditingController();
    final days = TextEditingController(text: '30');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New coupon'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
            const SizedBox(height: 10),
            TextField(controller: percent, decoration: const InputDecoration(labelText: 'Percent off (1-100)'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: amount, decoration: const InputDecoration(labelText: 'OR amount off (₹)'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: maxRedemptions, decoration: const InputDecoration(labelText: 'Max redemptions (blank = unlimited)'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: days, decoration: const InputDecoration(labelText: 'Valid for (days)'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            const Text('Provide either percent OR amount, not both.', style: TextStyle(fontSize: 11, color: Color(0xFF5A6B7B))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (code.text.trim().isEmpty) return;
              final now = DateTime.now();
              final startsAt = now.toIso8601String();
              final endsAt = now.add(Duration(days: int.tryParse(days.text) ?? 30)).toIso8601String();
              final body = <String, dynamic>{'code': code.text.trim(), 'startsAt': startsAt, 'endsAt': endsAt};
              if (percent.text.trim().isNotEmpty) body['percentOff'] = int.tryParse(percent.text.trim());
              if (amount.text.trim().isNotEmpty) body['amountOffPaise'] = (int.tryParse(amount.text.trim()) ?? 0) * 100;
              if (maxRedemptions.text.trim().isNotEmpty) body['maxRedemptions'] = int.tryParse(maxRedemptions.text.trim());
              Navigator.pop(ctx);
              try {
                await ApiClient.request('POST', '/admin/coupons', body: body);
                showSnack(context, 'Coupon created');
                _load();
              } on ApiException catch (e) {
                showSnack(context, e.message, error: true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Coupons',
          subtitle: '$_total coupons',
          actions: [FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('New coupon'))],
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: _loading
                ? const LoadingBox()
                : _error != null
                    ? ErrorBox(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? const Center(child: Text('No coupons', style: TextStyle(color: Color(0xFF5A6B7B))))
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Code')),
                                      DataColumn(label: Text('Discount')),
                                      DataColumn(label: Text('Valid until')),
                                      DataColumn(label: Text('Limit')),
                                      DataColumn(label: Text('Used')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('')),
                                    ],
                                    rows: [
                                      for (final c in _items)
                                        DataRow(cells: [
                                          DataCell(Text(c['code'] as String, style: const TextStyle(fontWeight: FontWeight.w700))),
                                          DataCell(Text(c['percentOff'] != null ? '${c['percentOff']}%' : c['amountOffPaise'] != null ? '₹${(BigInt.parse(c['amountOffPaise'].toString()) / BigInt.from(100)).toString()}' : '—')),
                                          DataCell(Text((c['endsAt'] as String).substring(0, 10))),
                                          DataCell(Text(c['maxRedemptions']?.toString() ?? '∞')),
                                          DataCell(Text(c['_count']?['redemptions']?.toString() ?? '0')),
                                          DataCell(StatusBadge(status: c['status'] as String)),
                                          DataCell(c['status'] == 'ACTIVE' ? TextButton(onPressed: () => _setStatus(c, 'INACTIVE'), child: const Text('Disable')) : TextButton(onPressed: () => _setStatus(c, 'ACTIVE'), child: const Text('Enable'))),
                                        ]),
                                    ],
                                  ),
                                ),
                              ),
                              PaginationBar(page: _page, totalPages: _totalPages, total: _total, onChanged: (p) {
                                _page = p;
                                _load();
                              }),
                            ],
                          ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}