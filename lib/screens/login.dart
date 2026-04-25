import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api.dart';
import '../config.dart';
import '../theme.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _busy = false;
  bool _showPass = false;
  String? _err;

  Future<void> _submit() async {
    setState(() { _busy = true; _err = null; });
    try {
      await Api.login(_u.text.trim(), _p.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _busy = true; _err = null; });
    try {
      // serverClientId MUST be the web client ID — that tells Google to issue
      // an ID token whose `aud` matches the backend's allowed audiences.
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConfig.googleServerClientId,
      );
      // Force the account picker every time, even if a previous account is cached.
      // This is what makes the picker appear after a logout, instead of silently
      // re-using the last account.
      try { await google.signOut(); } catch (_) {}
      final acct = await google.signIn();
      if (acct == null) {
        setState(() => _busy = false);
        return; // user cancelled
      }
      final auth = await acct.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        setState(() { _err = 'No ID token from Google (configure OAuth client first)'; _busy = false; });
        return;
      }
      await Api.loginWithGoogle(idToken);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Google sign-in (preferred)
            FilledButton.icon(
              icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.white),
              label: const Text('Continue with Google'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : _googleSignIn,
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Container(height: 1, color: AppTheme.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('OR PHONE / EMAIL', style: TextStyle(color: AppTheme.textLo, fontSize: 11, letterSpacing: 1)),
              ),
              Expanded(child: Container(height: 1, color: AppTheme.line)),
            ]),
            const SizedBox(height: 14),
            TextField(controller: _u, decoration: const InputDecoration(labelText: 'Phone or Email', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
              controller: _p,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                  tooltip: _showPass ? 'Hide' : 'Show',
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_err!, style: const TextStyle(color: Colors.redAccent))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Sign in'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('New here? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
