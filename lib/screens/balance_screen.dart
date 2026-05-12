import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => BalanceScreenState();
}

class BalanceScreenState extends State<BalanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _monthStartDay = 1;
  bool _loading = true;

  List<Map<String, String>> _monthlyEvents = [];
  List<Map<String, String>> _monthExpenseEntries = [];
  List<Map<String, String>> _monthIncomeEntries = [];
  List<Map<String, String>> _subscriptions = [];
  List<String> _monthlyExpenseCats = [];
  List<String> _monthlyIncomeCats = [];

  void reload() => _loadData();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  (DateTime, DateTime) _getMonthRange(DateTime month) {
    if (_monthStartDay <= 1) {
      return (
        DateTime(month.year, month.month, 1),
        DateTime(month.year, month.month + 1, 0),
      );
    }
    return (
      DateTime(month.year, month.month - 1, _monthStartDay),
      DateTime(month.year, month.month, _monthStartDay - 1),
    );
  }

  bool _isSubApplicable(Map<String, String> s, DateTime month) {
    final startStr = s['startYearMonth'] ?? '';
    final endStr = s['endYearMonth'] ?? '';
    final isYearly = s['cycle'] == 'yearly';
    if (isYearly) {
      if (startStr.isNotEmpty) {
        final startYear = int.tryParse(startStr.split('-')[0]) ?? 0;
        if (month.year < startYear) return false;
      }
      if (endStr.isNotEmpty) {
        final endYear = int.tryParse(endStr.split('-')[0]) ?? 0;
        if (month.year > endYear) return false;
      }
    } else {
      if (startStr.isNotEmpty) {
        final parts = startStr.split('-');
        if (parts.length == 2) {
          final start = DateTime(
              int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
          if (month.isBefore(start)) return false;
        }
      }
      if (endStr.isNotEmpty) {
        final parts = endStr.split('-');
        if (parts.length == 2) {
          final end = DateTime(
              int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
          if (month.isAfter(end)) return false;
        }
      }
    }
    return true;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final settings = await FirestoreService.getSettings();
    _monthStartDay = (settings['month_start_day'] as int?) ?? 1;

    final expCats =
        List<String>.from(settings['monthly_expense_categories'] ?? []);
    final incCats =
        List<String>.from(settings['monthly_income_categories'] ?? []);

    final incEntries =
        await FirestoreService.getMonthlyEntries('income', _month);
    final expEntries =
        await FirestoreService.getMonthlyEntries('expense', _month);
    final subs = await FirestoreService.getSubscriptions();

    final (rangeStart, rangeEnd) = _getMonthRange(_month);
    final monthEvents = <Map<String, String>>[];
    final allEntries = await FirestoreService.getAllDailyEntries();
    for (final entry in allEntries.entries) {
      final key = entry.key;
      final parts = key.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;
      final keyDate = DateTime(year, month, day);
      if (keyDate.isBefore(rangeStart) || keyDate.isAfter(rangeEnd)) continue;
      for (var i = 0; i < entry.value.length; i++) {
        final e = entry.value[i];
        monthEvents.add({
          'title': e['title'] ?? '',
          'amount': e['amount'] ?? '0',
          'type': e['type'] ?? 'expense',
          'comment': e['comment'] ?? '',
          'date': '$month/$day',
          'storageKey': key,
          'eventIndex': '$i',
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _monthIncomeEntries = incEntries;
      _monthExpenseEntries = expEntries;
      _subscriptions = subs;
      _monthlyEvents = monthEvents;
      _monthlyExpenseCats = expCats;
      _monthlyIncomeCats = incCats;
      _loading = false;
    });
  }

  Future<void> _addMonthExpense(
      String? category, int amount, String day, String comment) async {
    final entries = List<Map<String, String>>.from(_monthExpenseEntries);
    entries.add({
      'title': category ?? '支出',
      'amount': '$amount',
      'day': day,
      'comment': comment,
    });
    await FirestoreService.setMonthlyEntries('expense', _month, entries);
    await _loadData();
  }

  Future<void> _addMonthIncome(
      String? category, int amount, String day, String comment) async {
    final entries = List<Map<String, String>>.from(_monthIncomeEntries);
    entries.add({
      'title': category ?? '収入',
      'amount': '$amount',
      'day': day,
      'comment': comment,
    });
    await FirestoreService.setMonthlyEntries('income', _month, entries);
    await _loadData();
  }

  Future<void> _editMonthEntry(String type, int index, String? category,
      int amount, String day, String comment) async {
    if (type == 'expense') {
      final entries = List<Map<String, String>>.from(_monthExpenseEntries);
      entries[index] = {
        'title': category ?? '支出',
        'amount': '$amount',
        'day': day,
        'comment': comment,
      };
      await FirestoreService.setMonthlyEntries('expense', _month, entries);
    } else {
      final entries = List<Map<String, String>>.from(_monthIncomeEntries);
      entries[index] = {
        'title': category ?? '収入',
        'amount': '$amount',
        'day': day,
        'comment': comment,
      };
      await FirestoreService.setMonthlyEntries('income', _month, entries);
    }
    await _loadData();
  }

  Future<void> _deleteMonthEntry(String type, int index) async {
    if (type == 'expense') {
      final entries = List<Map<String, String>>.from(_monthExpenseEntries);
      entries.removeAt(index);
      await FirestoreService.setMonthlyEntries('expense', _month, entries);
    } else {
      final entries = List<Map<String, String>>.from(_monthIncomeEntries);
      entries.removeAt(index);
      await FirestoreService.setMonthlyEntries('income', _month, entries);
    }
    await _loadData();
  }

  String _fmt(int amount) => NumberFormat('#,###').format(amount);

  // ── 月ごとエントリ一覧ダイアログ ────────────────────────────────────
  void _showMonthListDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          final allEntries = [
            ...List.generate(
                _monthIncomeEntries.length,
                (i) => {
                      ..._monthIncomeEntries[i],
                      'type': 'income',
                      'entryIndex': '$i',
                    }),
            ...List.generate(
                _monthExpenseEntries.length,
                (i) => {
                      ..._monthExpenseEntries[i],
                      'type': 'expense',
                      'entryIndex': '$i',
                    }),
          ];
          return Dialog(
            child: Container(
              width: 420,
              constraints: const BoxConstraints(maxHeight: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text('${_month.month}月の入力',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('新規作成'),
                    onTap: () async {
                      await _showMonthlyEntryFormDialog();
                      setDs(() {});
                    },
                  ),
                  if (allEntries.isNotEmpty) ...[
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allEntries.length,
                        itemBuilder: (_, i) {
                          final e = allEntries[i];
                          final isIncome = e['type'] == 'income';
                          final color =
                              isIncome ? Colors.green : Colors.red;
                          final idx = int.parse(e['entryIndex']!);
                          return ListTile(
                            dense: true,
                            onTap: () async {
                              await _showMonthlyEntryFormDialog(
                                initialType: e['type'],
                                editIndex: idx,
                                editEntry: Map<String, String>.from(e),
                              );
                              setDs(() {});
                            },
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(isIncome ? '収入' : '支出',
                                  style: TextStyle(
                                      color: color, fontSize: 11)),
                            ),
                            title: Text(e['title'] ?? '',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: () {
                              final day = e['day'] ?? '';
                              final comment = e['comment'] ?? '';
                              final parts = [
                                if (day.isNotEmpty) '$day日',
                                if (comment.isNotEmpty) comment,
                              ];
                              return parts.isNotEmpty
                                  ? Text(parts.join('　'),
                                      style:
                                          const TextStyle(fontSize: 11))
                                  : null;
                            }(),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '¥${_fmt(int.tryParse(e['amount'] ?? '0') ?? 0)}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  onPressed: () async {
                                    await _deleteMonthEntry(
                                        e['type']!, idx);
                                    setDs(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('閉じる',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 月ごとエントリ入力フォーム ───────────────────────────────────────
  Future<void> _showMonthlyEntryFormDialog({
    String? initialType,
    int? editIndex,
    Map<String, String>? editEntry,
    String? initialCategory,
  }) async {
    final isEdit = editEntry != null;
    String inputType = isEdit
        ? (editEntry['type'] ?? initialType ?? 'expense')
        : (initialType ?? 'expense');
    final daysInMonth =
        DateUtils.getDaysInMonth(_month.year, _month.month);

    List<String> cats() =>
        inputType == 'income' ? _monthlyIncomeCats : _monthlyExpenseCats;

    String? selectedCategory = isEdit
        ? (cats().contains(editEntry['title'])
            ? editEntry['title']
            : (cats().isNotEmpty ? cats()[0] : null))
        : (initialCategory != null && cats().contains(initialCategory)
            ? initialCategory
            : (cats().isNotEmpty ? cats()[0] : null));

    final amountCtrl = TextEditingController(
        text: isEdit ? (editEntry['amount'] ?? '') : '');
    final commentCtrl = TextEditingController(
        text: isEdit ? (editEntry['comment'] ?? '') : '');
    int? inputDay = isEdit ? int.tryParse(editEntry['day'] ?? '') : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          child: Container(
            width: 420,
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'income', label: Text('収入')),
                          ButtonSegment(
                              value: 'expense', label: Text('支出')),
                        ],
                        selected: {inputType},
                        onSelectionChanged: (s) => setDs(() {
                          inputType = s.first;
                          selectedCategory =
                              cats().isNotEmpty ? cats()[0] : null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: '金額',
                            suffixText: '円',
                            border: OutlineInputBorder(),
                            isDense: true),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                            labelText: 'カテゴリ',
                            border: OutlineInputBorder(),
                            isDense: true),
                        items: cats()
                            .map((c) => DropdownMenuItem(
                                value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setDs(() => selectedCategory = v),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: commentCtrl,
                        decoration: const InputDecoration(
                            labelText: 'メモ（任意）',
                            border: OutlineInputBorder(),
                            isDense: true),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: inputDay,
                        decoration: const InputDecoration(
                            labelText: '日付（任意）',
                            border: OutlineInputBorder(),
                            isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('指定なし')),
                          ...List.generate(
                            daysInMonth,
                            (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}日')),
                          ),
                        ],
                        onChanged: (v) => setDs(() => inputDay = v),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('キャンセル'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (amountCtrl.text.isEmpty) return;
                          if (isEdit && editIndex != null) {
                            await _editMonthEntry(
                              inputType,
                              editIndex,
                              selectedCategory,
                              int.tryParse(amountCtrl.text) ?? 0,
                              inputDay?.toString() ?? '',
                              commentCtrl.text,
                            );
                          } else if (inputType == 'income') {
                            await _addMonthIncome(
                              selectedCategory,
                              int.tryParse(amountCtrl.text) ?? 0,
                              inputDay?.toString() ?? '',
                              commentCtrl.text,
                            );
                          } else {
                            await _addMonthExpense(
                              selectedCategory,
                              int.tryParse(amountCtrl.text) ?? 0,
                              inputDay?.toString() ?? '',
                              commentCtrl.text,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(isEdit ? '保存' : '追加する'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    amountCtrl.dispose();
    commentCtrl.dispose();
  }

  // ── 日々の収支詳細ダイアログ ────────────────────────────────────────
  void _showDailyEventsDetailDialog(
      String title, Color color, List<Map<String, String>> events) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('データがありません',
                          style: TextStyle(color: Colors.grey))),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final e = events[i];
                      final amount =
                          int.tryParse(e['amount'] ?? '0') ?? 0;
                      final date = e['date'] ?? '';
                      final comment = e['comment'] ?? '';
                      return ListTile(
                        dense: true,
                        title: Text(e['title'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: [date, comment]
                                .where((s) => s.isNotEmpty)
                                .isNotEmpty
                            ? Text(
                                [
                                  if (date.isNotEmpty) date,
                                  if (comment.isNotEmpty) comment,
                                ].join('　'),
                                style: const TextStyle(fontSize: 11))
                            : null,
                        trailing: Text(
                          '¥${_fmt(amount)}',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              const Divider(height: 1),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('閉じる',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 定期払い一覧ダイアログ ──────────────────────────────────────────
  void _showSubscriptionListDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          child: Container(
            width: 420,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Text('定期払い一覧',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          await _showSubscriptionFormDialog();
                          setDs(() {});
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('追加'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_subscriptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Text('定期払いが登録されていません',
                            style: TextStyle(color: Colors.grey))),
                  )
                else
                  Flexible(
                    child: Builder(builder: (_) {
                      final monthly = _subscriptions
                          .asMap()
                          .entries
                          .where((e) => e.value['cycle'] != 'yearly')
                          .toList();
                      final yearly = _subscriptions
                          .asMap()
                          .entries
                          .where((e) => e.value['cycle'] == 'yearly')
                          .toList();

                      Widget buildItem(
                          int origIdx, Map<String, String> s) {
                        final isIncome = s['type'] == 'income';
                        final isYearly = s['cycle'] == 'yearly';
                        final color =
                            isIncome ? Colors.green : Colors.red;
                        final day = s['billingDay'] ?? '';
                        final category = s['category'] ?? '';
                        final amount =
                            int.tryParse(s['amount'] ?? '0') ?? 0;
                        final monthlyAmount =
                            isYearly ? (amount / 12).round() : amount;
                        final subtitleParts = [
                          if (category.isNotEmpty) category,
                          if (day.isNotEmpty)
                            isYearly ? '毎年$day月' : '毎月$day日',
                        ];
                        return ListTile(
                          dense: true,
                          onTap: () async {
                            await _showSubscriptionFormDialog(
                                editIndex: origIdx, existing: s);
                            setDs(() {});
                          },
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(isIncome ? '収入' : '支出',
                                style: TextStyle(
                                    color: color, fontSize: 10)),
                          ),
                          title: Text(s['title'] ?? '',
                              style: const TextStyle(fontSize: 13)),
                          subtitle: subtitleParts.isNotEmpty
                              ? Text(subtitleParts.join('　'),
                                  style: const TextStyle(fontSize: 11))
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '¥${_fmt(monthlyAmount)}/月',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: color),
                                  ),
                                  if (isYearly)
                                    Text(
                                      '年額 ¥${_fmt(amount)}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('確認'),
                                      content: const Text(
                                          'この定期払いを削除しますか？'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                                    c, false),
                                            child: const Text(
                                                'キャンセル')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('削除',
                                                style: TextStyle(
                                                    color:
                                                        Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    final subs =
                                        List<Map<String, String>>.from(
                                            _subscriptions);
                                    subs.removeAt(origIdx);
                                    await FirestoreService
                                        .setSubscriptions(subs);
                                    await _loadData();
                                    setDs(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView(
                        shrinkWrap: true,
                        children: [
                          if (monthly.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 2),
                              child: Text('月単位',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const Divider(height: 1),
                            ...monthly
                                .map((e) => buildItem(e.key, e.value)),
                          ],
                          if (yearly.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 2),
                              child: Text('年単位',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const Divider(height: 1),
                            ...yearly
                                .map((e) => buildItem(e.key, e.value)),
                          ],
                        ],
                      );
                    }),
                  ),
                const Divider(height: 1),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('閉じる',
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 定期払い追加・編集フォーム ──────────────────────────────────────
  Future<void> _showSubscriptionFormDialog({
    int? editIndex,
    Map<String, String>? existing,
  }) async {
    final isEdit = existing != null;
    String subType =
        isEdit ? (existing['type'] ?? 'expense') : 'expense';
    String cycle =
        isEdit ? (existing['cycle'] ?? 'monthly') : 'monthly';
    final categoryCtrl = TextEditingController(
        text: isEdit ? (existing['category'] ?? '') : '');
    final titleCtrl = TextEditingController(
        text: isEdit ? (existing['title'] ?? '') : '');
    final amountCtrl = TextEditingController(
        text: isEdit ? (existing['amount'] ?? '') : '');
    int? billingDay =
        isEdit ? int.tryParse(existing['billingDay'] ?? '') : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(isEdit ? '定期払いを編集' : '定期払いを追加',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'income', label: Text('収入')),
                            ButtonSegment(
                                value: 'expense', label: Text('支出')),
                          ],
                          selected: {subType},
                          onSelectionChanged: (s) =>
                              setDs(() => subType = s.first),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'monthly',
                                icon: Icon(Icons.calendar_month,
                                    size: 15),
                                label: Text('毎月')),
                            ButtonSegment(
                                value: 'yearly',
                                icon: Icon(Icons.event_repeat,
                                    size: 15),
                                label: Text('年単位')),
                          ],
                          selected: {cycle},
                          onSelectionChanged: (s) => setDs(() {
                            cycle = s.first;
                            billingDay = null;
                          }),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: titleCtrl,
                          autofocus: !isEdit,
                          decoration: const InputDecoration(
                              labelText: 'サービス名',
                              hintText: '例：Netflix',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: '金額',
                              hintText: '例：1000',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              suffixText:
                                  cycle == 'yearly' ? '円/年' : '円/月',
                              border: const OutlineInputBorder(),
                              isDense: true),
                        ),
                        if (cycle == 'yearly')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Builder(builder: (_) {
                              final y =
                                  int.tryParse(amountCtrl.text) ?? 0;
                              return Text(
                                '月あたり約 ¥${(y / 12).round()} として計算されます',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              );
                            }),
                          ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: categoryCtrl,
                          decoration: const InputDecoration(
                              labelText: 'カテゴリ（任意）',
                              hintText: '例：動画配信',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int?>(
                          key: ValueKey(cycle),
                          initialValue: billingDay,
                          decoration: InputDecoration(
                              labelText: cycle == 'yearly'
                                  ? '引き落とし月（任意）'
                                  : '引き落とし日（任意）',
                              border: const OutlineInputBorder(),
                              isDense: true),
                          items: cycle == 'yearly'
                              ? [
                                  const DropdownMenuItem(
                                      value: null,
                                      child: Text('指定なし')),
                                  ...List.generate(
                                      12,
                                      (i) => DropdownMenuItem(
                                          value: i + 1,
                                          child: Text('毎年${i + 1}月'))),
                                ]
                              : [
                                  const DropdownMenuItem(
                                      value: null,
                                      child: Text('指定なし')),
                                  ...List.generate(
                                      31,
                                      (i) => DropdownMenuItem(
                                          value: i + 1,
                                          child: Text('毎月${i + 1}日'))),
                                ],
                          onChanged: (v) =>
                              setDs(() => billingDay = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    children: [
                      if (isEdit)
                        TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('確認'),
                                content:
                                    const Text('この定期払いを削除しますか？'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(c, false),
                                      child: const Text('キャンセル')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(c, true),
                                      child: const Text('削除',
                                          style: TextStyle(
                                              color: Colors.red))),
                                ],
                              ),
                            );
                            if (ok == true && editIndex != null) {
                              final subs =
                                  List<Map<String, String>>.from(
                                      _subscriptions);
                              subs.removeAt(editIndex);
                              await FirestoreService.setSubscriptions(
                                  subs);
                              await _loadData();
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          },
                          child: const Text('削除',
                              style: TextStyle(color: Colors.red)),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('キャンセル'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (amountCtrl.text.isEmpty ||
                              titleCtrl.text.trim().isEmpty) return;
                          final newSub = {
                            'type': subType,
                            'cycle': cycle,
                            'title': titleCtrl.text.trim(),
                            'category': categoryCtrl.text.trim(),
                            'amount': amountCtrl.text,
                            'billingDay': billingDay?.toString() ?? '',
                            'startYearMonth': '',
                            'endYearMonth': '',
                          };
                          final subs =
                              List<Map<String, String>>.from(
                                  _subscriptions);
                          if (isEdit && editIndex != null) {
                            subs[editIndex] = newSub;
                          } else {
                            subs.add(newSub);
                          }
                          await FirestoreService.setSubscriptions(subs);
                          await _loadData();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(isEdit ? '保存' : '追加'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    categoryCtrl.dispose();
    titleCtrl.dispose();
    amountCtrl.dispose();
  }

  // ── 円グラフダイアログ ────────────────────────────────────────────
  void _showPieChartDialog({
    required String title,
    required List<Map<String, String>> entries,
    required Color color,
  }) {
    final Map<String, int> categoryTotals = {};
    for (final e in entries) {
      final cat = e['title'] ?? '不明';
      final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
    }
    final total = categoryTotals.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('データがありません'),
            duration: Duration(seconds: 2)),
      );
      return;
    }
    const palette = [
      Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800),
      Color(0xFF9C27B0), Color(0xFFE91E63), Color(0xFF00BCD4),
      Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B),
      Color(0xFFFFC107),
    ];
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('¥${_fmt(total)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CustomPaint(
                          painter: _BalancePieChartPainter(
                            data: sortedEntries
                                .asMap()
                                .entries
                                .map((e) => _BalancePieSlice(
                                      value:
                                          e.value.value.toDouble(),
                                      color: palette[
                                          e.key % palette.length],
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...sortedEntries.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final cat = entry.value.key;
                        final amt = entry.value.value;
                        final pct =
                            (amt / total * 100).toStringAsFixed(1);
                        final pieColor =
                            palette[idx % palette.length];
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: pieColor,
                                  borderRadius:
                                      BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(cat,
                                    style: const TextStyle(
                                        fontSize: 13)),
                              ),
                              Text('$pct%',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                              const SizedBox(width: 8),
                              Text('¥${_fmt(amt)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('閉じる',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── サマリータイル ────────────────────────────────────────────────
  Widget _buildSummaryTile(String label, int amount, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: color)),
                const SizedBox(width: 2),
                Icon(Icons.pie_chart_outline, size: 10, color: color),
              ],
            ),
            Text(
              '¥${_fmt(amount)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedSummaryTile(
    String label,
    int total,
    Color color,
    List<(String, int, VoidCallback?)> breakdown, {
    VoidCallback? onTap,
  }) {
    final nonZero = breakdown.where((b) => b.$2 > 0).toList();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: TextStyle(fontSize: 12, color: color)),
                    const SizedBox(width: 2),
                    Icon(Icons.pie_chart_outline,
                        size: 12, color: color),
                  ],
                ),
                Flexible(
                  child: Text(
                    '¥${_fmt(total)}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (nonZero.isNotEmpty) ...[
              Divider(
                  height: 8,
                  thickness: 0.5,
                  color: color.withValues(alpha: 0.3)),
              ...nonZero.map(
                (b) => InkWell(
                  onTap: b.$3,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(b.$1,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        color.withValues(alpha: 0.85))),
                            if (b.$3 != null) ...[
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right,
                                  size: 14,
                                  color: color.withValues(alpha: 0.6)),
                            ],
                          ],
                        ),
                        Text('¥${_fmt(b.$2)}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: color.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final incomeEvents =
        _monthlyEvents.where((e) => e['type'] == 'income').toList();
    final expenseEvents =
        _monthlyEvents.where((e) => e['type'] != 'income').toList();

    final monthIncomeSum = _monthIncomeEntries.fold(
        0, (sum, e) => sum + (int.tryParse(e['amount'] ?? '0') ?? 0));
    final monthExpenseSum = _monthExpenseEntries.fold(
        0, (sum, e) => sum + (int.tryParse(e['amount'] ?? '0') ?? 0));
    final incomeSum = incomeEvents.fold(
        0, (sum, e) => sum + (int.tryParse(e['amount'] ?? '0') ?? 0));
    final expenseSum = expenseEvents.fold(
        0, (sum, e) => sum + (int.tryParse(e['amount'] ?? '0') ?? 0));

    int subMonthlyAmount(Map<String, String> s) {
      final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
      return s['cycle'] == 'yearly' ? (raw / 12).round() : raw;
    }

    final applicableSubs = _subscriptions
        .where((s) => _isSubApplicable(s, _month))
        .toList();
    final subIncomeSum = applicableSubs
        .where((s) => s['type'] == 'income')
        .fold(0, (sum, s) => sum + subMonthlyAmount(s));
    final subExpenseSum = applicableSubs
        .where((s) => s['type'] == 'expense')
        .fold(0, (sum, s) => sum + subMonthlyAmount(s));
    final totalIncome = monthIncomeSum + incomeSum + subIncomeSum;
    final totalExpense = monthExpenseSum + expenseSum + subExpenseSum;
    final balance = totalIncome - totalExpense;

    // 月の出費: 設定カテゴリすべてを表示（未登録は¥0）
    final expByCatIdx = <String, List<(int, Map<String, String>)>>{};
    for (var i = 0; i < _monthExpenseEntries.length; i++) {
      final e = _monthExpenseEntries[i];
      expByCatIdx.putIfAbsent(e['title'] ?? '', () => []).add((i, e));
    }
    final displayExpRows =
        <({String cat, int total, List<(int, Map<String, String>)> indexed})>[];
    for (final cat in _monthlyExpenseCats) {
      final indexed = expByCatIdx[cat] ?? [];
      final total = indexed.fold(
          0, (s, t) => s + (int.tryParse(t.$2['amount'] ?? '0') ?? 0));
      displayExpRows.add((cat: cat, total: total, indexed: indexed));
    }
    for (final cat in expByCatIdx.keys) {
      if (!_monthlyExpenseCats.contains(cat)) {
        final indexed = expByCatIdx[cat]!;
        final total = indexed.fold(
            0, (s, t) => s + (int.tryParse(t.$2['amount'] ?? '0') ?? 0));
        displayExpRows.add((cat: cat, total: total, indexed: indexed));
      }
    }

    // 円グラフ用イベントリスト
    final incomeDisplayEvents = [
      ...applicableSubs.where((s) => s['type'] == 'income').map((s) {
        final isYearly = s['cycle'] == 'yearly';
        final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
        return {
          'title': s['title'] ?? '',
          'amount': '${isYearly ? (raw / 12).round() : raw}',
          'type': 'income',
          'date': isYearly ? '年払' : '定期',
        };
      }),
      ...List.generate(
          _monthIncomeEntries.length,
          (i) => {
                'title': _monthIncomeEntries[i]['title'] ?? '',
                'amount': _monthIncomeEntries[i]['amount'] ?? '0',
                'type': 'income',
                'date': '月固定',
              }),
      ...incomeEvents,
    ];
    final expenseDisplayEvents = [
      ...applicableSubs.where((s) => s['type'] == 'expense').map((s) {
        final isYearly = s['cycle'] == 'yearly';
        final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
        return {
          'title': s['title'] ?? '',
          'amount': '${isYearly ? (raw / 12).round() : raw}',
          'type': 'expense',
          'date': isYearly ? '年払' : '定期',
        };
      }),
      ...List.generate(
          _monthExpenseEntries.length,
          (i) => {
                'title': _monthExpenseEntries[i]['title'] ?? '',
                'amount': _monthExpenseEntries[i]['amount'] ?? '0',
                'type': 'expense',
                'date': '月固定',
              }),
      ...expenseEvents,
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 月セレクター
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() => _month =
                          DateTime(_month.year, _month.month - 1));
                      _loadData();
                    },
                  ),
                  Text('${_month.year}年${_month.month}月',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() => _month =
                          DateTime(_month.year, _month.month + 1));
                      _loadData();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 月の出費カード
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 8, 12, 8),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: _showMonthListDialog,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('月',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color:
                                                      Colors.orange)),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('月の出費',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54)),
                                        const Spacer(),
                                        Text(
                                          '合計 ¥${_fmt(monthExpenseSum)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right,
                                            size: 16,
                                            color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Divider(height: 1),
                                  if (displayExpRows.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text('カテゴリ未設定',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    )
                                  else
                                    ...displayExpRows.map((row) {
                                      final hasEntry =
                                          row.indexed.isNotEmpty;
                                      return InkWell(
                                        onTap: () async {
                                          if (row.indexed.isEmpty) {
                                            await _showMonthlyEntryFormDialog(
                                              initialType: 'expense',
                                              initialCategory: row.cat,
                                            );
                                          } else if (row.indexed
                                                  .length ==
                                              1) {
                                            final (idx, entry) =
                                                row.indexed.first;
                                            await _showMonthlyEntryFormDialog(
                                              initialType: 'expense',
                                              editIndex: idx,
                                              editEntry: {
                                                ...entry,
                                                'type': 'expense'
                                              },
                                            );
                                          } else {
                                            _showMonthListDialog();
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              top: 6),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(row.cat,
                                                    style: const TextStyle(
                                                        fontSize: 13)),
                                              ),
                                              Text(
                                                '¥${_fmt(row.total)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: hasEntry
                                                      ? Colors.red
                                                      : Colors.grey,
                                                  fontWeight: hasEntry
                                                      ? FontWeight.w500
                                                      : FontWeight
                                                          .normal,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              const Icon(
                                                  Icons.chevron_right,
                                                  size: 14,
                                                  color: Colors.grey),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 収入タイル
                          _buildDetailedSummaryTile(
                            '収入',
                            totalIncome,
                            Colors.green,
                            [
                              (
                                '日々の記録',
                                incomeSum,
                                incomeSum > 0
                                    ? () => _showDailyEventsDetailDialog(
                                        '収入 日々の記録',
                                        Colors.green,
                                        incomeEvents)
                                    : null
                              ),
                              (
                                '月固定',
                                monthIncomeSum,
                                monthIncomeSum > 0
                                    ? _showMonthListDialog
                                    : null
                              ),
                              (
                                'サブスク',
                                subIncomeSum,
                                subIncomeSum > 0
                                    ? _showSubscriptionListDialog
                                    : null
                              ),
                            ],
                            onTap: () => _showPieChartDialog(
                              title: '収入の内訳',
                              entries: incomeDisplayEvents,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 支出タイル
                          _buildDetailedSummaryTile(
                            '支出',
                            totalExpense,
                            Colors.red,
                            [
                              (
                                '日々の記録',
                                expenseSum,
                                expenseSum > 0
                                    ? () => _showDailyEventsDetailDialog(
                                        '支出 日々の記録',
                                        Colors.red,
                                        expenseEvents)
                                    : null
                              ),
                              (
                                '月固定',
                                monthExpenseSum,
                                monthExpenseSum > 0
                                    ? _showMonthListDialog
                                    : null
                              ),
                              (
                                'サブスク',
                                subExpenseSum,
                                subExpenseSum > 0
                                    ? _showSubscriptionListDialog
                                    : null
                              ),
                            ],
                            onTap: () => _showPieChartDialog(
                              title: '支出の内訳',
                              entries: expenseDisplayEvents,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 合計タイル
                          _buildSummaryTile(
                            '合計',
                            balance,
                            balance >= 0 ? Colors.blue : Colors.orange,
                            onTap: () => _showPieChartDialog(
                              title: '収支の内訳',
                              entries: [
                                ...incomeDisplayEvents.map((e) =>
                                    {...e, 'title': '収入:${e['title']}'}),
                                ...expenseDisplayEvents.map((e) =>
                                    {...e, 'title': '支出:${e['title']}'}),
                              ],
                              color: balance >= 0
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalancePieSlice {
  final double value;
  final Color color;
  const _BalancePieSlice({required this.value, required this.color});
}

class _BalancePieChartPainter extends CustomPainter {
  final List<_BalancePieSlice> data;
  const _BalancePieChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold(0.0, (sum, s) => sum + s.value);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    double startAngle = -math.pi / 2;
    for (final slice in data) {
      final sweep = 2 * math.pi * slice.value / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, true,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.fill,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, true,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_BalancePieChartPainter old) => old.data != data;
}
