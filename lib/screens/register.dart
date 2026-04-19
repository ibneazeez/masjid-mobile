import 'package:flutter/material.dart';
import '../api.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _submit() async {
    setState(() { _busy = true; _err = null; });
    try {
      await Api.register(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        password: _pass.text,
      );
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
      appBar: AppBar(title: const Text('Register')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _name,  decoration: const InputDecoration(labelText: 'Full name',          border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone',              border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email (optional)',   border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _pass,  obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_err!, style: const TextStyle(color: Colors.redAccent))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Create account'),
          ),
          const SizedBox(height: 8),
          const Text('Approval by Masjid Admin / Committee President', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
