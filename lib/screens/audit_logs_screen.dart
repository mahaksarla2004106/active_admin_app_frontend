import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';
import 'dart:convert';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  bool _loading = false;
  List _logs = [];
  int _page = 1;
  int _total = 0;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AdminApi.getAuditLogs(page: _page, limit: 20);
      setState(() {
        _logs = res['items'] ?? [];
        _total = res['total'] ?? 0;
        _totalPages = res['totalPages'] ?? 1;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Audit Logs',
          subtitle: 'System activity & admin actions ($_total total)',
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        ),
        if (_loading && _logs.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_logs.isEmpty)
          const Expanded(child: Center(child: Text('No audit logs found')))
        else
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: ListView.separated(
                itemCount: _logs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final actor = log['actor'] ?? {};
                  final actorName = actor['name'] ?? 'System';
                  return ExpansionTile(
                    title: Text(log['action'] ?? 'Unknown Action', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${log['entityType']} • ${log['createdAt']} • by $actorName'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'Before: ${jsonEncode(log['beforeJson'] ?? {})}\nAfter: ${jsonEncode(log['afterJson'] ?? {})}',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(onPressed: _page > 1 ? () { _page--; _load(); } : null, child: const Text('Previous')),
                Text('Page $_page of $_totalPages'),
                OutlinedButton(onPressed: _page < _totalPages ? () { _page++; _load(); } : null, child: const Text('Next')),
              ],
            ),
          ),
      ],
    );
  }
}
