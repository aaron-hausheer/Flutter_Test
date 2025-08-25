import 'package:supabase_flutter/supabase_flutter.dart';

bool isAdmin() {
  final User? u = Supabase.instance.client.auth.currentUser;
  final Map<String, dynamic> app = u?.appMetadata ?? const <String, dynamic>{};
  final Map<String, dynamic> user = u?.userMetadata ?? const <String, dynamic>{};
  final dynamic r1 = app['role'];
  final dynamic r2 = user['role'];
  final dynamic f1 = app['is_admin'] ?? user['is_admin'];
  if (r1 == 'admin') return true;
  if (r2 == 'admin') return true;
  if (f1 == true) return true;
  return false;
}
