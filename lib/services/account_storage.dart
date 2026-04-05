import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAccount {
  final String email;
  final String password;

  SavedAccount({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};

  factory SavedAccount.fromJson(Map<String, dynamic> json) =>
      SavedAccount(email: json['email'] as String, password: json['password'] as String);
}

class AccountStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'saved_accounts';

  static Future<List<SavedAccount>> loadAccounts() async {
    final json = await _storage.read(key: _key);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => SavedAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// ログイン成功後に呼ぶ。同じメールは上書き、新規は先頭に追加。
  static Future<void> saveAccount(String email, String password) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.email == email);
    accounts.insert(0, SavedAccount(email: email, password: password));
    await _storage.write(
      key: _key,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  static Future<void> removeAccount(String email) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.email == email);
    await _storage.write(
      key: _key,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }
}
