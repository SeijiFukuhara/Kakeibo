import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class CalendarScreen extends StatefulWidget {
  final void Function(DateTime month)? onNavigateToAnalysis;

  const CalendarScreen({super.key, this.onNavigateToAnalysis});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  void reloadSettings() {
    _loadCategories();
  }

  /// 入力画面などで保存があったあとにカレンダーを最新状態に更新する
  void reloadData() {
    _loadMonthData(_focusedDay);
    _loadMonthBudget(_focusedDay);
    _loadSubscriptions();
  }
  DateTime _focusedDay = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _selectedDay;

  List<Map<String, String>> _monthlyEvents = [];
  // 日ごと入力用カテゴリ
  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];
  // 月ごと入力用カテゴリ
  List<String> _monthlyExpenseCats = [];
  List<String> _monthlyIncomeCats = [];

  // 月の開始日・先頭曜日（設定から読み込む）
  int _monthStartDay = 1;
  int _firstDayOfWeek = 0; // 0=日, 1=月, 6=土

  // カレンダースワイプ用
  double _dragOffset = 0;

  // 月固定エントリ（複数対応）
  List<Map<String, String>> _monthIncomeEntries = [];
  List<Map<String, String>> _monthExpenseEntries = [];

  // 定期支払い
  List<Map<String, String>> _subscriptions = [];

  // カテゴリフィルター（複数選択）
  Set<String> _filterCategories = {};


  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthData(_selectedDay!);
    _loadMonthBudget(_selectedDay!);
    _loadCategories();
    _loadSubscriptions();
  }

  // ── 月固定エントリのロード ──────────────────────────────────────────
  Future<void> _loadMonthBudget(DateTime date) async {
    final incomeEntries = await FirestoreService.getMonthlyEntries('income', date);
    final expenseEntries = await FirestoreService.getMonthlyEntries('expense', date);
    setState(() {
      _monthIncomeEntries = incomeEntries;
      _monthExpenseEntries = expenseEntries;
    });
  }

  // ── 定期支払いのロード ────────────────────────────────────────────
  Future<void> _loadSubscriptions() async {
    final subs = await FirestoreService.getSubscriptions();
    setState(() => _subscriptions = subs);
  }

  bool _isSubApplicable(Map<String, String> s, DateTime month) {
    final startStr = s['startYearMonth'] ?? '';
    final endStr = s['endYearMonth'] ?? '';
    final isYearly = s['cycle'] == 'yearly';

    if (isYearly) {
      // 年単位：'YYYY' 形式（後方互換で 'YYYY-M' も許容）
      if (startStr.isNotEmpty) {
        final startYear = int.tryParse(startStr.split('-')[0]) ?? 0;
        if (month.year < startYear) return false;
      }
      if (endStr.isNotEmpty) {
        final endYear = int.tryParse(endStr.split('-')[0]) ?? 0;
        if (month.year > endYear) return false;
      }
    } else {
      // 月単位：'YYYY-M' 形式
      if (startStr.isNotEmpty) {
        final parts = startStr.split('-');
        if (parts.length == 2) {
          final startMonth = DateTime(
              int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
          if (month.isBefore(startMonth)) return false;
        }
      }
      if (endStr.isNotEmpty) {
        final parts = endStr.split('-');
        if (parts.length == 2) {
          final endMonth = DateTime(
              int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
          if (month.isAfter(endMonth)) return false;
        }
      }
    }
    return true;
  }

  // ── 月固定エントリの追加 ──────────────────────────────────────────
  Future<void> _addMonthIncome(
      String? category, int amount, String day, String comment) async {
    final entries = List<Map<String, String>>.from(_monthIncomeEntries);
    entries.add({
      'title': category ?? '収入',
      'amount': '$amount',
      'day': day,
      'comment': comment,
    });
    await FirestoreService.setMonthlyEntries('income', _focusedDay, entries);
    await _loadMonthBudget(_focusedDay);
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
    await FirestoreService.setMonthlyEntries('expense', _focusedDay, entries);
    await _loadMonthBudget(_focusedDay);
  }

  // ── 月固定エントリの編集 ──────────────────────────────────────────
  Future<void> _editMonthEntry(String type, int index, String? category,
      int amount, String day, String comment) async {
    if (type == 'income') {
      final entries = List<Map<String, String>>.from(_monthIncomeEntries);
      entries[index] = {
        'title': category ?? '収入',
        'amount': '$amount',
        'day': day,
        'comment': comment,
      };
      await FirestoreService.setMonthlyEntries('income', _focusedDay, entries);
    } else {
      final entries = List<Map<String, String>>.from(_monthExpenseEntries);
      entries[index] = {
        'title': category ?? '支出',
        'amount': '$amount',
        'day': day,
        'comment': comment,
      };
      await FirestoreService.setMonthlyEntries('expense', _focusedDay, entries);
    }
    await _loadMonthBudget(_focusedDay);
  }

  // ── 月固定エントリの削除 ──────────────────────────────────────────
  Future<void> _deleteMonthEntry(String type, int index) async {
    if (type == 'income') {
      final entries = List<Map<String, String>>.from(_monthIncomeEntries);
      entries.removeAt(index);
      await FirestoreService.setMonthlyEntries('income', _focusedDay, entries);
    } else {
      final entries = List<Map<String, String>>.from(_monthExpenseEntries);
      entries.removeAt(index);
      await FirestoreService.setMonthlyEntries('expense', _focusedDay, entries);
    }
    await _loadMonthBudget(_focusedDay);
  }

  // ── 日エントリの編集 ──────────────────────────────────────────────
  Future<void> _editDailyEvent(
      Map<String, String> event, String? category, String type, int amount, String comment, DateTime newDate) async {
    final storageKey = event['storageKey']!;
    final eventIndex = int.parse(event['eventIndex']!);
    final parts = storageKey.split('-');
    final origDate = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    // 元の日付から削除
    final origEntries = await FirestoreService.getDailyEntries(origDate);
    if (eventIndex < origEntries.length) origEntries.removeAt(eventIndex);
    await FirestoreService.setDailyEntries(origDate, origEntries);
    // 新しい日付に追加
    final newEntries = await FirestoreService.getDailyEntries(newDate);
    newEntries.add({
      'title': category ?? '',
      'amount': '$amount',
      'type': type,
      'comment': comment,
    });
    await FirestoreService.setDailyEntries(newDate, newEntries);
    await _loadMonthData(_focusedDay);
  }

  // ── 年月選択ピッカー ────────────────────────────────────────────────
  void _showMonthPicker() {
    int tempYear = _focusedDay.year;
    int tempMonth = _focusedDay.month;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: tempYear,
                items: List.generate(
                  11,
                  (i) => DropdownMenuItem(
                    value: DateTime.now().year - 5 + i,
                    child: Text('${DateTime.now().year - 5 + i}年'),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setDs(() => tempYear = v);
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: tempMonth,
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('${i + 1}月'),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setDs(() => tempMonth = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final newDay = DateTime(tempYear, tempMonth);
                setState(() => _focusedDay = newDay);
                _loadMonthData(newDay);
                _loadMonthBudget(newDay);
                Navigator.pop(ctx);
              },
              child: const Text('決定'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 月ごとリストダイアログ（〇月の収支を登録ボタン用）────────────
  void _showMonthListDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          final allEntries = [
            ...List.generate(_monthIncomeEntries.length, (i) => {
              ..._monthIncomeEntries[i], 'type': 'income', 'entryIndex': '$i',
            }),
            ...List.generate(_monthExpenseEntries.length, (i) => {
              ..._monthExpenseEntries[i], 'type': 'expense', 'entryIndex': '$i',
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
                    child: Text('${_focusedDay.month}月の入力',
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
                          final color = isIncome ? Colors.green : Colors.red;
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
                                  style: TextStyle(color: color, fontSize: 11)),
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
                                      style: const TextStyle(fontSize: 11))
                                  : null;
                            }(),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '¥${_formatAmount(int.tryParse(e['amount'] ?? '0') ?? 0)}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  onPressed: () async {
                                    await _deleteMonthEntry(e['type']!, idx);
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

  // ── 月ごとエントリ入力フォーム（新規・編集共通）──────────────────
  Future<void> _showMonthlyEntryFormDialog({
    String? initialType,
    int? editIndex,
    Map<String, String>? editEntry,
  }) async {
    final isEdit = editEntry != null;
    String inputType = isEdit
        ? (editEntry['type'] ?? initialType ?? 'expense')
        : (initialType ?? 'expense');
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);

    List<String> cats() =>
        inputType == 'income' ? _monthlyIncomeCats : _monthlyExpenseCats;

    String? selectedCategory = isEdit
        ? (cats().contains(editEntry['title'])
            ? editEntry['title']
            : (cats().isNotEmpty ? cats()[0] : null))
        : (cats().isNotEmpty ? cats()[0] : null);
    final amountCtrl =
        TextEditingController(text: isEdit ? (editEntry['amount'] ?? '') : '');
    final commentCtrl =
        TextEditingController(text: isEdit ? (editEntry['comment'] ?? '') : '');
    int? inputDay =
        isEdit ? int.tryParse(editEntry['day'] ?? '') : null;

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
                          ButtonSegment(value: 'income', label: Text('収入')),
                          ButtonSegment(value: 'expense', label: Text('支出')),
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
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setDs(() => selectedCategory = v),
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
                                value: i + 1, child: Text('${i + 1}日')),
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

  // ── カテゴリロード ────────────────────────────────────────────────
  Future<void> _loadCategories() async {
    final data = await FirestoreService.getSettings();
    setState(() {
      _monthStartDay = (data['month_start_day'] as int?) ?? 1;
      _firstDayOfWeek = (data['first_day_of_week'] as int?) ?? 0;
      _expenseCategories = List<String>.from(
          data['categories'] ?? ['食費', '日用品', '交通費']);
      _incomeCategories = List<String>.from(
          data['income_categories'] ?? ['給与', '副収入', 'その他']);
      _monthlyExpenseCats = List<String>.from(
          data['monthly_expense_categories'] ?? ['家賃', '光熱費', '通信費']);
      _monthlyIncomeCats = List<String>.from(
          data['monthly_income_categories'] ?? ['給与', '副収入']);
    });
  }

  // ── 月の開始日に基づく日付範囲 ────────────────────────────────────
  (DateTime, DateTime) _getMonthRange(DateTime month) {
    if (_monthStartDay <= 1) {
      return (
        DateTime(month.year, month.month, 1),
        DateTime(month.year, month.month + 1, 0),
      );
    }
    // 例: 開始日=16, 月=3月 → 2/16〜3/15
    return (
      DateTime(month.year, month.month - 1, _monthStartDay),
      DateTime(month.year, month.month, _monthStartDay - 1),
    );
  }

  // ── 月データロード ────────────────────────────────────────────────
  Future<void> _loadMonthData(DateTime date) async {
    final settings = await FirestoreService.getSettings();
    _monthStartDay = (settings['month_start_day'] as int?) ?? 1;
    final (rangeStart, rangeEnd) = _getMonthRange(date);
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

      final decoded = entry.value;
      for (var i = 0; i < decoded.length; i++) {
        final event = decoded[i];
        monthEvents.add({
          'title': event['title'] ?? '',
          'amount': event['amount'] ?? '0',
          'type': event['type'] ?? 'expense',
          'comment': event['comment'] ?? '',
          'date': '$month/$day',
          'storageKey': key,
          'eventIndex': '$i',
        });
      }
    }

    monthEvents.sort((a, b) {
      final aDay = int.tryParse(a['date']!.split('/')[1]) ?? 0;
      final bDay = int.tryParse(b['date']!.split('/')[1]) ?? 0;
      return aDay.compareTo(bDay);
    });

    setState(() {
      _monthlyEvents = monthEvents;
    });
  }

  // ── 日データ削除 ─────────────────────────────────────────────────
  Future<void> _deleteMonthlyEvent(Map<String, String> event) async {
    final storageKey = event['storageKey'];
    final eventIndex = int.tryParse(event['eventIndex'] ?? '');
    if (storageKey == null || eventIndex == null) return;
    final parts = storageKey.split('-');
    if (parts.length != 3) return;
    final date = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final entries = await FirestoreService.getDailyEntries(date);
    if (eventIndex >= entries.length) return;
    entries.removeAt(eventIndex);
    await FirestoreService.setDailyEntries(date, entries);
    await _loadMonthData(_focusedDay);
  }

  Future<void> _confirmAndDeleteMonthlyEvent(
      Map<String, String> event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認'),
        content: const Text('削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) await _deleteMonthlyEvent(event);
  }

  // ── 日付タップ入力ダイアログ ─────────────────────────────────────
  // ── 日付タップ: 履歴＋新規作成ダイアログ（中央表示）───────────────
  void _showInputSheet(DateTime date) {
    const wds = ['月', '火', '水', '木', '金', '土', '日'];
    final wd = wds[date.weekday - 1];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final dateKey = '${date.year}-${date.month}-${date.day}';
          final dayEvents = _monthlyEvents
              .where((e) => e['storageKey'] == dateKey)
              .toList();

          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '${date.month}月${date.day}日（$wd）',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('新規作成'),
                    onTap: () async {
                      await _showDailyEntryDialog(date);
                      setSheetState(() {});
                    },
                  ),
                  if (dayEvents.isNotEmpty) ...[
                    const Divider(height: 1),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: dayEvents.map((e) {
                          final isIncome = e['type'] == 'income';
                          final color = isIncome ? Colors.green : Colors.red;
                          return ListTile(
                            dense: true,
                            onTap: () async {
                              final parts = e['storageKey']?.split('-') ?? [];
                              final tapDate = parts.length == 3
                                  ? DateTime(int.parse(parts[0]),
                                      int.parse(parts[1]), int.parse(parts[2]))
                                  : date;
                              await _showDailyEntryDialog(tapDate,
                                  editEvent: e);
                              setSheetState(() {});
                            },
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isIncome ? '収入' : '支出',
                                style: TextStyle(color: color, fontSize: 11),
                              ),
                            ),
                            title: Text(e['title'] ?? '',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: e['comment']?.isNotEmpty == true
                                ? Text(e['comment']!,
                                    style: const TextStyle(fontSize: 11))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '¥${_formatAmount(int.tryParse(e['amount'] ?? '0') ?? 0)}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  onPressed: () async {
                                    await _confirmAndDeleteMonthlyEvent(e);
                                    setSheetState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('キャンセル',
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

  // ── 日ごとエントリ入力フォーム（新規・編集共通）────────────────────
  Future<void> _showDailyEntryDialog(DateTime date,
      {Map<String, String>? editEvent}) async {
    await _loadCategories();
    if (!mounted) return;

    final isEdit = editEvent != null;
    String inputType = isEdit ? (editEvent['type'] ?? 'expense') : 'expense';

    List<String> cats() =>
        inputType == 'income' ? _incomeCategories : _expenseCategories;

    String? selectedCategory = isEdit
        ? (cats().contains(editEvent['title'])
            ? editEvent['title']
            : (cats().isNotEmpty ? cats()[0] : null))
        : (cats().isNotEmpty ? cats()[0] : null);

    DateTime selectedDate = DateTime(date.year, date.month, date.day);
    final amountCtrl =
        TextEditingController(text: isEdit ? (editEvent['amount'] ?? '') : '');
    final commentCtrl =
        TextEditingController(text: isEdit ? (editEvent['comment'] ?? '') : '');

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
                          ButtonSegment(value: 'income', label: Text('収入')),
                          ButtonSegment(value: 'expense', label: Text('支出')),
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
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setDs(() => selectedCategory = v),
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
                      DropdownButtonHideUnderline(
                        child: DropdownButton<DateTime>(
                          value: selectedDate,
                          isExpanded: true,
                          items: List.generate(
                            DateUtils.getDaysInMonth(
                                selectedDate.year, selectedDate.month),
                            (i) {
                              final d = DateTime(selectedDate.year,
                                  selectedDate.month, i + 1);
                              const wds = ['月', '火', '水', '木', '金', '土', '日'];
                              return DropdownMenuItem(
                                value: d,
                                child: Text(
                                    '${d.month}月${d.day}日（${wds[d.weekday - 1]}）'),
                              );
                            },
                          ),
                          onChanged: (d) {
                            if (d != null) setDs(() => selectedDate = d);
                          },
                        ),
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
                          if (selectedCategory == null ||
                              amountCtrl.text.isEmpty) { return; }
                          if (isEdit) {
                            await _editDailyEvent(
                              editEvent,
                              selectedCategory,
                              inputType,
                              int.tryParse(amountCtrl.text) ?? 0,
                              commentCtrl.text,
                              selectedDate,
                            );
                          } else {
                            final events = await FirestoreService
                                .getDailyEntries(selectedDate);
                            events.add({
                              'title': selectedCategory!,
                              'amount': amountCtrl.text,
                              'type': inputType,
                              'comment': commentCtrl.text,
                            });
                            await FirestoreService.setDailyEntries(
                                selectedDate, events);
                            await _loadMonthData(selectedDate);
                          }
                          if (!mounted) return;
                          setState(() {
                            _selectedDay = selectedDate;
                            _focusedDay = selectedDate;
                          });
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

  // ── 金額フォーマット ──────────────────────────────────────────────
  String _formatAmount(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  // ── カレンダー日付セル ────────────────────────────────────────────
  Widget _buildDayCell(
    DateTime day,
    BoxDecoration? circleDecoration,
    Color dayTextColor,
    Map<String, Map<String, int>> dailyTotals, {
    bool isFiltered = false,
  }) {
    final key = '${day.year}-${day.month}-${day.day}';
    final totals = dailyTotals[key];
    final income = totals?['income'] ?? 0;
    final expense = totals?['expense'] ?? 0;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isFiltered
                    ? Colors.indigo.withValues(alpha: 0.12)
                    : null,
                border: Border.all(
                  color: isFiltered
                      ? Colors.indigo.withValues(alpha: 0.5)
                      : Colors.grey.shade300,
                  width: isFiltered ? 1.2 : 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日付：上段
                    Container(
                      width: 18,
                      height: 18,
                      decoration: circleDecoration,
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(fontSize: 10, color: dayTextColor),
                        ),
                      ),
                    ),
                    // 金額：収入＋支出を常に2行で中央に固定表示
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              income > 0 ? _formatAmount(income) : '',
                              style: const TextStyle(
                                  color: Colors.green, fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              expense > 0 ? _formatAmount(expense) : '',
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // フィルター一致インジケーター（右上の小さな丸）
          if (isFiltered)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.indigo,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

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
                Text(label, style: TextStyle(fontSize: 10, color: color)),
                const SizedBox(width: 2),
                Icon(Icons.pie_chart_outline, size: 10, color: color),
              ],
            ),
            Text(
              '¥${_formatAmount(amount)}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── カテゴリフィルターダイアログ（複数選択）────────────────────────
  void _showCategoryFilterDialog() {
    final allCategories = [
      ...{..._expenseCategories, ..._incomeCategories}
    ]..sort();

    // ダイアログ内で一時的な選択状態を管理
    final tempSelected = Set<String>.from(_filterCategories);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          child: Container(
            width: 360,
            constraints: const BoxConstraints(maxHeight: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 18),
                      const SizedBox(width: 8),
                      const Text('項目を選択（複数可）',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (tempSelected.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setDs(() => tempSelected.clear());
                          },
                          child: const Text('クリア',
                              style: TextStyle(color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: allCategories.length,
                    itemBuilder: (_, i) {
                      final cat = allCategories[i];
                      final isSelected = tempSelected.contains(cat);
                      return ListTile(
                        dense: true,
                        title: Text(cat),
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (_) => setDs(() {
                            if (isSelected) {
                              tempSelected.remove(cat);
                            } else {
                              tempSelected.add(cat);
                            }
                          }),
                        ),
                        tileColor: isSelected
                            ? Colors.indigo.withValues(alpha: 0.08)
                            : null,
                        onTap: () => setDs(() {
                          if (isSelected) {
                            tempSelected.remove(cat);
                          } else {
                            tempSelected.add(cat);
                          }
                        }),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('キャンセル',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _filterCategories = Set.from(tempSelected));
                          Navigator.pop(ctx);
                        },
                        child: const Text('適用'),
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
  }

  // ── 円グラフダイアログ ────────────────────────────────────────────
  void _showPieChartDialog({
    required String title,
    required List<Map<String, String>> entries,
    required Color color,
  }) {
    // カテゴリ別に集計
    final Map<String, int> categoryTotals = {};
    for (final e in entries) {
      final cat = e['title'] ?? '不明';
      final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
    }
    final total = categoryTotals.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データがありません'), duration: Duration(seconds: 2)),
      );
      return;
    }

    // パレット
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
                    Text('¥${_formatAmount(total)}',
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
                          painter: _PieChartPainter(
                            data: sortedEntries
                                .asMap()
                                .entries
                                .map((e) => _PieSlice(
                                      value: e.value.value.toDouble(),
                                      color: palette[e.key % palette.length],
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
                        final pct = (amt / total * 100).toStringAsFixed(1);
                        final pieColor = palette[idx % palette.length];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: pieColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(cat,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Text('$pct%',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(width: 8),
                              Text('¥${_formatAmount(amt)}',
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

  // ── 定期払い一覧ダイアログ ──────────────────────────────────────────
  void _showSubscriptionListDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          return Dialog(
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
                                fontSize: 16, fontWeight: FontWeight.bold)),
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
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _subscriptions.length,
                        itemBuilder: (_, i) {
                          final s = _subscriptions[i];
                          final isIncome = s['type'] == 'income';
                          final isYearly = s['cycle'] == 'yearly';
                          final color = isIncome ? Colors.green : Colors.red;
                          final day = s['billingDay'] ?? '';
                          final memo = s['memo'] ?? '';
                          final amount = int.tryParse(s['amount'] ?? '0') ?? 0;
                          final monthlyAmount = isYearly ? (amount / 12).round() : amount;
                          return ListTile(
                            dense: true,
                            onTap: () async {
                              await _showSubscriptionFormDialog(
                                  editIndex: i, existing: s);
                              setDs(() {});
                            },
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(isIncome ? '収入' : '支出',
                                      style: TextStyle(color: color, fontSize: 10)),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isYearly
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isYearly ? '年払' : '毎月',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isYearly
                                            ? Colors.orange.shade700
                                            : Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(s['title'] ?? ''),
                            subtitle: Text(
                              [
                                if (day.isNotEmpty)
                                  isYearly ? '毎年$day月' : '毎月$day日',
                                if (memo.isNotEmpty) memo,
                              ].join('　'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '¥${_formatAmount(monthlyAmount)}/月',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: color),
                                    ),
                                    if (isYearly)
                                      Text(
                                        '年額 ¥${_formatAmount(amount)}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600),
                                      ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
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
                                    if (ok == true) {
                                      final subs = List<Map<String, String>>.from(
                                          _subscriptions);
                                      subs.removeAt(i);
                                      await FirestoreService.setSubscriptions(
                                          subs);
                                      await _loadSubscriptions();
                                      setDs(() {});
                                    }
                                  },
                                ),
                              ],
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
          );
        },
      ),
    );
  }

  // ── 定期払い追加・編集フォーム ─────────────────────────────────────
  Future<void> _showSubscriptionFormDialog({
    int? editIndex,
    Map<String, String>? existing,
  }) async {
    final isEdit = existing != null;
    String subType = isEdit ? (existing['type'] ?? 'expense') : 'expense';
    String cycle = isEdit ? (existing['cycle'] ?? 'monthly') : 'monthly';
    List<String> cats() =>
        subType == 'income' ? _monthlyIncomeCats : _monthlyExpenseCats;
    String? selectedCat = isEdit
        ? (cats().contains(existing['title'])
            ? existing['title']
            : (cats().isNotEmpty ? cats()[0] : null))
        : (cats().isNotEmpty ? cats()[0] : null);
    final amountCtrl =
        TextEditingController(text: isEdit ? (existing['amount'] ?? '') : '');
    final memoCtrl =
        TextEditingController(text: isEdit ? (existing['memo'] ?? '') : '');
    int? billingDay =
        isEdit ? int.tryParse(existing['billingDay'] ?? '') : null;

    // 開始・終了を年・月の個別変数で管理
    int? startYear, startMonth, endYear, endMonth;
    if (isEdit) {
      final s = existing['startYearMonth'] ?? '';
      final e = existing['endYearMonth'] ?? '';
      if (s.isNotEmpty) {
        final p = s.split('-');
        startYear = int.tryParse(p[0]);
        startMonth = p.length > 1 ? int.tryParse(p[1]) : null;
      }
      if (e.isNotEmpty) {
        final p = e.split('-');
        endYear = int.tryParse(p[0]);
        endMonth = p.length > 1 ? int.tryParse(p[1]) : null;
      }
    }
    String buildYM(int? y, int? m) =>
        (y != null && m != null) ? '$y-$m' : '';

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
                            ButtonSegment(value: 'income', label: Text('収入')),
                            ButtonSegment(value: 'expense', label: Text('支出')),
                          ],
                          selected: {subType},
                          onSelectionChanged: (s) => setDs(() {
                            subType = s.first;
                            selectedCat =
                                cats().isNotEmpty ? cats()[0] : null;
                          }),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'monthly',
                                icon: Icon(Icons.calendar_month, size: 15),
                                label: Text('毎月')),
                            ButtonSegment(
                                value: 'yearly',
                                icon: Icon(Icons.event_repeat, size: 15),
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
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          autofocus: !isEdit,
                          decoration: InputDecoration(
                              labelText: '金額',
                              hintText: '例：1000',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              suffixText: cycle == 'yearly' ? '円/年' : '円/月',
                              border: const OutlineInputBorder(),
                              isDense: true),
                        ),
                        if (cycle == 'yearly')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Builder(builder: (_) {
                              final y = int.tryParse(amountCtrl.text) ?? 0;
                              return Text(
                                '月あたり約 ¥${(y / 12).round()} として計算されます',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              );
                            }),
                          ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCat,
                          decoration: const InputDecoration(
                              labelText: 'カテゴリ',
                              border: OutlineInputBorder(),
                              isDense: true),
                          items: cats()
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setDs(() => selectedCat = v),
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
                                      value: null, child: Text('指定なし')),
                                  ...List.generate(
                                      12,
                                      (i) => DropdownMenuItem(
                                          value: i + 1,
                                          child: Text('毎年${i + 1}月'))),
                                ]
                              : [
                                  const DropdownMenuItem(
                                      value: null, child: Text('指定なし')),
                                  ...List.generate(
                                      31,
                                      (i) => DropdownMenuItem(
                                          value: i + 1,
                                          child: Text('毎月${i + 1}日'))),
                                ],
                          onChanged: (v) => setDs(() => billingDay = v),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: memoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'メモ（任意）',
                              hintText: 'メモを入力',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                        const SizedBox(height: 12),
                        // ── 開始年月 ──
                        _InlineYMPicker(
                          label: '開始（任意）',
                          year: startYear,
                          month: startMonth,
                          onChanged: (y, m) =>
                              setDs(() { startYear = y; startMonth = m; }),
                        ),
                        const SizedBox(height: 10),
                        // ── 終了年月 ──
                        _InlineYMPicker(
                          label: '終了（任意）',
                          year: endYear,
                          month: endMonth,
                          onChanged: (y, m) =>
                              setDs(() { endYear = y; endMonth = m; }),
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
                                content: const Text('この定期払いを削除しますか？'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('キャンセル')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('削除',
                                          style:
                                              TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (ok == true && editIndex != null) {
                              final subs = List<Map<String, String>>.from(
                                  _subscriptions);
                              subs.removeAt(editIndex);
                              await FirestoreService.setSubscriptions(subs);
                              await _loadSubscriptions();
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
                              selectedCat == null) { return; }
                          final now = DateTime.now();
                          final effectiveStart =
                              buildYM(startYear, startMonth).isNotEmpty
                                  ? buildYM(startYear, startMonth)
                                  : '${now.year}-${now.month}';
                          final newSub = {
                            'type': subType,
                            'cycle': cycle,
                            'title': selectedCat!,
                            'amount': amountCtrl.text,
                            'billingDay': billingDay?.toString() ?? '',
                            'startYearMonth': effectiveStart,
                            'endYearMonth': buildYM(endYear, endMonth),
                            'memo': memoCtrl.text,
                          };
                          final subs = List<Map<String, String>>.from(
                              _subscriptions);
                          if (isEdit && editIndex != null) {
                            subs[editIndex] = newSub;
                          } else {
                            subs.add(newSub);
                          }
                          await FirestoreService.setSubscriptions(subs);
                          await _loadSubscriptions();
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
    amountCtrl.dispose();
    memoCtrl.dispose();
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
    // 定期支払い合計（当月適用分、年単位は÷12）
    int subMonthlyAmount(Map<String, String> s) {
      final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
      return s['cycle'] == 'yearly' ? (raw / 12).round() : raw;
    }
    final subIncomeSum = _subscriptions
        .where((s) => s['type'] == 'income' && _isSubApplicable(s, _focusedDay))
        .fold(0, (sum, s) => sum + subMonthlyAmount(s));
    final subExpenseSum = _subscriptions
        .where((s) => s['type'] == 'expense' && _isSubApplicable(s, _focusedDay))
        .fold(0, (sum, s) => sum + subMonthlyAmount(s));
    final totalIncome = monthIncomeSum + incomeSum + subIncomeSum;
    final totalExpense = monthExpenseSum + expenseSum + subExpenseSum;
    final balance = totalIncome - totalExpense;

    // 日別合計マップ（キー: "year-month-day"）
    final dailyTotals = <String, Map<String, int>>{};
    for (final e in _monthlyEvents) {
      final key = e['storageKey']!;
      dailyTotals.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
      if (e['type'] == 'income') {
        dailyTotals[key]!['income'] =
            (dailyTotals[key]!['income'] ?? 0) + amount;
      } else {
        dailyTotals[key]!['expense'] =
            (dailyTotals[key]!['expense'] ?? 0) + amount;
      }
    }

    // カテゴリフィルター一致日セット（複数選択対応）
    final filteredDays = <String>{};
    if (_filterCategories.isNotEmpty) {
      for (final e in _monthlyEvents) {
        if (_filterCategories.contains(e['title'])) {
          filteredDays.add(e['storageKey']!);
        }
      }
    }

    // 当月に適用可能な定期支払い
    final applicableSubs = _subscriptions
        .where((s) => _isSubApplicable(s, _focusedDay))
        .toList();

    // 定期→月固定→日ごとの順に表示
    final incomeDisplayEvents = [
      ...applicableSubs
          .where((s) => s['type'] == 'income')
          .map((s) {
            final isYearly = s['cycle'] == 'yearly';
            final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
            return {
              'title': s['title'] ?? '',
              'amount': '${isYearly ? (raw / 12).round() : raw}',
              'day': s['billingDay'] ?? '',
              'comment': s['memo'] ?? '',
              'type': 'income',
              'date': isYearly ? '年払' : '定期',
            };
          }),
      ...List.generate(
        _monthIncomeEntries.length,
        (i) => {
          'title': _monthIncomeEntries[i]['title'] ?? '',
          'amount': _monthIncomeEntries[i]['amount'] ?? '0',
          'day': _monthIncomeEntries[i]['day'] ?? '',
          'comment': _monthIncomeEntries[i]['comment'] ?? '',
          'type': 'income',
          'date': '月固定',
          'isFixed': 'true',
          'fixedIndex': '$i',
        },
      ),
      ...incomeEvents,
    ];
    final expenseDisplayEvents = [
      ...applicableSubs
          .where((s) => s['type'] == 'expense')
          .map((s) {
            final isYearly = s['cycle'] == 'yearly';
            final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
            return {
              'title': s['title'] ?? '',
              'amount': '${isYearly ? (raw / 12).round() : raw}',
              'day': s['billingDay'] ?? '',
              'comment': s['memo'] ?? '',
              'type': 'expense',
              'date': isYearly ? '年払' : '定期',
            };
          }),
      ...List.generate(
        _monthExpenseEntries.length,
        (i) => {
          'title': _monthExpenseEntries[i]['title'] ?? '',
          'amount': _monthExpenseEntries[i]['amount'] ?? '0',
          'day': _monthExpenseEntries[i]['day'] ?? '',
          'comment': _monthExpenseEntries[i]['comment'] ?? '',
          'type': 'expense',
          'date': '月固定',
          'isFixed': 'true',
          'fixedIndex': '$i',
        },
      ),
      ...expenseEvents,
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
              GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() => _dragOffset += details.delta.dx);
            },
            onHorizontalDragEnd: (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              final threshold = screenWidth / 3;
              if (_dragOffset < -threshold) {
                final next = DateTime(_focusedDay.year, _focusedDay.month + 1);
                setState(() { _focusedDay = next; _dragOffset = 0; });
                _loadMonthData(next);
                _loadMonthBudget(next);
              } else if (_dragOffset > threshold) {
                final prev = DateTime(_focusedDay.year, _focusedDay.month - 1);
                setState(() { _focusedDay = prev; _dragOffset = 0; });
                _loadMonthData(prev);
                _loadMonthBudget(prev);
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: TableCalendar(
            availableGestures: AvailableGestures.none,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            locale: 'ja_JP',
            rowHeight: 52,
            daysOfWeekHeight: 28,
            startingDayOfWeek: switch (_firstDayOfWeek) {
              1 => StartingDayOfWeek.monday,
              6 => StartingDayOfWeek.saturday,
              _ => StartingDayOfWeek.sunday,
            },
            availableCalendarFormats: const {CalendarFormat.month: ''},
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _loadMonthData(selectedDay);
              _showInputSheet(selectedDay);
            },
            onHeaderTapped: (_) => _showMonthPicker(),
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              _loadMonthData(focusedDay);
              _loadMonthBudget(focusedDay);
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final key = '${day.year}-${day.month}-${day.day}';
                return _buildDayCell(day, null, Colors.black87, dailyTotals,
                    isFiltered: filteredDays.contains(key));
              },
              outsideBuilder: (context, day, focusedDay) =>
                  _buildDayCell(day, null, Colors.grey.shade400, const {}),
              todayBuilder: (context, day, focusedDay) {
                final key = '${day.year}-${day.month}-${day.day}';
                return _buildDayCell(
                  day,
                  BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  Colors.white,
                  dailyTotals,
                  isFiltered: filteredDays.contains(key),
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                final key = '${day.year}-${day.month}-${day.day}';
                return _buildDayCell(
                  day,
                  const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  Colors.white,
                  dailyTotals,
                  isFiltered: filteredDays.contains(key),
                );
              },
              headerTitleBuilder: (context, day) {
                return InkWell(
                  onTap: _showMonthPicker,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Text(
                      '${day.year}年${day.month}月',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                );
              },
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          ),
          ),

          // ボタン行: 月の収支登録 ／ 定期払い管理
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _showMonthListDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text('${_focusedDay.month}月の収支を登録',
                        overflow: TextOverflow.ellipsis),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _showSubscriptionListDialog,
                    icon: const Icon(Icons.repeat_outlined, size: 16),
                    label: const Text('定期払い',
                        overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _showCategoryFilterDialog,
                    icon: Icon(Icons.filter_list,
                        size: 16,
                        color: _filterCategories.isNotEmpty
                            ? Colors.white
                            : Colors.indigo),
                    label: Text(
                      _filterCategories.isEmpty
                          ? 'フィルター'
                          : '${_filterCategories.length}件選択',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _filterCategories.isNotEmpty
                            ? Colors.white
                            : Colors.indigo,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      backgroundColor: _filterCategories.isNotEmpty
                          ? Colors.indigo
                          : Colors.indigo.withValues(alpha: 0.06),
                      side: const BorderSide(color: Colors.indigo),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 月合計バー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryTile('収入', totalIncome, Colors.green,
                      onTap: () => _showPieChartDialog(
                            title: '収入の内訳',
                            entries: incomeDisplayEvents,
                            color: Colors.green,
                          )),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSummaryTile('支出', totalExpense, Colors.red,
                      onTap: () => _showPieChartDialog(
                            title: '支出の内訳',
                            entries: expenseDisplayEvents,
                            color: Colors.red,
                          )),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSummaryTile(
                    '合計',
                    balance,
                    balance >= 0 ? Colors.blue : Colors.orange,
                    onTap: () => _showPieChartDialog(
                          title: '収支の内訳',
                          entries: [
                            ...incomeDisplayEvents
                                .map((e) => {...e, 'title': '収入:${e['title']}'}),
                            ...expenseDisplayEvents
                                .map((e) => {...e, 'title': '支出:${e['title']}'}),
                          ],
                          color: balance >= 0 ? Colors.blue : Colors.orange,
                        ),
                  ),
                ),
              ],
            ),
          ),

        ],
        ),
      ),
    );
  }

}


class _PieSlice {
  final double value;
  final Color color;
  const _PieSlice({required this.value, required this.color});
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSlice> data;
  const _PieChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold(0.0, (sum, s) => sum + s.value);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    double startAngle = -math.pi / 2;
    for (final slice in data) {
      final sweep = 2 * math.pi * slice.value / total;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      // 区切り線
      final divider = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        divider,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => old.data != data;
}

// ── 年月インラインピッカー ─────────────────────────────────────────────────
class _InlineYMPicker extends StatelessWidget {
  final String label;
  final int? year;
  final int? month;
  final void Function(int? year, int? month) onChanged;
  final bool showMonth; // false のとき年のみ表示（年単位サブスク用）

  const _InlineYMPicker({
    required this.label,
    required this.year,
    required this.month,
    required this.onChanged,
    this.showMonth = true,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isSet = year != null || month != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (isSet) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => onChanged(null, null),
                child: const Text('クリア',
                    style: TextStyle(fontSize: 11, color: Colors.blue)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '年',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: year,
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('---')),
                      ...List.generate(11, (i) {
                        final y = now.year - 1 + i;
                        return DropdownMenuItem(value: y, child: Text('$y年'));
                      }),
                    ],
                    onChanged: (v) => onChanged(v, showMonth ? month : null),
                  ),
                ),
              ),
            ),
            if (showMonth) ...[
              const SizedBox(width: 6),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '月',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: month,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('---')),
                        ...List.generate(12,
                            (i) => DropdownMenuItem(
                                value: i + 1, child: Text('${i + 1}月'))),
                      ],
                      onChanged: (v) => onChanged(year, v),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

