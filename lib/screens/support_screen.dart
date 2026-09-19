import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _status;
  int _page = 1;
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
      final result = await ApiClient.request('GET', '/admin/support/tickets', query: query);
      final data = result as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _items = (data['items'] as List).cast<Map<String, dynamic>>();
          _total = data['total'] as int;
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

  void _open(Map<String, dynamic> ticket) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TicketDetailScreen(ticket: ticket, onChanged: _load)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(title: 'Support tickets', subtitle: '$_total tickets'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            DropdownButton<String>(
              value: _status,
              hint: const Text('All status'),
              items: ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                        ? const Center(child: Text('No tickets', style: TextStyle(color: Color(0xFF5A6B7B))))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (ctx, i) {
                              final t = _items[i];
                              return ListTile(
                                onTap: () => _open(t),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: const CircleAvatar(backgroundColor: Color(0xFFEDE9FE), child: Icon(Icons.support_agent, color: Color(0xFF7C3AED))),
                                title: Text(t['subject'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${t['user']?['name'] ?? t['user']?['phoneE164'] ?? '—'} • ${(t['createdAt'] as String).substring(0, 16)}'),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [StatusBadge(status: t['status'] as String), const SizedBox(width: 8), const Icon(Icons.chevron_right)]),
                              );
                            },
                          ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onChanged;
  const _TicketDetailScreen({required this.ticket, required this.onChanged});

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  late Map<String, dynamic> _ticket = widget.ticket;

  Future<void> _setStatus(String status) async {
    try {
      final result = await ApiClient.request('PATCH', '/admin/support/tickets/${_ticket['id']}/status', body: {'status': status});
      setState(() => _ticket['status'] = result['status']);
      widget.onChanged();
      showSnack(context, 'Ticket status updated');
    } on ApiException catch (e) {
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket details'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_ticket['subject'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  StatusBadge(status: _ticket['status'] as String),
                ]),
                const Divider(height: 24),
                _kv('User', '${_ticket['user']?['name'] ?? '—'} (${_ticket['user']?['phoneE164'] ?? '—'})'),
                if (_ticket['booking'] != null) _kv('Booking', _ticket['booking']?['publicCode'] as String),
                _kv('Created', (_ticket['createdAt'] as String).substring(0, 16)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_ticket['message'] as String, style: const TextStyle(height: 1.5, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Update status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, children: [
            for (final s in ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'])
              OutlinedButton(onPressed: _ticket['status'] == s ? null : () => _setStatus(s), child: Text('Mark $s')),
          ]),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Color(0xFF5A6B7B)))), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))]),
    );
  }
}