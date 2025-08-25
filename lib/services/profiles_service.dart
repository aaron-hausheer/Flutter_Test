import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilesService {
  SupabaseClient get _sb => Supabase.instance.client;

  Future<Map<String, String>> fetchDisplayNames() async {
    final List<dynamic> res = await _sb.from('profiles').select('id, display_name');
    final Map<String, String> m = <String, String>{};
    for (final dynamic row in res) {
      final Map<String, dynamic> r = row as Map<String, dynamic>;
      final String id = r['id'] as String;
      final String dn = (r['display_name'] as String?) ?? '';
      if (dn.isNotEmpty) m[id] = dn;
    }
    return m;
  }
}
