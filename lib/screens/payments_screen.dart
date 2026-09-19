import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  int _tab = 0;
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

  List<String> get _statuses => _tab == 0
      ? ['CREATED', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUND_PENDING', 'REFUNDED', 'EXCEPTION_REVIEW']
      : ['PENDING', 'PROCESSED', 'FAILED', 'EXCEPTION_REVIEW'];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, String>{'page': '$_page', 'limit': '15'};
      if (_status != null) query['status'] = _status!;
      final result = await ApiClient.request('GET', _tab == 0 ? '/admin/payments' : '/admin/refunds', query: query);
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

  void _switchTab(int tab) {
    setState(() {
      _tab = tab;
      _status = null;
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isPayments = _tab == 0;
    return Column(
      children: [
        PageHeader(title: 'Payments & Refunds', subtitle: _total > 0 ? '$_total ${(_tab == 0 ? 'payments' : 'refunds')}' : ''),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 0, label: Text('Payments'), icon: Icon(Icons.payments_outlined)), ButtonSegment(value: 1, label: Text('Refunds'), icon: Icon(Icons.currency_rupee))],
              selected: {_tab},
              onSelectionChanged: (s) => _switchTab(s.first),
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _status,
              hint: const Text('All status'),
              items: _statuses.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                _status = v;
                _page = 1;
                _load();
              },
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: _loading
                ? const LoadingBox()
                : _error != null
                    ? ErrorBox(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? const Center(child: Text('Nothing found', style: TextStyle(color: Color(0xFF5A6B7B))))
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: isPayments
                                          ? const [
                                              DataColumn(label: Text('Order')),
                                              DataColumn(label: Text('Booking')),
                                              DataColumn(label: Text('User')),
                                              DataColumn(label: Text('Amount')),
                                              DataColumn(label: Text('Status')),
                                              DataColumn(label: Text('Date')),
                                            ]
                                          : const [
                                              DataColumn(label: Text('Refund')),
                                              DataColumn(label: Text('Booking')),
                                              DataColumn(label: Text('User')),
                                              DataColumn(label: Text('Amount')),
                                              DataColumn(label: Text('Status')),
                                              DataColumn(label: Text('Date')),
                                            ],
                                      rows: [
                                        for (final item in _items)
                                          isPayments
                                              ? DataRow(cells: [
                                                  DataCell(Text(item['providerOrderId'] ?? item['id'].substring(0, 8) as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                                                  DataCell(Text(item['booking']?['publicCode'] ?? '—')),
                                                  DataCell(Text(item['booking']?['user']?['name'] ?? item['booking']?['user']?['phoneE164'] ?? '—')),
                                                  DataCell(Text('₹${(BigInt.parse(item['amountPaise'].toString()) / BigInt.from(100)).toString()}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                                  DataCell(StatusBadge(status: item['status'] as String)),
                                                  DataCell(Text((item['createdAt'] as String).substring(0, 10))),
                                                ])
                                              : DataRow(cells: [
                                                  DataCell(Text(item['providerRef'] ?? item['id'].substring(0, 8) as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                                                  DataCell(Text(item['booking']?['publicCode'] ?? '—')),
                                                  DataCell(Text(item['booking']?['user']?['name'] ?? item['booking']?['user']?['phoneE164'] ?? '—')),
                                                  DataCell(Text('₹${(BigInt.parse(item['amountPaise'].toString()) / BigInt.from(100)).toString()}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                                  DataCell(StatusBadge(status: item['status'] as String)),
                                                  DataCell(Text((item['createdAt'] as String).substring(0, 10))),
                                                ]),
                                      ],
                                    ),
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