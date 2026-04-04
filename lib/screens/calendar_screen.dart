import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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
  DateTime _focusedDay = DateTime.now();
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

  // 月固定エントリ（複数対応）
  List<Map<String, String>> _monthIncomeEntries = [];
  List<Map<String, String>> _monthExpenseEntries = [];


  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthData(_selectedDay!);
    _loadMonthBudget(_selectedDay!);
    _loadCategories();
  }

  // ── 月固定エントリのロード ──────────────────────────────────────────
  Future<void> _loadMonthBudget(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final incomeKey = "monthly-income-${date.year}-${date.month}";
    final expenseKey = "monthly-expense-${date.year}-${date.month}";
    final incomeJson = prefs.getString(incomeKey);
    final expenseJson = prefs.getString(expenseKey);
    setState(() {
      _monthIncomeEntries = incomeJson != null
          ? List<Map<String, String>>.from(
              json.decode(incomeJson).map((i) => Map<String, String>.from(i)))
          : [];
      _monthExpenseEntries = expenseJson != null
          ? List<Map<String, String>>.from(
              json.decode(expenseJson).map((i) => Map<String, String>.from(i)))
          : [];
    });
  }

  // ── 月固定エントリの追加 ──────────────────────────────────────────
  Future<void> _addMonthIncome(
      String? category, int amount, String day, String comment) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "monthly-income-${_focusedDay.year}-${_focusedDay.month}";
    final entries = List<Map<String, String>>.from(_monthIncomeEntries);
    entries.add({
      'title': category ?? '収入',
      'amount': '$amount',
      'day': day,
      'comment': comment,
    });
    await prefs.setString(key, json.encode(entries));
    await _loadMonthBudget(_focusedDay);
  }

  Future<void> _addMonthExpense(
      String? category, int amount, String day, String comment) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "monthly-expense-${_focusedDay.year}-${_focusedDay.month}";
    final entries = List<Map<String, String>>.from(_monthExpenseEntries);
    entries.add({
      'title': category ?? '支出',
      'amount': '$amount',
      'day': day,
      'comment': comment,
    });
    await prefs.setString(key, json.encode(entries));
    await _loadMonthBudget(_focusedDay);
  }

  // ── 月固定エントリの編集 ──────────────────────────────────────────
  Future<void> _editMonthEntry(String type, int index, String? category,
      int amount, String day, String comment) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == 'income') {
      final key = "monthly-income-${_focusedDay.year}-${_focusedDay.month}";
      final entries = List<Map<String, String>>.from(_monthIncomeEntries);
      entries[index] = {
        'title': category ?? '収入',
        'amount': '$amount',
        'day': day,
        'comment': comment,
      };
      await prefs.setString(key, json.encode(entries));
    } else {
      final key = "monthly-expense-${_focusedDay.year}-${_focusedDay.month}";
      final entries = List<Map<String, String>>.from(_monthExpenseEntries);
      entries[index] = {
        'title': category ?? '支出',
        'amount': '$amount',
        'day': day,
        'comment': comment,
      };
      await prefs.setString(key, json.encode(entries));
    }
    await _loadMonthBudget(_focusedDay);
  }

  // ── 月固定エントリの削除 ──────────────────────────────────────────
  Future<void> _deleteMonthEntry(String type, int index) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == 'income') {
      final key = "monthly-income-${_focusedDay.year}-${_focusedDay.month}";
      final entries = List<Map<String, String>>.from(_monthIncomeEntries);
      entries.removeAt(index);
      if (entries.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, json.encode(entries));
      }
    } else {
      final key = "monthly-expense-${_focusedDay.year}-${_focusedDay.month}";
      final entries = List<Map<String, String>>.from(_monthExpenseEntries);
      entries.removeAt(index);
      if (entries.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, json.encode(entries));
      }
    }
    await _loadMonthBudget(_focusedDay);
  }

  // ── 日エントリの編集 ──────────────────────────────────────────────
  Future<void> _editDailyEvent(
      Map<String, String> event, String? category, int amount, String comment) async {
    final storageKey = event['storageKey']!;
    final eventIndex = int.parse(event['eventIndex']!);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(storageKey);
    if (jsonStr == null) return;
    final decoded = json.decode(jsonStr) as List;
    decoded[eventIndex] = {
      'title': category ?? decoded[eventIndex]['title'],
      'amount': '$amount',
      'type': event['type'],
      'comment': comment,
    };
    await prefs.setString(storageKey, json.encode(decoded));
    await _loadMonthData(_focusedDay);
  }

  // ── 月入力ダイアログ（ヘッダータップ用）────────────────────────────
  void _showMonthInputDialog() {
    _loadCategories();
    final amountCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    int? inputDay;
    String inputType = 'expense';
    String? selectedCategory =
        _monthlyExpenseCats.isNotEmpty ? _monthlyExpenseCats[0] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final allEntries = [
            ...List.generate(
              _monthIncomeEntries.length,
              (i) => {
                ..._monthIncomeEntries[i],
                'type': 'income',
                'entryIndex': '$i',
              },
            ),
            ...List.generate(
              _monthExpenseEntries.length,
              (i) => {
                ..._monthExpenseEntries[i],
                'type': 'expense',
                'entryIndex': '$i',
              },
            ),
          ];

          return Dialog(
            child: Container(
              width: 420,
              constraints: const BoxConstraints(maxHeight: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // タイトル
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text(
                      '${_focusedDay.month}月の入力',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // 履歴リスト
                  if (allEntries.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('履歴',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    const Divider(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allEntries.length,
                        itemBuilder: (ctx, i) {
                          final e = allEntries[i];
                          final isIncome = e['type'] == 'income';
                          final color =
                              isIncome ? Colors.green : Colors.red;
                          final idx = int.parse(e['entryIndex']!);
                          return ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isIncome ? '収入' : '支出',
                                style: TextStyle(
                                    color: color, fontSize: 11),
                              ),
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
                                  '¥${_formatAmount(int.tryParse(e['amount'] ?? '0') ?? 0)}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  onPressed: () async {
                                    await _showEditMonthEntryDialog(
                                        e['type']!, idx, e);
                                    setDialogState(() {});
                                  },
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
                                    setDialogState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const Divider(height: 8),

                  // 入力フォーム
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                          onSelectionChanged: (s) =>
                              setDialogState(() {
                            inputType = s.first;
                            final list = inputType == 'income'
                                ? _monthlyIncomeCats
                                : _monthlyExpenseCats;
                            selectedCategory =
                                list.isNotEmpty ? list[0] : null;
                          }),
                        ),
                        const SizedBox(height: 4),
                        DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          items: (inputType == 'income'
                                  ? _monthlyIncomeCats
                                  : _monthlyExpenseCats)
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedCategory = v),
                        ),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: '金額', suffixText: '円'),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int?>(
                                initialValue: inputDay,
                                decoration: const InputDecoration(
                                    labelText: '日付（任意）'),
                                items: [
                                  const DropdownMenuItem(
                                      value: null, child: Text('指定なし')),
                                  ...List.generate(
                                    DateUtils.getDaysInMonth(
                                        _focusedDay.year,
                                        _focusedDay.month),
                                    (i) => DropdownMenuItem(
                                        value: i + 1,
                                        child: Text('${i + 1}日')),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setDialogState(() => inputDay = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: commentCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'コメント（任意）'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ボタン
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('閉じる'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (amountCtrl.text.isEmpty) return;
                            if (inputType == 'income') {
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
                            amountCtrl.clear();
                            commentCtrl.clear();
                            setDialogState(() => inputDay = null);
                          },
                          child: const Text('追加'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 月固定エントリ編集ダイアログ ─────────────────────────────────
  Future<void> _showEditMonthEntryDialog(
      String type, int index, Map<String, String> entry) async {
    final categories =
        type == 'income' ? _monthlyIncomeCats : _monthlyExpenseCats;
    final amountCtrl = TextEditingController(text: entry['amount']);
    final commentCtrl =
        TextEditingController(text: entry['comment'] ?? '');
    int? editDay = int.tryParse(entry['day'] ?? '');
    String? selectedCategory = categories.contains(entry['title'])
        ? entry['title']
        : (categories.isNotEmpty ? categories[0] : null);
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setEditState) => AlertDialog(
          title: const Text('編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setEditState(() => selectedCategory = v),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: '金額', suffixText: '円'),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int?>(
                      initialValue: editDay,
                      decoration: const InputDecoration(
                          labelText: '日付（任意）'),
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
                      onChanged: (v) =>
                          setEditState(() => editDay = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: commentCtrl,
                      decoration: const InputDecoration(
                          labelText: 'コメント（任意）'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                if (amountCtrl.text.isEmpty) return;
                await _editMonthEntry(
                  type,
                  index,
                  selectedCategory,
                  int.tryParse(amountCtrl.text) ?? 0,
                  editDay?.toString() ?? '',
                  commentCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 日エントリ編集ダイアログ ─────────────────────────────────────
  Future<void> _showEditDailyEventDialog(Map<String, String> event) async {
    final isIncome = event['type'] == 'income';
    final categories =
        isIncome ? _incomeCategories : _expenseCategories;
    final amountCtrl = TextEditingController(text: event['amount']);
    final commentCtrl =
        TextEditingController(text: event['comment'] ?? '');
    String? selectedCategory = categories.contains(event['title'])
        ? event['title']
        : (categories.isNotEmpty ? categories[0] : null);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setEditState) => AlertDialog(
          title: const Text('編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setEditState(() => selectedCategory = v),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: '金額', suffixText: '円'),
              ),
              TextField(
                controller: commentCtrl,
                decoration:
                    const InputDecoration(labelText: 'コメント（任意）'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                if (amountCtrl.text.isEmpty) return;
                await _editDailyEvent(
                  event,
                  selectedCategory,
                  int.tryParse(amountCtrl.text) ?? 0,
                  commentCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  // ── カテゴリロード ────────────────────────────────────────────────
  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthStartDay = prefs.getInt('month_start_day') ?? 1;
      _firstDayOfWeek = prefs.getInt('first_day_of_week') ?? 0;
      _expenseCategories =
          prefs.getStringList('categories') ?? ['食費', '日用品', '交通費'];
      _incomeCategories =
          prefs.getStringList('income_categories') ?? ['給与', '副収入', 'その他'];
      _monthlyExpenseCats =
          prefs.getStringList('monthly_expense_categories') ?? ['家賃', '光熱費', '通信費'];
      _monthlyIncomeCats =
          prefs.getStringList('monthly_income_categories') ?? ['給与', '副収入'];
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
    final prefs = await SharedPreferences.getInstance();
    _monthStartDay = prefs.getInt('month_start_day') ?? 1;
    final (rangeStart, rangeEnd) = _getMonthRange(date);
    final monthEvents = <Map<String, String>>[];

    for (final key in prefs.getKeys()) {
      if (!key.contains('-')) continue;
      final parts = key.split('-');
      if (parts.length != 3) continue;

      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;

      final keyDate = DateTime(year, month, day);
      if (keyDate.isBefore(rangeStart) || keyDate.isAfter(rangeEnd)) continue;

      final jsonString = prefs.getString(key);
      if (jsonString == null) continue;

      final decoded = json.decode(jsonString);
      if (decoded is! List) continue;

      for (var i = 0; i < decoded.length; i++) {
        final event = Map<String, String>.from(decoded[i] as Map);
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
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(storageKey);
    if (jsonString == null) return;
    final decoded = json.decode(jsonString) as List;
    decoded.removeAt(eventIndex);
    if (decoded.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, json.encode(decoded));
    }
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
  void _showInputSheet(DateTime date) {
    _loadCategories();
    String inputType = 'expense';
    String? selectedCategory =
        _expenseCategories.isNotEmpty ? _expenseCategories[0] : null;
    DateTime selectedDate = DateTime(date.year, date.month, date.day);
    final amountCtrl = TextEditingController();
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final dateKey =
              '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
          final dayEvents = _monthlyEvents
              .where((e) => e['storageKey'] == dateKey)
              .toList();

          return Dialog(
            child: Container(
              width: 420,
              constraints: const BoxConstraints(maxHeight: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 日付セレクター
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DateTime>(
                        value: selectedDate,
                        isExpanded: true,
                        items: List.generate(
                          DateUtils.getDaysInMonth(
                              selectedDate.year, selectedDate.month),
                          (i) {
                            final d = DateTime(selectedDate.year,
                                selectedDate.month, i + 1);
                            const wds = [
                              '月', '火', '水', '木', '金', '土', '日'
                            ];
                            return DropdownMenuItem(
                              value: d,
                              child: Text(
                                  '${d.month}月${d.day}日（${wds[d.weekday - 1]}）'),
                            );
                          },
                        ),
                        onChanged: (d) {
                          if (d != null) {
                            setSheetState(() => selectedDate = d);
                          }
                        },
                      ),
                    ),
                  ),

                  // 履歴リスト
                  if (dayEvents.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text('履歴',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                    const Divider(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: dayEvents.length,
                        itemBuilder: (ctx, i) {
                          final e = dayEvents[i];
                          final isIncome = e['type'] == 'income';
                          final color =
                              isIncome ? Colors.green : Colors.red;
                          return ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isIncome ? '収入' : '支出',
                                style: TextStyle(
                                    color: color, fontSize: 11),
                              ),
                            ),
                            title: Text(e['title'] ?? '',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: e['comment']?.isNotEmpty == true
                                ? Text(e['comment']!,
                                    style:
                                        const TextStyle(fontSize: 11))
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
                                  icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  onPressed: () async {
                                    await _showEditDailyEventDialog(e);
                                    setSheetState(() {});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
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
                        },
                      ),
                    ),
                  ],

                  const Divider(height: 8),

                  // 入力フォーム
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                          onSelectionChanged: (s) =>
                              setSheetState(() {
                            inputType = s.first;
                            final list = inputType == 'income'
                                ? _incomeCategories
                                : _expenseCategories;
                            selectedCategory =
                                list.isNotEmpty ? list[0] : null;
                          }),
                        ),
                        const SizedBox(height: 4),
                        DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          items: (inputType == 'income'
                                  ? _incomeCategories
                                  : _expenseCategories)
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => selectedCategory = v),
                        ),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: '金額', suffixText: '円'),
                        ),
                        TextField(
                          controller: commentCtrl,
                          decoration: const InputDecoration(
                              labelText: 'コメント（任意）'),
                        ),
                      ],
                    ),
                  ),

                  // ボタン
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('閉じる'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (selectedCategory == null ||
                                amountCtrl.text.isEmpty) {
                              return;
                            }

                            final prefs =
                                await SharedPreferences.getInstance();
                            final key =
                                '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
                            final jsonStr = prefs.getString(key);
                            final events = jsonStr != null
                                ? List<Map<String, String>>.from(
                                    json.decode(jsonStr).map(
                                        (i) => Map<String, String>.from(i)))
                                : <Map<String, String>>[];
                            events.add({
                              'title': selectedCategory!,
                              'amount': amountCtrl.text,
                              'type': inputType,
                              'comment': commentCtrl.text,
                            });
                            await prefs.setString(key, json.encode(events));
                            await _loadMonthData(selectedDate);

                            if (!mounted) return;
                            setState(() {
                              _selectedDay = selectedDate;
                              _focusedDay = selectedDate;
                            });

                            amountCtrl.clear();
                            commentCtrl.clear();
                            setSheetState(() {});
                          },
                          child: const Text('追加する'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日付：上段
              Container(
                width: 22,
                height: 22,
                decoration: circleDecoration,
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(fontSize: 12, color: dayTextColor),
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
                            color: Colors.green, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        expense > 0 ? _formatAmount(expense) : '',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 11),
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
    final totalIncome = monthIncomeSum + incomeSum;
    final totalExpense = monthExpenseSum + expenseSum;
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

    // 月固定エントリを先頭に追加した表示用リスト
    final incomeDisplayEvents = [
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
      appBar: AppBar(
        title: const Text('カレンダー'),
      ),
      body: Column(
        children: [
              TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            locale: 'ja_JP',
            rowHeight: 68,
            daysOfWeekHeight: 36,
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
            onHeaderTapped: (_) =>
                widget.onNavigateToAnalysis?.call(_focusedDay),
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
                  onTap: () =>
                      widget.onNavigateToAnalysis?.call(_focusedDay),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.08),
                      border: Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 1.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart,
                            size: 20,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          '${day.year}年${day.month}月',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '収入 ¥${_formatAmount(totalIncome)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '支出 ¥${_formatAmount(totalExpense)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '合計 ¥${_formatAmount(balance)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: balance >= 0
                                    ? Colors.blue
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
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

          // 月の収支登録ボタン
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showMonthInputDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('${_focusedDay.month}月の収支を登録'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
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
