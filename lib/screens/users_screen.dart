import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
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
      final result = await ApiClient.request('GET', '/admin/users', query: query);
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

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    final target = user['status'] == 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text('${target == 'SUSPENDED' ? 'Suspend' : 'Reactivate'} user ${user['name'] ?? user['phoneE164']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.request('PATCH', '/admin/users/${user['id']}/status', body: {'status': target});
      showSnack(context, 'User ${target == 'SUSPENDED' ? 'suspended' : 'activated'}');
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, error: true);
    }
  }

  void _viewDetail(Map<String, dynamic> user) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _UserDetailScreen(userId: user['id'] as String)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Users',
          subtitle: '$_total registered users',
          actions: [
            SearchField(controller: _search, hint: 'Search name, phone, email...', onChanged: () {
              _page = 1;
              _load();
            }),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _status,
              hint: const Text('All status'),
              items: ['ACTIVE', 'SUSPENDED', 'DELETED'].map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                        ? const Center(child: Text('No users found', style: TextStyle(color: Color(0xFF5A6B7B))))
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Name')),
                                        DataColumn(label: Text('Phone')),
                                        DataColumn(label: Text('Email')),
                                        DataColumn(label: Text('Bookings')),
                                        DataColumn(label: Text('Role')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Joined')),
                                        DataColumn(label: Text('')),
                                      ],
                                      rows: [
                                        for (final user in _items)
                                          DataRow(
                                            onSelectChanged: (_) => _viewDetail(user),
                                            cells: [
                                              DataCell(Text(user['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
                                              DataCell(Text(user['phoneE164'] ?? '—')),
                                              DataCell(Text(user['email'] ?? '—')),
                                              DataCell(Text((user['_count'] as Map?)?['bookings']?.toString() ?? '0')),
                                              DataCell(Text(user['isAdmin'] == true ? 'Admin' : 'User')),
                                              DataCell(StatusBadge(status: user['status'] as String)),
                                              DataCell(Text((user['createdAt'] as String? ?? '').substring(0, 10))),
                                              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                                IconButton(icon: const Icon(Icons.visibility_outlined, size: 20), onPressed: () => _viewDetail(user)),
                                                IconButton(
                                                  icon: Icon(user['status'] == 'ACTIVE' ? Icons.block : Icons.refresh, size: 20, color: user['status'] == 'ACTIVE' ? const Color(0xFFD32F2F) : const Color(0xFF00B892)),
                                                  onPressed: () => _toggleStatus(user),
                                                ),
                                              ])),
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

class _UserDetailScreen extends StatefulWidget {
  final String userId;
  const _UserDetailScreen({required this.userId});

  @override
  State<_UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<_UserDetailScreen> {
  Map<String, dynamic>? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await ApiClient.request('GET', '/admin/users/${widget.userId}');
      if (mounted) setState(() => _user = user as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User details'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _user == null
          ? (_error != null ? ErrorBox(message: _error!, onRetry: _load) : const LoadingBox())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.person_outline, size: 44, color: Color(0xFF00B892)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_user!['name'] ?? 'Unnamed user', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          Text(_user!['phoneE164'] ?? '—'),
                        ])),
                        StatusBadge(status: _user!['status'] as String),
                      ]),
                      const Divider(height: 28),
                      _kv('Email', _user!['email'] ?? '—'),
                      _kv('Joined', (_user!['createdAt'] as String? ?? '').substring(0, 10)),
                      _kv('Bookings', _user!['_count']?['bookings']?.toString() ?? '0'),
                      _kv('Reviews', _user!['_count']?['reviews']?.toString() ?? '0'),
                      _kv('Support tickets', _user!['_count']?['supportTickets']?.toString() ?? '0'),
                      if (_user!['deletionRequestedAt'] != null) _kv('Deletion requested', 'Yes'),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Recent bookings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: (_user!['bookings'] as List).isEmpty
                        ? const Padding(padding: EdgeInsets.all(20), child: Text('No bookings'))
                        : Column(children: [
                            for (final b in (_user!['bookings'] as List).cast<Map<String, dynamic>>())
                              ListTile(
                                dense: true,
                                title: Text(b['publicCode'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text((b['startsAt'] as String).substring(0, 16)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text('₹${(BigInt.parse(b['totalPaise'].toString()) / BigInt.from(100)).toString()}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 10),
                                  StatusBadge(status: b['status'] as String),
                                ]),
                              ),
                          ]),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [SizedBox(width: 150, child: Text(k, style: const TextStyle(color: Color(0xFF5A6B7B)))), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))]),
    );
  }
}