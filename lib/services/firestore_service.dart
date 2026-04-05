import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestoreへのすべての読み書きをまとめたサービスクラス。
/// Firestoreの構造:
///   users/{uid}/entries/{yyyy-M-d}   → {entries: [...]}  日ごと記録
///   users/{uid}/monthly/{type-yyyy-M} → {entries: [...]}  月ごと固定費
///   users/{uid}/settings/app          → カテゴリ・設定
class FirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('users').doc(_uid).collection('entries');

  static CollectionReference<Map<String, dynamic>> get _monthly =>
      _db.collection('users').doc(_uid).collection('monthly');

  static DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('users').doc(_uid).collection('settings').doc('app');

  // ── 日ごと記録 ────────────────────────────────────────────────────────

  static String _dailyKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static Future<List<Map<String, String>>> getDailyEntries(DateTime date) async {
    final doc = await _entries.doc(_dailyKey(date)).get();
    if (!doc.exists) return [];
    final list = (doc.data()?['entries'] as List<dynamic>?) ?? [];
    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  static Future<void> setDailyEntries(
      DateTime date, List<Map<String, String>> entries) async {
    final ref = _entries.doc(_dailyKey(date));
    if (entries.isEmpty) {
      await ref.delete();
    } else {
      await ref.set({'entries': entries});
    }
  }

  // ── 月ごと固定費 ──────────────────────────────────────────────────────

  static String _monthlyKey(String type, DateTime month) =>
      '$type-${month.year}-${month.month}';

  static Future<List<Map<String, String>>> getMonthlyEntries(
      String type, DateTime month) async {
    final doc = await _monthly.doc(_monthlyKey(type, month)).get();
    if (!doc.exists) return [];
    final list = (doc.data()?['entries'] as List<dynamic>?) ?? [];
    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  static Future<void> setMonthlyEntries(
      String type, DateTime month, List<Map<String, String>> entries) async {
    final ref = _monthly.doc(_monthlyKey(type, month));
    if (entries.isEmpty) {
      await ref.delete();
    } else {
      await ref.set({'entries': entries});
    }
  }

  // ── 分析用: 全日ごと記録を取得 ────────────────────────────────────────

  /// キー({yyyy-M-d}) → entries のマップを返す
  static Future<Map<String, List<Map<String, String>>>>
      getAllDailyEntries() async {
    final snapshot = await _entries.get();
    final result = <String, List<Map<String, String>>>{};
    for (final doc in snapshot.docs) {
      final list = (doc.data()['entries'] as List<dynamic>?) ?? [];
      result[doc.id] =
          list.map((e) => Map<String, String>.from(e as Map)).toList();
    }
    return result;
  }

  /// キー({type-yyyy-M}) → entries のマップを返す
  static Future<Map<String, List<Map<String, String>>>>
      getAllMonthlyEntries() async {
    final snapshot = await _monthly.get();
    final result = <String, List<Map<String, String>>>{};
    for (final doc in snapshot.docs) {
      final list = (doc.data()['entries'] as List<dynamic>?) ?? [];
      result[doc.id] =
          list.map((e) => Map<String, String>.from(e as Map)).toList();
    }
    return result;
  }

  // ── 定期支払い（サブスクリプション）──────────────────────────────────

  static Future<List<Map<String, String>>> getSubscriptions() async {
    final doc = await _settings.get();
    if (!doc.exists) return [];
    final list = (doc.data()?['subscriptions'] as List<dynamic>?) ?? [];
    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  static Future<void> setSubscriptions(
      List<Map<String, String>> subscriptions) async {
    await _settings.set({'subscriptions': subscriptions}, SetOptions(merge: true));
  }

  // ── 設定・カテゴリ ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSettings() async {
    final doc = await _settings.get();
    if (!doc.exists) return {};
    return doc.data() ?? {};
  }

  static Future<void> saveSettings(Map<String, dynamic> data) async {
    await _settings.set(data, SetOptions(merge: true));
  }
}
