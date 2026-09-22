import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;
  Map<String, dynamic>? _stats;
  bool _loadingStats = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loadingStats = true;
      _error = null;
    });
    try {
      final stats = await AdminApi.getNotificationStats();
      if (mounted) {
        setState(() {
          _stats = stats as Map<String, dynamic>;
          _loadingStats = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loadingStats = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      showSnack(context, 'Title and body are required', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send broadcast?'),
        content: const Text('This will push a notification to all opted-in users.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _sending = true);
    try {
      final result = await AdminApi.broadcastNotification(_title.text.trim(), _body.text.trim());
      if (!mounted) return;
      showSnack(context, 'Broadcast created (${result['created'] ?? 0} notifications, ${result['pushed'] ?? 0} pushed)');
      _title.clear();
      _body.clear();
      await _loadStats();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(title: 'Push notifications', subtitle: 'Send broadcast messages and view delivery stats'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Compose broadcast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Flash sale this weekend')),
                      const SizedBox(height: 12),
                      TextField(controller: _body, decoration: const InputDecoration(labelText: 'Body', hintText: 'e.g. Flat 25% off at all venues'), minLines: 3, maxLines: 6),
                      const SizedBox(height: 20),
                      Row(children: [
                        FilledButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Icons.campaign_outlined), label: Text(_sending ? 'Sending...' : 'Send broadcast')),
                        const SizedBox(width: 12),
                        Text('Sends to all users with FCM tokens', style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B7B))),
                      ]),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      if (_loadingStats)
                        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                      else if (_error != null)
                        ErrorBox(message: _error!, onRetry: _loadStats)
                      else ...[
                        Row(children: [
                          Expanded(child: StatCard(label: 'Total notifications', value: '${_stats!['total'] ?? 0}', icon: Icons.notifications_active_outlined, color: const Color(0xFF2563EB))),
                          const SizedBox(width: 12),
                          Expanded(child: StatCard(label: 'Sent', value: '${_stats!['sent'] ?? 0}', icon: Icons.check_circle_outline, color: const Color(0xFF00B892))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: StatCard(label: 'Failed', value: '${_stats!['failed'] ?? 0}', icon: Icons.error_outline, color: const Color(0xFFD32F2F))),
                          const SizedBox(width: 12),
                          Expanded(child: StatCard(label: 'Devices', value: '${_stats!['devices'] ?? 0}', icon: Icons.phone_android, color: const Color(0xFF7C3AED))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: StatCard(label: 'Pending', value: '${_stats!['pending'] ?? 0}', icon: Icons.schedule, color: const Color(0xFFF59E0B))),
                          const SizedBox(width: 12),
                          Expanded(child: StatCard(label: 'Unread', value: '${_stats!['unread'] ?? 0}', icon: Icons.mark_email_unread_outlined, color: const Color(0xFF14B8A6))),
                        ]),
                      ],
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}