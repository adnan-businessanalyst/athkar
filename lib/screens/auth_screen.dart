import 'package:flutter/material.dart';

import '../state/athkar_store.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = StoreScope.of(context);
    try {
      if (_register) {
        await store.register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
      } else {
        await store.login(email: _email.text, password: _password.text);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'إنشاء حساب' : 'تسجيل الدخول')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _register
                ? 'الحساب اختياري. يمكنك الاستمرار كضيف دون اتصال.'
                : 'بعد الدخول تُزامَن العدادات والقوائم بين أجهزتك.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
          ),
          if (_register) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم (اختياري)'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'جارٍ...' : (_register ? 'إنشاء حساب' : 'دخول')),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _register = !_register),
            child: Text(_register ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد'),
          ),
        ],
      ),
    );
  }
}
