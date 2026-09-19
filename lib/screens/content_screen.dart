import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(title: 'Content', subtitle: 'FAQs and policies shown to users'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: TabBar(
            tabs: [Tab(text: 'FAQs'), Tab(text: 'Policies')],
            labelColor: Color(0xFF00B892),
            unselectedLabelColor: Color(0xFF5A6B7B),
            indicatorColor: Color(0xFF00B892),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: TabBarView(children: [_FaqsTab(), _PoliciesTab()]),
          ),
        ),
      ],
    );
  }
}

class _FaqsTab extends StatefulWidget {
  @override
  State<_FaqsTab> createState() => _FaqsTabState();
}

class _FaqsTabState extends State<_FaqsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
      final result = await ApiClient.request('GET', '/admin/content/faqs');
      if (mounted) {
        setState(() {
          _items = (result as List).cast<Map<String, dynamic>>();
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

  Future<void> _setStatus(Map<String, dynamic> faq, String status) async {
    try {
      await ApiClient.request('PATCH', '/admin/content/faqs/${faq['id']}/status', body: {'status': status});
      showSnack(context, 'FAQ ${status == 'ACTIVE' ? 'published' : 'hidden'}');
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, error: true);
    }
  }

  void _edit([Map<String, dynamic>? faq]) {
    final question = TextEditingController(text: faq?['question'] as String? ?? '');
    final answer = TextEditingController(text: faq?['answer'] as String? ?? '');
    final order = TextEditingController(text: faq?['sortOrder']?.toString() ?? '0');
    final isEdit = faq != null;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit FAQ' : 'New FAQ'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: question, decoration: const InputDecoration(labelText: 'Question')),
              const SizedBox(height: 10),
              TextField(controller: answer, decoration: const InputDecoration(labelText: 'Answer'), minLines: 4, maxLines: 8),
              const SizedBox(height: 10),
              TextField(controller: order, decoration: const InputDecoration(labelText: 'Sort order'), keyboardType: TextInputType.number),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (question.text.trim().isEmpty || answer.text.trim().isEmpty) return;
              final body = {'question': question.text.trim(), 'answer': answer.text.trim(), 'sortOrder': int.tryParse(order.text) ?? 0};
              Navigator.pop(ctx);
              try {
                await ApiClient.request(isEdit ? 'PATCH' : 'POST', isEdit ? '/admin/content/faqs/${faq['id']}' : '/admin/content/faqs', body: body);
                showSnack(context, 'FAQ saved');
                _load();
              } on ApiException catch (e) {
                showSnack(context, e.message, error: true);
              }
            },
            child: Text(isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        child: _loading
            ? const LoadingBox()
            : _error != null
                ? ErrorBox(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? const Center(child: Text('No FAQs', style: TextStyle(color: Color(0xFF5A6B7B))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final f = _items[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            leading: const CircleAvatar(backgroundColor: Color(0xFFE6F7F3), child: Icon(Icons.help_outline, color: Color(0xFF00B892))),
                            title: Text(f['question'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(f['answer'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              StatusBadge(status: f['status'] as String),
                              IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _edit(f), tooltip: 'Edit'),
                              PopupMenuButton<String>(onSelected: (s) => _setStatus(f, s), itemBuilder: (_) => ['ACTIVE', 'INACTIVE'].map((s) => PopupMenuItem(value: s, child: Text(s == 'ACTIVE' ? 'Publish' : 'Hide'))).toList()),
                            ]),
                          );
                        },
                      ),
      ),
    );
  }
}

class _PoliciesTab extends StatefulWidget {
  @override
  State<_PoliciesTab> createState() => _PoliciesTabState();
}

class _PoliciesTabState extends State<_PoliciesTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
      final result = await ApiClient.request('GET', '/admin/content/policies');
      if (mounted) {
        setState(() {
          _items = (result as List).cast<Map<String, dynamic>>();
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

  Future<void> _setStatus(Map<String, dynamic> policy, String status) async {
    try {
      await ApiClient.request('PATCH', '/admin/content/policies/${policy['id']}/status', body: {'status': status});
      showSnack(context, 'Policy ${status == 'PUBLISHED' ? 'published' : 'concealed'}');
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, error: true);
    }
  }

  void _create() {
    final title = TextEditingController();
    final body = TextEditingController();
    final version = TextEditingController(text: 'v1.0');
    String type = 'PRIVACY';
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('New policy'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['PRIVACY', 'TOS', 'REFUND', 'CANCELLATION'].map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: body, decoration: const InputDecoration(labelText: 'Body'), minLines: 10, maxLines: 20),
                const SizedBox(height: 10),
                TextField(controller: version, decoration: const InputDecoration(labelText: 'Version')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
                final payload = <String, dynamic>{'type': type, 'title': title.text.trim(), 'body': body.text.trim(), 'version': version.text.trim().isEmpty ? 'v1.0' : version.text.trim()};
                Navigator.pop(ctx);
                try {
                  await ApiClient.request('POST', '/admin/content/policies', body: payload);
                  showSnack(context, 'Policy created');
                  _load();
                } on ApiException catch (e) {
                  showSnack(context, e.message, error: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        child: _loading
            ? const LoadingBox()
            : _error != null
                ? ErrorBox(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? const Center(child: Text('No policies', style: TextStyle(color: Color(0xFF5A6B7B))))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('New policy'))]),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _items.length,
                              itemBuilder: (ctx, i) {
                                final p = _items[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), child: Icon(Icons.description_outlined, color: Color(0xFFF97316))),
                                  title: Text('${p['title']} (${p['version']})', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('${p['type']} • ${(p['updatedAt'] as String).substring(0, 10)}'),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    StatusBadge(status: p['status'] as String),
                                    PopupMenuButton<String>(onSelected: (s) => _setStatus(p, s), itemBuilder: (_) => ['PUBLISHED', 'CONCEALED'].map((s) => PopupMenuItem(value: s, child: Text(s == 'PUBLISHED' ? 'Publish' : 'Hide'))).toList()),
                                  ]),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}