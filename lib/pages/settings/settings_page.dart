import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SupabaseClient _sb = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  String _email = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final User? u = _sb.auth.currentUser;
    if (u == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final List<dynamic> rows = await _sb.from('profiles').select('display_name').eq('id', u.id).limit(1);
    String dn = '';
    if (rows.isNotEmpty) {
      final Map<String, dynamic> m = rows.first as Map<String, dynamic>;
      dn = (m['display_name'] as String?) ?? '';
    }
    if (mounted) {
      _email = u.email ?? '';
      _nameCtrl.text = dn;
      _loading = false;
      setState(() {});
    }
  }

  Future<void> _save() async {
    final User? u = _sb.auth.currentUser;
    if (u == null) return;
    final bool ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    await _sb.from('profiles').upsert(<String, dynamic>{'id': u.id, 'display_name': _nameCtrl.text.trim()});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(_email.isEmpty ? 'Konto' : _email),
                    subtitle: const Text('Angemeldet'),
                  ),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Display Name'),
                      validator: (String? v) {
                        if (v == null) return null;
                        if (v.length > 80) return 'Zu lang';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: <Widget>[
                const ListTile(
                  leading: Icon(Icons.keyboard),
                  title: Text('Tastaturkürzel'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: SizedBox(width: 24),
                  title: Text('⌘/Ctrl + F'),
                  subtitle: Text('Suche'),
                ),
                const ListTile(
                  leading: SizedBox(width: 24),
                  title: Text('⌘/Ctrl + K'),
                  subtitle: Text('Neue Notiz'),
                ),
                const ListTile(
                  leading: SizedBox(width: 24),
                  title: Text('⌘/Ctrl + L'),
                  subtitle: Text('Favoritenfilter'),
                ),
                const ListTile(
                  leading: SizedBox(width: 24),
                  title: Text('Shift + S'),
                  subtitle: Text('Sortierung'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Abmelden'),
                  onTap: () async {
                    await _sb.auth.signOut();
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
