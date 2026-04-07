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

  // ── 月固定エントリの削除確認（下部リストから）────────────────────
  Future<void> _deleteFixedEntry(Map<String, String> e) async {
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
    if (shouldDelete != true) return;
    final index = int.tryParse(e['fixedIndex'] ?? '');
    if (index == null) return;
    await _deleteMonthEntry(e['type'] ?? 'expense', index);
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
    Map<String, Map<String, int>> dailyTotals,
  ) {
    final key = '${day.year}-${day.month}-${day.day}';
    final totals = dailyTotals[key];
    final income = totals?['income'] ?? 0;
    final expense = totals?['expense'] ?? 0;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
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
    );
  }

  Widget _buildSummaryTile(String label, int amount, Color color) {
    return Container(
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
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          Text(
            '¥${_formatAmount(amount)}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
    // 定期支払い合計（当月適用分）
    final subIncomeSum = _subscriptions
        .where((s) => s['type'] == 'income' && _isSubApplicable(s, _focusedDay))
        .fold(0, (sum, s) => sum + (int.tryParse(s['amount'] ?? '0') ?? 0));
    final subExpenseSum = _subscriptions
        .where((s) => s['type'] == 'expense' && _isSubApplicable(s, _focusedDay))
        .fold(0, (sum, s) => sum + (int.tryParse(s['amount'] ?? '0') ?? 0));
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

    // 当月に適用可能な定期支払い
    final applicableSubs = _subscriptions
        .where((s) => _isSubApplicable(s, _focusedDay))
        .toList();

    // 定期→月固定→日ごとの順に表示
    final incomeDisplayEvents = [
      ...applicableSubs
          .where((s) => s['type'] == 'income')
          .map((s) => {
                'title': s['title'] ?? '',
                'amount': s['amount'] ?? '0',
                'day': s['billingDay'] ?? '',
                'comment': s['memo'] ?? '',
                'type': 'income',
                'date': '定期',
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
          .map((s) => {
                'title': s['title'] ?? '',
                'amount': s['amount'] ?? '0',
                'day': s['billingDay'] ?? '',
                'comment': s['memo'] ?? '',
                'type': 'expense',
                'date': '定期',
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
              defaultBuilder: (context, day, focusedDay) =>
                  _buildDayCell(day, null, Colors.black87, dailyTotals),
              outsideBuilder: (context, day, focusedDay) =>
                  _buildDayCell(day, null, Colors.grey.shade400, const {}),
              todayBuilder: (context, day, focusedDay) => _buildDayCell(
                day,
                BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                Colors.white,
                dailyTotals,
              ),
              selectedBuilder: (context, day, focusedDay) => _buildDayCell(
                day,
                const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                Colors.white,
                dailyTotals,
              ),
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

          // 月の収支登録ボタン
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showMonthListDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('${_focusedDay.month}月の収支を登録'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // 月合計バー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryTile('収入', totalIncome, Colors.green),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSummaryTile('支出', totalExpense, Colors.red),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSummaryTile(
                    '合計',
                    balance,
                    balance >= 0 ? Colors.blue : Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // 詳細パネル（ボタン直下・残余スペースを占有）
          Expanded(
            child: Material(
              elevation: 4,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Column(
                children: [
                  // ヘッダー行：「詳細」＋「大きく表示」ボタン
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text('詳細',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            builder: (ctx) => Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      const Text('詳細',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.bold)),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () =>
                                            Navigator.pop(ctx),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      _SubSectionHeader(
                                          label: '今月の収入',
                                          total:
                                              '¥${_formatAmount(totalIncome)}',
                                          color: Colors.green),
                                      if (incomeDisplayEvents.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Center(
                                              child: Text('データなし')),
                                        )
                                      else
                                        ...incomeDisplayEvents.map((e) =>
                                            _buildEventTile(
                                                e, Colors.green)),
                                      _SubSectionHeader(
                                          label: '今月の支出',
                                          total:
                                              '¥${_formatAmount(totalExpense)}',
                                          color: Colors.red),
                                      if (expenseDisplayEvents.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Center(
                                              child: Text('データなし')),
                                        )
                                      else
                                        ...expenseDisplayEvents.map((e) =>
                                            _buildEventTile(
                                                e, Colors.red)),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          icon: const Icon(Icons.open_in_full, size: 16),
                          label: const Text('大きく表示'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // スクロール可能なリスト
                  Expanded(
                    child: ListView(
                      children: [
                        _SubSectionHeader(
                            label: '今月の収入',
                            total: '¥${_formatAmount(totalIncome)}',
                            color: Colors.green),
                        if (incomeDisplayEvents.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: Text('データなし')),
                          )
                        else
                          ...incomeDisplayEvents.map(
                              (e) => _buildEventTile(e, Colors.green)),
                        _SubSectionHeader(
                            label: '今月の支出',
                            total: '¥${_formatAmount(totalExpense)}',
                            color: Colors.red),
                        if (expenseDisplayEvents.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: Text('データなし')),
                          )
                        else
                          ...expenseDisplayEvents.map(
                              (e) => _buildEventTile(e, Colors.red)),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildEventTile(Map<String, String> e, Color amountColor) {
    final day = e['day'] ?? '';
    final comment = e['comment'] ?? '';
    final parts = [
      if (day.isNotEmpty) '$day日',
      if (comment.isNotEmpty) comment,
    ];
    return ListTile(
      onTap: () {
        if (e['isFixed'] == 'true') {
          final idx = int.tryParse(e['fixedIndex'] ?? '');
          if (idx != null) {
            _showMonthlyEntryFormDialog(
              initialType: e['type'],
              editIndex: idx,
              editEntry: Map<String, String>.from(e),
            );
          }
        } else {
          final storageKeyParts = e['storageKey']?.split('-') ?? [];
          if (storageKeyParts.length == 3) {
            final tapDate = DateTime(
              int.parse(storageKeyParts[0]),
              int.parse(storageKeyParts[1]),
              int.parse(storageKeyParts[2]),
            );
            _showDailyEntryDialog(tapDate, editEvent: e);
          }
        }
      },
      title: Text('${e['date']} ${e['title']}'),
      subtitle: parts.isNotEmpty
          ? Text(parts.join('　'), style: const TextStyle(fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '¥${_formatAmount(int.tryParse(e['amount'] ?? '0') ?? 0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => e['isFixed'] == 'true'
                ? _deleteFixedEntry(e)
                : _confirmAndDeleteMonthlyEvent(e),
          ),
        ],
      ),
    );
  }

}


class _SubSectionHeader extends StatelessWidget {
  final String label;
  final String total;
  final Color color;

  const _SubSectionHeader({
    required this.label,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(
            total,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
