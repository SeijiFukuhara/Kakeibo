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

  // unavailable 時はデフォルト値を返す（クラッシュさせない）
  static Future<T> _read<T>(Future<T> Function() fn, T defaultValue) async {
    try {
      return await fn();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') return defaultValue;
      rethrow;
    }
  }

  // unavailable を指数バックオフでリトライ（最大3回）、それでも失敗なら無視
  static Future<void> _write(Future<void> Function() fn) async {
    var delay = const Duration(milliseconds: 500);
    for (var i = 0; i < 4; i++) {
      try {
        await fn();
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'unavailable') rethrow;
        if (i == 3) return;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }

  static CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('users').doc(_uid).collection('entries');

  static CollectionReference<Map<String, dynamic>> get _monthly =>
      _db.collection('users').doc(_uid).collection('monthly');

  static DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('users').doc(_uid).collection('settings').doc('app');

  // ── 日ごと記録 ────────────────────────────────────────────────────────

  static String _dailyKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static Future<List<Map<String, String>>> getDailyEntries(DateTime date) =>
      _read(() async {
        final doc = await _entries.doc(_dailyKey(date)).get();
        if (!doc.exists) return [];
        final list = (doc.data()?['entries'] as List<dynamic>?) ?? [];
        return list.map((e) => Map<String, String>.from(e as Map)).toList();
      }, []);

  static Future<void> setDailyEntries(
          DateTime date, List<Map<String, String>> entries) =>
      _write(() async {
        final ref = _entries.doc(_dailyKey(date));
        if (entries.isEmpty) {
          await ref.delete();
        } else {
          await ref.set({'entries': entries});
        }
      });

  // ── 月ごと固定費 ──────────────────────────────────────────────────────

  static String _monthlyKey(String type, DateTime month) =>
      '$type-${month.year}-${month.month}';

  static Future<List<Map<String, String>>> getMonthlyEntries(
          String type, DateTime month) =>
      _read(() async {
        final doc = await _monthly.doc(_monthlyKey(type, month)).get();
        if (!doc.exists) return [];
        final list = (doc.data()?['entries'] as List<dynamic>?) ?? [];
        return list.map((e) => Map<String, String>.from(e as Map)).toList();
      }, []);

  static Future<void> setMonthlyEntries(
          String type, DateTime month, List<Map<String, String>> entries) =>
      _write(() async {
        final ref = _monthly.doc(_monthlyKey(type, month));
        if (entries.isEmpty) {
          await ref.delete();
        } else {
          await ref.set({'entries': entries});
        }
      });

  // ── 分析用: 全日ごと記録を取得 ────────────────────────────────────────

  /// キー({yyyy-M-d}) → entries のマップを返す
  static Future<Map<String, List<Map<String, String>>>> getAllDailyEntries() =>
      _read(() async {
        final snapshot = await _entries.get();
        final result = <String, List<Map<String, String>>>{};
        for (final doc in snapshot.docs) {
          final list = (doc.data()['entries'] as List<dynamic>?) ?? [];
          result[doc.id] =
              list.map((e) => Map<String, String>.from(e as Map)).toList();
        }
        return result;
      }, {});

  /// キー({type-yyyy-M}) → entries のマップを返す
  static Future<Map<String, List<Map<String, String>>>> getAllMonthlyEntries() =>
      _read(() async {
        final snapshot = await _monthly.get();
        final result = <String, List<Map<String, String>>>{};
        for (final doc in snapshot.docs) {
          final list = (doc.data()['entries'] as List<dynamic>?) ?? [];
          result[doc.id] =
              list.map((e) => Map<String, String>.from(e as Map)).toList();
        }
        return result;
      }, {});

  // ── 定期支払い（サブスクリプション）──────────────────────────────────

  static Future<List<Map<String, String>>> getSubscriptions() =>
      _read(() async {
        final doc = await _settings.get();
        if (!doc.exists) return [];
        final list = (doc.data()?['subscriptions'] as List<dynamic>?) ?? [];
        return list.map((e) => Map<String, String>.from(e as Map)).toList();
      }, []);

  static Future<void> setSubscriptions(
          List<Map<String, String>> subscriptions) =>
      _write(() =>
          _settings.set({'subscriptions': subscriptions}, SetOptions(merge: true)));

  // ── 設定・カテゴリ ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSettings() =>
      _read(() async {
        final doc = await _settings.get();
        if (!doc.exists) return {};
        return doc.data() ?? {};
      }, {});

  static Future<void> saveSettings(Map<String, dynamic> data) =>
      _write(() => _settings.set(data, SetOptions(merge: true)));

  // ── 予算（月別） ─────────────────────────────────────────────────────────

  static String _budgetMonthKey(DateTime month) =>
      '${month.year}-${month.month}';

  static Future<Map<String, int>> getBudgets(DateTime month) =>
      _read(() async {
        final monthKey = _budgetMonthKey(month);
        final doc = await _settings.get();
        if (!doc.exists) return {};
        final budgets = doc.data()?['budgets'] as Map<String, dynamic>?;
        if (budgets == null) return {};
        final monthBudgets = budgets[monthKey] as Map<String, dynamic>?;
        if (monthBudgets == null) return {};
        return monthBudgets.map((k, v) => MapEntry(k, (v as num).toInt()));
      }, {});

  static Future<void> saveBudgets(
          DateTime month, Map<String, int> budgets) =>
      _write(() async {
        final monthKey = _budgetMonthKey(month);
        final doc = await _settings.get();
        final existing = Map<String, dynamic>.from(
            (doc.data()?['budgets'] as Map<String, dynamic>?) ?? {});
        if (budgets.isEmpty) {
          existing.remove(monthKey);
        } else {
          existing[monthKey] = budgets;
        }
        await _settings.set({'budgets': existing}, SetOptions(merge: true));
      });
}
