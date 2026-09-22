import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/ui_kit.dart';

class VenuesScreen extends StatefulWidget {
  const VenuesScreen({super.key});

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(title: 'Venues & Activities', subtitle: 'Manage venues and the activity catalogue'),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [Tab(text: 'Venues'), Tab(text: 'Activities')],
                  labelColor: Color(0xFF00B892),
                  unselectedLabelColor: Color(0xFF5A6B7B),
                  indicatorColor: Color(0xFF00B892),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TabBarView(
                    children: [_VenuesTab(), _ActivitiesTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VenuesTab extends StatefulWidget {
  @override
  State<_VenuesTab> createState() => _VenuesTabState();
}

class _VenuesTabState extends State<_VenuesTab> {
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
      final query = <String, String>{'page': '$_page', 'limit': '12'};
      if (_search.text.trim().isNotEmpty) query['search'] = _search.text.trim();
      if (_status != null) query['status'] = _status!;
      final result = await AdminApi.getVenues(query);
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

  Future<void> _setStatus(Map<String, dynamic> venue, String status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(title: const Text('Confirm'), content: Text('Set venue "${venue['name']}" status to $status?'), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
      ]),
    );
    if (confirmed != true) return;
    try {
      await AdminApi.updateVenueStatus(venue['id'], status);
      if (!mounted) return;
      showSnack(context, 'Venue status updated');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  void _viewDetail(Map<String, dynamic> venue) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _VenueDetailScreen(venueId: venue['id'] as String)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(children: [
            SearchField(controller: _search, hint: 'Search venue...', onChanged: () {
              _page = 1;
              _load();
            }),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _status,
              hint: const Text('All status'),
              items: ['DRAFT', 'PUBLISHED', 'ARCHIVED'].map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                _status = v;
                _page = 1;
                _load();
              },
            ),
          ]),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: _loading
                ? const LoadingBox()
                : _error != null
                    ? ErrorBox(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? const Center(child: Text('No venues found', style: TextStyle(color: Color(0xFF5A6B7B))))
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _items.length,
                                  itemBuilder: (ctx, i) {
                                    final v = _items[i];
                                    final activities = (v['activities'] as List?)?.length ?? 0;
                                    return ListTile(
                                      onTap: () => _viewDetail(v),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: const CircleAvatar(backgroundColor: Color(0xFFE6F7F3), child: Icon(Icons.location_city_outlined, color: Color(0xFF00B892))),
                                      title: Text(v['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text('${v['cityCode']} • ${v['_count']?['savedBy'] ?? 0} saves • $activities activities'),
                                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                        StatusBadge(status: v['status'] as String),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          onSelected: (s) => _setStatus(v, s),
                                          itemBuilder: (_) => ['PUBLISHED', 'DRAFT', 'ARCHIVED'].map((s) => PopupMenuItem(value: s, child: Text('Set $s'))).toList(),
                                        ),
                                      ]),
                                    );
                                  },
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
      ],
    );
  }
}

class _VenueDetailScreen extends StatefulWidget {
  final String venueId;
  const _VenueDetailScreen({required this.venueId});

  @override
  State<_VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<_VenueDetailScreen> {
  Map<String, dynamic>? _venue;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final venue = await AdminApi.getVenueDetails(widget.venueId);
      if (mounted) setState(() => _venue = venue as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Venue details'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _venue == null
          ? (_error != null ? ErrorBox(message: _error!, onRetry: _load) : const LoadingBox())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(_venue!['name'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                        StatusBadge(status: _venue!['status'] as String),
                      ]),
                      const Divider(height: 24),
                      _kv('City', _venue!['cityCode'] as String),
                      _kv('Partner', '${_venue!['partner']?['legalName'] ?? '—'} (${_venue!['partner']?['status'] ?? '—'})'),
                      _kv('Policy version', _venue!['policyVersion'] as String),
                      _kv('Saved by', _venue!['_count']?['savedBy']?.toString() ?? '0'),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Activities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: (_venue!['activities'] as List).isEmpty
                        ? const Padding(padding: EdgeInsets.all(16), child: Text('No activities'))
                        : Column(children: [
                            for (final a in (_venue!['activities'] as List).cast<Map<String, dynamic>>())
                              ListTile(
                                dense: true,
                                title: Text(a['activity']['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text('${a['activity']['sportCode']} • ${a['activity']['type']}'),
                                trailing: StatusBadge(status: a['status'] as String),
                              ),
                          ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Facilities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: (_venue!['facilities'] as List).isEmpty
                        ? const Padding(padding: EdgeInsets.all(16), child: Text('No facilities'))
                        : Column(children: [
                            for (final f in (_venue!['facilities'] as List).cast<Map<String, dynamic>>())
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.stadium_outlined, color: Color(0xFF00B892)),
                                title: Text(f['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                subtitle: Text('Capacity ${f['capacity']} • ${f['_count']?['slots'] ?? 0} slots'),
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
      child: Row(children: [SizedBox(width: 130, child: Text(k, style: const TextStyle(color: Color(0xFF5A6B7B)))), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))]),
    );
  }
}

class _ActivitiesTab extends StatefulWidget {
  @override
  State<_ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<_ActivitiesTab> {
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
      final result = await AdminApi.getActivities();
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

  Future<void> _setStatus(Map<String, dynamic> activity, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(title: const Text('Confirm'), content: Text('$action "${activity['name']}"?'), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
      ]),
    );
    if (confirmed != true) return;
    try {
      await AdminApi.updateActivityStatus(activity['id'], action);
      if (!mounted) return;
      showSnack(context, 'Activity ${action}ed');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  void _createActivity() {
    final name = TextEditingController();
    final code = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New activity'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Sport code')),
          const SizedBox(height: 12),
          const Text('Type: SINGLE / COURT / TURF / TABLE / CRICKET_NETS', style: TextStyle(fontSize: 11, color: Color(0xFF5A6B7B))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty || code.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await AdminApi.createActivity(name.text.trim(), code.text.trim(), 'SINGLE');
                if (!mounted) return;
                showSnack(context, 'Activity created');
                _load();
              } on ApiException catch (e) {
                if (!mounted) return;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Card(
        child: _loading
            ? const LoadingBox()
            : _error != null
                ? ErrorBox(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? const Center(child: Text('No activities', style: TextStyle(color: Color(0xFF5A6B7B))))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [FilledButton.icon(onPressed: _createActivity, icon: const Icon(Icons.add), label: const Text('New activity'))]),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Sport code')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: [
                                  for (final a in _items)
                                    DataRow(cells: [
                                      DataCell(Text(a['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(a['sportCode'] as String)),
                                      DataCell(Text(a['type'] as String)),
                                      DataCell(StatusBadge(status: a['status'] as String)),
                                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (a['status'] != 'PUBLISHED') TextButton(onPressed: () => _setStatus(a, 'approve'), child: const Text('Publish')),
                                        if (a['status'] != 'ARCHIVED') TextButton(onPressed: () => _setStatus(a, 'deactivate'), child: const Text('Archive')),
                                      ])),
                                    ]),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}