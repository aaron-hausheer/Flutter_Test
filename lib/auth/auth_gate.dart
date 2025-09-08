import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  void _syncRealtime(Session? s) {
    final SupabaseClient sb = Supabase.instance.client;
    final String token = s?.accessToken ?? '';
    sb.realtime.setAuth(token);
  }

  @override
  Widget build(BuildContext context) {
    final SupabaseClient sb = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: sb.auth.onAuthStateChange,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        final Session? session = sb.auth.currentSession;
        _syncRealtime(session);
        if (session == null) return const _LoginPage();
        return widget.child;
      },
    );
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage();
  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _displayNameCtrl = TextEditingController();
  bool _isLogin = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    setState(() => _busy = true);
    final SupabaseClient sb = Supabase.instance.client;
    try {
      if (_isLogin) {
        await sb.auth.signInWithPassword(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Angemeldet')));
      } else {
        final Map<String, dynamic> data = <String, dynamic>{'display_name': _displayNameCtrl.text.trim()};
        final AuthResponse r = await sb.auth.signUp(email: _emailCtrl.text.trim(), password: _passwordCtrl.text, data: data);
        if (mounted) {
          if (r.session != null && r.user != null) {
            try {
              await sb.from('profiles').upsert(<String, dynamic>{'id': r.user!.id, 'display_name': _displayNameCtrl.text.trim()});
            } catch (_) {}
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registriert und angemeldet')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registriert. Prüfe deine E-Mail zur Bestätigung.')));
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPw() async {
    final String email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-Mail eingeben')));
      return;
    }
    final SupabaseClient sb = Supabase.instance.client;
    try {
      await sb.auth.resetPasswordForEmail(email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-Mail zum Zurücksetzen gesendet')));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Anmelden' : 'Registrieren'), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!_isLogin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _displayNameCtrl,
                        decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.person)),
                        validator: (String? v) {
                          if (_isLogin) return null;
                          if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'E-Mail', prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (String? v) {
                      if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                      if (!v.contains('@')) return 'Ungültige E-Mail';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Passwort', prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                    validator: (String? v) {
                      if (v == null || v.isEmpty) return 'Pflichtfeld';
                      if (v.length < 6) return 'Mind. 6 Zeichen';
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      TextButton(onPressed: _busy ? null : _resetPw, child: const Text('Passwort vergessen?')),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() => _isLogin = !_isLogin);
                              },
                        child: Text(_isLogin ? 'Noch kein Konto? Registrieren' : 'Schon ein Konto? Anmelden'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                      label: Text(_isLogin ? 'Anmelden' : 'Registrieren'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
