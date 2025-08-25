import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserMgmtPage extends StatefulWidget {
  const AdminUserMgmtPage({super.key});
  @override
  State<AdminUserMgmtPage> createState() => _AdminUserMgmtPageState();
}

class _AdminUserMgmtPageState extends State<AdminUserMgmtPage> {
  final SupabaseClient _sb = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<_UserRow>> _profilesStream() {
    final SupabaseStreamBuilder s = _sb.from('profiles').stream(primaryKey: <String>['id']).order('updated_at', ascending: false);
    return s.map((List<Map<String, dynamic>> rows) {
      final List<_UserRow> list = rows.map((Map<String, dynamic> m) {
        final String id = m['id'] as String;
        final String dn = (m['display_name'] as String?) ?? '';
        final String role = (m['role'] as String?) ?? 'user';
        return _UserRow(id: id, displayName: dn, role: role);
      }).toList();
      list.sort((a, b) => (a.displayName.isEmpty ? a.id : a.displayName).toLowerCase().compareTo((b.displayName.isEmpty ? b.id : b.displayName).toLowerCase()));
      return list;
    });
  }

  List<_UserRow> _applyFilter(List<_UserRow> all) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((u) => u.id.toLowerCase().contains(q) || u.displayName.toLowerCase().contains(q) || u.role.toLowerCase().contains(q)).toList();
  }

  Future<void> _editUser(_UserRow u) async {
    final _EditResult? r = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext c) => _EditSheet(
        initialName: u.displayName,
        initialRole: u.role,
      ),
    );
    if (r == null) return;
    try {
      await _sb.rpc('admin_update_profile', params: <String, dynamic>{
        'p_user_id': u.id,
        'p_display_name': r.name,
        'p_role': r.role,
      });
      await _sb.from('profiles').select('id').limit(1);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Nutzerverwaltung'),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              await _sb.from('profiles').select().limit(1);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      onPressed: () {
                        setState(() => _query = _searchCtrl.text.trim());
                      },
                      icon: const Icon(Icons.check),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 96),
              ),
              onSubmitted: (String _) => setState(() => _query = _searchCtrl.text.trim()),
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<_UserRow>>(
              stream: _profilesStream(),
              builder: (BuildContext context, AsyncSnapshot<List<_UserRow>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }
                final List<_UserRow> users = _applyFilter(snapshot.data ?? <_UserRow>[]);
                if (users.isEmpty) return const Center(child: Text('Keine Nutzer'));
                return RefreshIndicator(
                  onRefresh: () async {
                    await _sb.from('profiles').select().limit(1);
                  },
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (BuildContext context, int i) {
                      final _UserRow u = users[i];
                      final String title = u.displayName.isEmpty ? u.id : u.displayName;
                      final String sub = u.displayName.isEmpty ? u.role : '${u.role} • ${u.id}';
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          onPressed: () => _editUser(u),
                          icon: const Icon(Icons.edit),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow {
  final String id;
  final String displayName;
  final String role;
  const _UserRow({required this.id, required this.displayName, required this.role});
}

class _EditResult {
  final String name;
  final String role;
  const _EditResult({required this.name, required this.role});
}

class _EditSheet extends StatefulWidget {
  final String initialName;
  final String initialRole;
  const _EditSheet({super.key, required this.initialName, required this.initialRole});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.initialName);
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Wrap(
            runSpacing: 12,
            children: <Widget>[
              Text('Nutzer bearbeiten', style: Theme.of(context).textTheme.titleLarge),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              DropdownButtonFormField<String>(
                value: _role,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'user', child: Text('user')),
                  DropdownMenuItem<String>(value: 'moderator', child: Text('moderator')),
                  DropdownMenuItem<String>(value: 'admin', child: Text('admin')),
                ],
                onChanged: (String? v) => setState(() => _role = v ?? 'user'),
                decoration: const InputDecoration(labelText: 'Rolle'),
              ),
              Row(
                children: <Widget>[
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(_EditResult(name: _nameCtrl.text.trim(), role: _role));
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Speichern'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
