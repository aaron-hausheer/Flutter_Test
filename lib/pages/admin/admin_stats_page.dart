import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});
  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  final SupabaseClient _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  _Stats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _toUtcDate(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final DateTime now = DateTime.now().toUtc();
      final DateTime from7 = now.subtract(const Duration(days: 7));
      final DateTime from14 = now.subtract(const Duration(days: 14));

      // ---- 1) "Ping" messen
      final DateTime t0 = DateTime.now();
      await _sb.from('notes').select('id').limit(1);
      final Duration ping = DateTime.now().difference(t0);

      // ---- 2) Daten parallel holen
      final List<Future<dynamic>> futs = <Future<dynamic>>[
        _sb.from('profiles').select('id, display_name'),
        _sb.from('notes').select('id'), // total count via length
        _sb
            .from('notes')
            .select('id, user_id, created_at')
            .gte('created_at', from14.toIso8601String())
            .order('created_at'),
      ];

      final List<dynamic> res = await Future.wait(futs);

      final List<dynamic> profiles = res[0] as List<dynamic>;
      final List<dynamic> noteIds = res[1] as List<dynamic>;
      final List<dynamic> recent = res[2] as List<dynamic>;

      // ---- 3) Profile-Namen-Map
      final Map<String, String> names = <String, String>{};
      for (final dynamic r in profiles) {
        final Map<String, dynamic> m = r as Map<String, dynamic>;
        final String id = (m['id'] as String?) ?? '';
        final String dn = (m['display_name'] as String?) ?? '';
        if (id.isNotEmpty) names[id] = dn.isEmpty ? id : dn;
      }
      final int totalUsers = profiles.length;
      final int totalNotes = noteIds.length;

      // ---- 4) Recent Notes (14T) normalisieren
      final List<_NoteRow> notes = <_NoteRow>[];
      for (final dynamic r in recent) {
        final Map<String, dynamic> m = r as Map<String, dynamic>;
        final String uid = (m['user_id'] as String?) ?? '';
        final dynamic cr = m['created_at'];
        DateTime createdAtUtc;
        if (cr is String) {
          createdAtUtc = DateTime.parse(cr).toUtc();
        } else if (cr is DateTime) {
          createdAtUtc = cr.toUtc();
        } else {
          createdAtUtc = now;
        }
        notes.add(_NoteRow(uid: uid, createdAt: createdAtUtc));
      }

      // ---- 5) Tagesbuckets (letzte 14 Tage, aufsteigend)
      final List<DateTime> daysAsc = List<DateTime>.generate(
        14,
        (int i) => _toUtcDate(now.subtract(Duration(days: 13 - i))),
      );
      final Map<DateTime, int> perDay = <DateTime, int>{
        for (final DateTime d in daysAsc) d: 0,
      };

      for (final _NoteRow n in notes) {
        final DateTime d = _toUtcDate(n.createdAt);
        if (perDay.containsKey(d)) {
          perDay[d] = (perDay[d] ?? 0) + 1;
        }
      }

      // ---- 6) letzte 7 Tage Stats
      final List<_NoteRow> last7 =
          notes.where((e) => e.createdAt.isAfter(from7)).toList();
      final int notesLast7 = last7.length;
      final int activeUsersLast7 =
          last7.map((e) => e.uid).where((id) => id.isNotEmpty).toSet().length;

      // ---- 7) Top Nutzer (14T)
      final Map<String, int> perUser14 = <String, int>{};
      for (final _NoteRow n in notes) {
        if (n.uid.isEmpty) continue;
        perUser14[n.uid] = (perUser14[n.uid] ?? 0) + 1;
      }
      final List<_TopUser> topUsers14d = perUser14.entries
          .map((e) => _TopUser(
                userId: e.key,
                name: names[e.key] ?? e.key,
                count: e.value,
              ))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      final List<_TopUser> top5 = topUsers14d.take(5).toList();

      setState(() {
        _stats = _Stats(
          totalUsers: totalUsers,
          totalNotes: totalNotes,
          notesLast7: notesLast7,
          activeUsersLast7: activeUsersLast7,
          ping: ping,
          perDay: perDay, // bereits sortierbar, keys = daysAsc
          topUsers14d: top5,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Fehler beim Laden: $e';
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $e')),
      );
    }
  }

  String _dur(Duration d) => '${d.inMilliseconds} ms';

  String _dayLabel(DateTime d) {
    final int dd = d.day;
    final int mm = d.month;
    return '${dd.toString().padLeft(2, '0')}.${mm.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin: Statistiken')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        ),
      );
    }
    final _Stats s = _stats!;
    final List<MapEntry<DateTime, int>> daysSorted =
        s.perDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final int maxDay = s.perDay.values.isEmpty
        ? 1
        : s.perDay.values.reduce((int a, int b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Statistiken'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Neu laden',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // KPIs
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _metricCard('Nutzer', s.totalUsers.toString(), Icons.people),
                _metricCard('Notizen', s.totalNotes.toString(), Icons.note),
                _metricCard('Notizen 7T', s.notesLast7.toString(), Icons.timeline),
                _metricCard('Aktive Nutzer 7T', s.activeUsersLast7.toString(), Icons.person_pin_circle),
                _metricCard('DB Ping', _dur(s.ping), Icons.speed),
              ],
            ),
            const SizedBox(height: 16),

            // Notes per day
            Text('Notizen pro Tag (14T)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: daysSorted.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Keine Daten in den letzten 14 Tagen'),
                      )
                    : Column(
                        children: daysSorted.map((MapEntry<DateTime, int> e) {
                          final double v = maxDay == 0
                              ? 0
                              : (e.value / maxDay).clamp(0, 1).toDouble();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 52,
                                  child: Text(_dayLabel(e.key)),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(value: v, minHeight: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    e.value.toString(),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Top users
            Text('Top Nutzer (14T)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: s.topUsers14d.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Keine Notizaktivität in den letzten 14 Tagen'),
                    )
                  : Column(
                      children: s.topUsers14d.map((e) {
                        return ListTile(
                          leading: const Icon(Icons.emoji_events),
                          title: Text(e.name),
                          subtitle: Text(e.userId),
                          trailing: Text(e.count.toString()),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 200,
      height: 96,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteRow {
  final String uid;
  final DateTime createdAt;
  const _NoteRow({required this.uid, required this.createdAt});
}

class _TopUser {
  final String userId;
  final String name;
  final int count;
  const _TopUser({required this.userId, required this.name, required this.count});
}

class _Stats {
  final int totalUsers;
  final int totalNotes;
  final int notesLast7;
  final int activeUsersLast7;
  final Duration ping;
  final Map<DateTime, int> perDay;
  final List<_TopUser> topUsers14d;
  const _Stats({
    required this.totalUsers,
    required this.totalNotes,
    required this.notesLast7,
    required this.activeUsersLast7,
    required this.ping,
    required this.perDay,
    required this.topUsers14d,
  });
}
