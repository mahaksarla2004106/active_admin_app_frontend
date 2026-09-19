import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _search = TextEditingController();
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
      if (_search.text.trim().isNotEmpty) query['search'] = _search.text.trim();
      if (_status != null) query['status'] = _status!;
      final result = await ApiClient.request('GET', '/admin/bookings', query: query);
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

  void _viewDetail(Map<String, dynamic> booking) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _BookingDetailScreen(bookingId: booking['id'] as String)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Bookings',
          subtitle: '$_total bookings',
          actions: [
            SearchField(controller: _search, hint: 'Search booking code...', onChanged: () {
              _page = 1;
              _load();
            }),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _status,
              hint: const Text('All status'),
              items: ['PENDING_PAYMENT', 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'RESCHEDULED'].map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                _status = v;
                _page = 1;
                _load();
              },
            ),
          ],
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: _loading
                ? const LoadingBox()
                : _error != null
                    ? ErrorBox(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? const Center(child: Text('No bookings found', style: TextStyle(color: Color(0xFF5A6B7B))))
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Code')),
                                        DataColumn(label: Text('User')),
                                        DataColumn(label: Text('Venue')),
                                        DataColumn(label: Text('Slot')),
                                        DataColumn(label: Text('Amount')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Created')),
                                        DataColumn(label: Text('')),
                                      ],
                                      rows: [
                                        for (final b in _items)
                                          DataRow(
                                            onSelectChanged: (_) => _viewDetail(b),
                                            cells: [
                                              DataCell(Text(b['publicCode'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                                              DataCell(Text(b['user']?['name'] ?? b['user']?['phoneE164'] ?? '—')),
                                              DataCell(Text(b['slot']['facility']['venue']['name'] as String)),
                                              DataCell(Text((b['startsAt'] as String).substring(0, 16))),
                                              DataCell(Text('₹${(BigInt.parse(b['totalPaise'].toString()) / BigInt.from(100)).toString()}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                              DataCell(StatusBadge(status: b['status'] as String)),
                                              DataCell(Text((b['createdAt'] as String).substring(0, 10))),
                                              DataCell(IconButton(icon: const Icon(Icons.visibility_outlined, size: 20), onPressed: () => _viewDetail(b))),
                                            ],
                                          ),
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

class _BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const _BookingDetailScreen({required this.bookingId});

  @override
  State<_BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<_BookingDetailScreen> {
  Map<String, dynamic>? _booking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final booking = await ApiClient.request('GET', '/admin/bookings/${widget.bookingId}');
      if (mounted) setState(() => _booking = booking as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking'),
        content: Text('Cancel ${_booking!['publicCode']}? A refund will be created for paid bookings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)), child: const Text('Cancel booking')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.request('POST', '/admin/bookings/${widget.bookingId}/cancel', body: {'reason': 'Admin cancelled'});
      showSnack(context, 'Booking cancelled');
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking details'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _booking == null
          ? (_error != null ? ErrorBox(message: _error!, onRetry: _load) : const LoadingBox())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(_booking!['publicCode'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                        StatusBadge(status: _booking!['status'] as String),
                        if (_booking!['status'] == 'CONFIRMED') ...[
                          const SizedBox(width: 10),
                          OutlinedButton(onPressed: _cancel, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD32F2F), side: const BorderSide(color: Color(0xFFD32F2F))), child: const Text('Cancel')),
                        ],
                      ]),
                      const Divider(height: 28),
                      _kv('User', '${_booking!['user']?['name'] ?? '—'} (${_booking!['user']?['phoneE164'] ?? '—'})'),
                      _kv('Venue', '${_booking!['slot']['facility']['venue']['name']} • ${_booking!['slot']['facility']['venue']['cityCode']}'),
                      _kv('Facility', _booking!['slot']['facility']['name'] as String),
                      _kv('Starts', (_booking!['startsAt'] as String).substring(0, 16)),
                      _kv('Subtotal', '₹${(BigInt.parse(_booking!['subtotalPaise'].toString()) / BigInt.from(100)).toString()}'),
                      _kv('Discount', '−₹${(BigInt.parse(_booking!['discountPaise'].toString()) / BigInt.from(100)).toString()}'),
                      _kv('Total', '₹${(BigInt.parse(_booking!['totalPaise'].toString()) / BigInt.from(100)).toString()}', bold: true),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Payments', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: (_booking!['payments'] as List).isEmpty
                        ? const Padding(padding: EdgeInsets.all(16), child: Text('No payments'))
                        : Column(children: [
                            for (final p in (_booking!['payments'] as List).cast<Map<String, dynamic>>())
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.payments_outlined, color: Color(0xFF00B892)),
                                title: Text('${p['provider']} • ${p['providerOrderId'] ?? '—'}', style: const TextStyle(fontSize: 13)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text('₹${(BigInt.parse(p['amountPaise'].toString()) / BigInt.from(100)).toString()}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 10),
                                  StatusBadge(status: p['status'] as String),
                                ]),
                              ),
                          ]),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Refunds', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: (_booking!['refunds'] as List).isEmpty
                        ? const Padding(padding: EdgeInsets.all(16), child: Text('No refunds'))
                        : Column(children: [
                            for (final r in (_booking!['refunds'] as List).cast<Map<String, dynamic>>())
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.currency_rupee, color: Color(0xFFF97316)),
                                title: Text('Refund ${r['providerRef'] ?? r['id']}', style: const TextStyle(fontSize: 13)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text('₹${(BigInt.parse(r['amountPaise'].toString()) / BigInt.from(100)).toString()}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 10),
                                  StatusBadge(status: r['status'] as String),
                                ]),
                              ),
                          ]),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Timeline', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: (_booking!['events'] as List).isEmpty
                        ? const Padding(padding: EdgeInsets.all(16), child: Text('No events'))
                        : Column(children: [
                            for (final e in (_booking!['events'] as List).cast<Map<String, dynamic>>())
                              ListTile(
                                dense: true,
                                title: Text('${e['fromStatus'] ?? '—'} → ${e['toStatus']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text((e['createdAt'] as String).substring(0, 16)),
                              ),
                          ]),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Color(0xFF5A6B7B)))),
        Expanded(child: Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 15 : 14))),
      ]),
    );
  }
}