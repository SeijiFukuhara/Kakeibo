import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/account_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String? _error;
  bool _loading = false;
  List<SavedAccount> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await AccountStorage.loadAccounts();
    if (mounted) setState(() => _savedAccounts = accounts);
  }

  Future<void> _submit() async {
    await _signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      isRegister: !_isLogin,
    );
  }

  Future<void> _signIn({
    required String email,
    required String password,
    bool isRegister = false,
  }) async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      if (isRegister) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      await AccountStorage.saveAccount(email, password);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _toJapanese(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeAccount(SavedAccount account) async {
    await AccountStorage.removeAccount(account.email);
    await _loadSavedAccounts();
  }

  String _toJapanese(String code) {
    switch (code) {
      case 'user-not-found':
        return 'メールアドレスが見つかりません';
      case 'wrong-password':
        return 'パスワードが間違っています';
      case 'email-already-in-use':
        return 'このメールアドレスはすでに登録されています';
      case 'weak-password':
        return 'パスワードは6文字以上にしてください';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが間違っています';
      default:
        return 'エラーが発生しました（$code）';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'ログイン' : '新規登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 保存済みアカウント一覧
            if (_savedAccounts.isNotEmpty && _isLogin) ...[
              const Text('アカウントを選択', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._savedAccounts.map(
                (account) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: Text(account.email),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: '削除',
                      onPressed: _loading ? null : () => _removeAccount(account),
                    ),
                    onTap: _loading
                        ? null
                        : () => _signIn(email: account.email, password: account.password),
                  ),
                ),
              ),
              const Divider(height: 32),
              const Text('別のアカウント', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],

            // メール・パスワード入力フォーム
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード（6文字以上）',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isLogin ? 'ログイン' : '登録'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isLogin = !_isLogin;
                _error = null;
              }),
              child: Text(_isLogin ? '新規登録はこちら' : 'ログインはこちら'),
            ),
          ],
        ),
      ),
    );
  }
}
