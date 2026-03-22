import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'category_settings_screen.dart';
import 'analysis_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  List<Map<String, String>> _monthlyEvents = [];
  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];

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

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
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
      String? category, int amount, String comment) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "monthly-income-${_focusedDay.year}-${_focusedDay.month}";
    final entries = List<Map<String, String>>.from(_monthIncomeEntries);
    entries.add({
      'title': category ?? '収入',
      'amount': '$amount',
      'comment': comment,
    });
    await prefs.setString(key, json.encode(entries));
    await _loadMonthBudget(_focusedDay);
  }

  Future<void> _addMonthExpense(
      String? category, int amount, String comment) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "monthly-expense-${_focusedDay.year}-${_focusedDay.month}";
    final entries = List<Map<String, String>>.from(_monthExpenseEntries);
    entries.add({
      'title': category ?? '支出',
      'amount': '$amount',
      'comment': comment,
    });
    await prefs.setString(key, json.encode(entries));
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

  // ── 月収入ダイアログ ─────────────────────────────────────────────
  // ── 月入力ダイアログ（ヘッダータップ用）────────────────────────────
  void _showMonthInputDialog() {
    _loadCategories();
    final amountCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    String inputType = 'expense';
    String? selectedCategory =
        _expenseCategories.isNotEmpty ? _expenseCategories[0] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${_focusedDay.month}月の入力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'income', label: Text('収入')),
                  ButtonSegment(value: 'expense', label: Text('支出')),
                ],
                selected: {inputType},
                onSelectionChanged: (s) => setDialogState(() {
                  inputType = s.first;
                  final list = inputType == 'income'
                      ? _incomeCategories
                      : _expenseCategories;
                  selectedCategory = list.isNotEmpty ? list[0] : null;
                }),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: (inputType == 'income'
                        ? _incomeCategories
                        : _expenseCategories)
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedCategory = v),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: '金額', suffixText: '円'),
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
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (amountCtrl.text.isEmpty) return;
                if (inputType == 'income') {
                  await _addMonthIncome(
                    selectedCategory,
                    int.tryParse(amountCtrl.text) ?? 0,
                    commentCtrl.text,
                  );
                } else {
                  await _addMonthExpense(
                    selectedCategory,
                    int.tryParse(amountCtrl.text) ?? 0,
                    commentCtrl.text,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('追加'),
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
      _expenseCategories =
          prefs.getStringList('categories') ?? ['食費', '日用品', '交通費'];
      _incomeCategories =
          prefs.getStringList('income_categories') ?? ['給与', '副収入', 'その他'];
    });
  }

  // ── 月データロード ────────────────────────────────────────────────
  Future<void> _loadMonthData(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final monthEvents = <Map<String, String>>[];

    for (final key in prefs.getKeys()) {
      if (!key.contains('-')) continue;
      final parts = key.split('-');
      if (parts.length != 3) continue;

      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != date.year || month != date.month) continue;

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

  // ── 月固定エントリの削除確認 ─────────────────────────────────────
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          title: DropdownButtonHideUnderline(
            child: DropdownButton<DateTime>(
              value: selectedDate,
              isExpanded: true,
              items: List.generate(
                DateUtils.getDaysInMonth(
                    selectedDate.year, selectedDate.month),
                (i) {
                  final d = DateTime(
                      selectedDate.year, selectedDate.month, i + 1);
                  const wds = ['月', '火', '水', '木', '金', '土', '日'];
                  return DropdownMenuItem(
                    value: d,
                    child: Text(
                        '${d.month}月${d.day}日（${wds[d.weekday - 1]}）'),
                  );
                },
              ),
              onChanged: (d) {
                if (d != null) setSheetState(() => selectedDate = d);
              },
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'income', label: Text('収入')),
                  ButtonSegment(value: 'expense', label: Text('支出')),
                ],
                selected: {inputType},
                onSelectionChanged: (s) => setSheetState(() {
                  inputType = s.first;
                  final list = inputType == 'income'
                      ? _incomeCategories
                      : _expenseCategories;
                  selectedCategory = list.isNotEmpty ? list[0] : null;
                }),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: (inputType == 'income'
                        ? _incomeCategories
                        : _expenseCategories)
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedCategory = v),
              ),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: '金額', suffixText: '円'),
              ),
              TextField(
                controller: _commentController,
                decoration:
                    const InputDecoration(labelText: 'コメント（任意）'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _amountController.clear();
                _commentController.clear();
                Navigator.pop(ctx);
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedCategory == null ||
                    _amountController.text.isEmpty) {
                  return;
                }

                // selectedDate のストレージに直接追記
                final prefs = await SharedPreferences.getInstance();
                final key =
                    '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
                final jsonStr = prefs.getString(key);
                final events = jsonStr != null
                    ? List<Map<String, String>>.from(json
                        .decode(jsonStr)
                        .map((i) => Map<String, String>.from(i)))
                    : <Map<String, String>>[];
                events.add({
                  'title': selectedCategory!,
                  'amount': _amountController.text,
                  'type': inputType,
                  'comment': _commentController.text,
                });
                await prefs.setString(key, json.encode(events));

                await _loadMonthData(selectedDate);

                if (!mounted) return;
                setState(() {
                  _selectedDay = selectedDate;
                  _focusedDay = selectedDate;
                });

                _amountController.clear();
                _commentController.clear();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('追加する'),
            ),
          ],
        ),
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
              // 金額：下段、右寄せ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (income > 0)
                      Text(
                        _formatAmount(income),
                        style: const TextStyle(
                            color: Colors.green, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (expense > 0)
                      Text(
                        _formatAmount(expense),
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '分析',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const AnalysisScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => const CategorySettingsScreen(),
                ),
              );
              _loadCategories();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // カレンダー
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            locale: 'ja_JP',
            rowHeight: 68,
            daysOfWeekHeight: 28,
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
            onHeaderTapped: (_) => _showMonthInputDialog(),
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              _loadMonthData(focusedDay);
              _loadMonthBudget(focusedDay);
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) => _buildDayCell(
                day, null, Colors.black87, dailyTotals),
              outsideBuilder: (context, day, focusedDay) => _buildDayCell(
                day, null, Colors.grey.shade400, const {}),
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
              headerTitleBuilder: (context, day) => Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                onTap: _showMonthInputDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                    border: Border.all(
                        color: Theme.of(context).primaryColor, width: 1.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_calendar,
                          size: 16,
                          color: Theme.of(context).primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '${day.year}年${day.month}月',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

          // サマリーカード
          Card(
            margin: const EdgeInsets.all(10),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem("収入計", "¥$totalIncome", Colors.green),
                  _buildSummaryItem("支出計", "¥$totalExpense", Colors.red),
                  _buildSummaryItem("合計", "¥$balance", Colors.blue),
                ],
              ),
            ),
          ),

          // 詳細ヘッダー
          _SectionHeader(
            label: '詳細',
            total: '',
            totalColor: Colors.black,
          ),

          // 詳細リスト（ここだけスクロール）
          Expanded(
            child: ListView(
              children: [
                // 今月の収入
                _SubSectionHeader(
                    label: '今月の収入',
                    total: '¥$totalIncome',
                    color: Colors.green),
                if (incomeDisplayEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: Text('データなし')),
                  )
                else
                  ...incomeDisplayEvents
                      .map((e) => _buildEventTile(e, Colors.green)),

                // 今月の支出
                _SubSectionHeader(
                    label: '今月の支出',
                    total: '¥$totalExpense',
                    color: Colors.red),
                if (expenseDisplayEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: Text('データなし')),
                  )
                else
                  ...expenseDisplayEvents
                      .map((e) => _buildEventTile(e, Colors.red)),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, String> e, Color amountColor) {
    final comment = e['comment'];
    return ListTile(
      title: Text('${e['date']} ${e['title']}'),
      subtitle: (comment != null && comment.isNotEmpty)
          ? Text(comment, style: const TextStyle(fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '¥${e['amount']}',
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

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String total;
  final Color totalColor;

  const _SectionHeader({
    required this.label,
    required this.total,
    required this.totalColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(
            total,
            style: TextStyle(fontWeight: FontWeight.bold, color: totalColor),
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
