import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class FeatureFlagsScreen extends StatefulWidget {
  const FeatureFlagsScreen({super.key});

  @override
  State<FeatureFlagsScreen> createState() => _FeatureFlagsScreenState();
}

class _FeatureFlagsScreenState extends State<FeatureFlagsScreen> {
  bool _loading = false;
  List _flags = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AdminApi.getFeatureFlags();
      setState(() => _flags = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String key, bool enabled) async {
    try {
      await AdminApi.toggleFeatureFlag(key, enabled);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Feature Flags',
          subtitle: 'Manage system-wide toggles',
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        ),
        if (_loading && _flags.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_flags.isEmpty)
          const Expanded(child: Center(child: Text('No feature flags found')))
        else
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: ListView.separated(
                itemCount: _flags.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final flag = _flags[index];
                  return ListTile(
                    title: Text(flag['key'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(flag['description'] ?? ''),
                    trailing: Switch(
                      value: flag['enabled'] == true,
                      onChanged: (val) => _toggle(flag['key'], val),
                      activeThumbColor: const Color(0xFF00B892),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
