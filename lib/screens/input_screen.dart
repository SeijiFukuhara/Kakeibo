import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  // 入力モード: 'daily' or 'monthly'
  String _mode = 'daily';

  // カテゴリ
  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];
  List<String> _monthlyExpenseCats = [];
  List<String> _monthlyIncomeCats = [];

  // 共通入力値
  String _inputType = 'expense';
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  // 日ごと入力
  DateTime _selectedDate = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String? _dailyCategory;

  // 月ごと入力
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _monthlyDay;
  String? _monthlyCategory;

  // 履歴
  List<Map<String, String>> _dailyEntries = [];
  List<Map<String, String>> _monthlyEntries = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadCategories();
    await _loadDailyEntries();
    await _loadMonthlyEntries();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _expenseCategories =
          prefs.getStringList('categories') ?? ['食費', '日用品', '交通費'];
      _incomeCategories =
          prefs.getStringList('income_categories') ?? ['給与', '副収入', 'その他'];
      _monthlyExpenseCats =
          prefs.getStringList('monthly_expense_categories') ?? ['家賃', '光熱費', '通信費'];
      _monthlyIncomeCats =
          prefs.getStringList('monthly_income_categories') ?? ['給与', '副収入'];

      // カテゴリ変更後に選択値をリセット
      _dailyCategory = _currentDailyCats.isNotEmpty ? _currentDailyCats[0] : null;
      _monthlyCategory =
          _currentMonthlyCats.isNotEmpty ? _currentMonthlyCats[0] : null;
    });
  }

  List<String> get _currentDailyCats =>
      _inputType == 'income' ? _incomeCategories : _expenseCategories;

  List<String> get _currentMonthlyCats =>
      _inputType == 'income' ? _monthlyIncomeCats : _monthlyExpenseCats;

  Future<void> _loadDailyEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    final jsonStr = prefs.getString(key);
    setState(() {
      _dailyEntries = jsonStr != null
          ? List<Map<String, String>>.from(
              json.decode(jsonStr).map((i) => Map<String, String>.from(i)))
          : [];
    });
  }

  Future<void> _loadMonthlyEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final incomeKey =
        'monthly-income-${_selectedMonth.year}-${_selectedMonth.month}';
    final expenseKey =
        'monthly-expense-${_selectedMonth.year}-${_selectedMonth.month}';
    final incomeJson = prefs.getString(incomeKey);
    final expenseJson = prefs.getString(expenseKey);

    final incomeEntries = incomeJson != null
        ? List<Map<String, String>>.from(
            json.decode(incomeJson).map((i) => Map<String, String>.from(i)))
        : <Map<String, String>>[];
    final expenseEntries = expenseJson != null
        ? List<Map<String, String>>.from(
            json.decode(expenseJson).map((i) => Map<String, String>.from(i)))
        : <Map<String, String>>[];

    setState(() {
      _monthlyEntries = [
        ...incomeEntries.map((e) => {...e, 'entryType': 'income'}),
        ...expenseEntries.map((e) => {...e, 'entryType': 'expense'}),
      ];
    });
  }

  // ── 日ごと追加 ──────────────────────────────────────────────────────
  Future<void> _addDailyEntry() async {
    final amount = int.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || _dailyCategory == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key =
        '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    final jsonStr = prefs.getString(key);
    final entries = jsonStr != null
        ? List<Map<String, String>>.from(
            json.decode(jsonStr).map((i) => Map<String, String>.from(i)))
        : <Map<String, String>>[];
    entries.add({
      'title': _dailyCategory!,
      'amount': '$amount',
      'type': _inputType,
      'comment': _commentCtrl.text,
    });
    await prefs.setString(key, json.encode(entries));

    _amountCtrl.clear();
    _commentCtrl.clear();
    await _loadDailyEntries();
  }

  // ── 月ごと追加 ──────────────────────────────────────────────────────
  Future<void> _addMonthlyEntry() async {
    final amount = int.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || _monthlyCategory == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _inputType == 'income'
        ? 'monthly-income-${_selectedMonth.year}-${_selectedMonth.month}'
        : 'monthly-expense-${_selectedMonth.year}-${_selectedMonth.month}';
    final jsonStr = prefs.getString(key);
    final entries = jsonStr != null
        ? List<Map<String, String>>.from(
            json.decode(jsonStr).map((i) => Map<String, String>.from(i)))
        : <Map<String, String>>[];
    entries.add({
      'title': _monthlyCategory!,
      'amount': '$amount',
      'day': _monthlyDay?.toString() ?? '',
      'comment': _commentCtrl.text,
    });
    await prefs.setString(key, json.encode(entries));

    _amountCtrl.clear();
    _commentCtrl.clear();
    setState(() => _monthlyDay = null);
    await _loadMonthlyEntries();
  }

  // ── 日ごとエントリ削除 ──────────────────────────────────────────────
  Future<void> _deleteDailyEntry(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return;
    final entries = List<Map<String, String>>.from(
        json.decode(jsonStr).map((i) => Map<String, String>.from(i)));
    entries.removeAt(index);
    if (entries.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, json.encode(entries));
    }
    await _loadDailyEntries();
  }

  // ── 月ごとエントリ削除 ──────────────────────────────────────────────
  // [index] は同じentryType内でのインデックス（=prefs配列のインデックス）
  Future<void> _deleteMonthlyEntry(String entryType, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final key = entryType == 'income'
        ? 'monthly-income-${_selectedMonth.year}-${_selectedMonth.month}'
        : 'monthly-expense-${_selectedMonth.year}-${_selectedMonth.month}';
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return;
    final entries = List<Map<String, String>>.from(
        json.decode(jsonStr).map((i) => Map<String, String>.from(i)));
    entries.removeAt(index);
    if (entries.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, json.encode(entries));
    }
    await _loadMonthlyEntries();
  }

  String _formatAmount(int amount) => NumberFormat('#,###').format(amount);

  void _onTypeChanged(String newType) {
    setState(() {
      _inputType = newType;
      _dailyCategory =
          _currentDailyCats.isNotEmpty ? _currentDailyCats[0] : null;
      _monthlyCategory =
          _currentMonthlyCats.isNotEmpty ? _currentMonthlyCats[0] : null;
    });
  }

  // ── 日付選択ダイアログ ────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ja', 'JP'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadDailyEntries();
    }
  }

  // ── 年月選択ダイアログ ────────────────────────────────────────────
  Future<void> _pickMonth() async {
    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('年月を選択'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: tempYear,
                items: List.generate(
                  10,
                  (i) => DropdownMenuItem(
                    value: DateTime.now().year - 4 + i,
                    child: Text('${DateTime.now().year - 4 + i}年'),
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
              onPressed: () async {
                setState(() =>
                    _selectedMonth = DateTime(tempYear, tempMonth));
                Navigator.pop(ctx);
                await _loadMonthlyEntries();
              },
              child: const Text('決定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('入力')),
      body: Column(
        children: [
          // モード切り替え
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'daily',
                  icon: Icon(Icons.today_outlined),
                  label: Text('日ごと'),
                ),
                ButtonSegment(
                  value: 'monthly',
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('月ごと'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) async {
                setState(() {
                  _mode = s.first;
                  _amountCtrl.clear();
                  _commentCtrl.clear();
                  _monthlyDay = null;
                  _inputType = 'expense';
                  _dailyCategory = _currentDailyCats.isNotEmpty
                      ? _currentDailyCats[0]
                      : null;
                  _monthlyCategory = _currentMonthlyCats.isNotEmpty
                      ? _currentMonthlyCats[0]
                      : null;
                });
              },
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // ── 入力フォームカード ──────────────────────────────
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 収入/支出切り替え
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'expense', label: Text('支出')),
                              ButtonSegment(
                                  value: 'income', label: Text('収入')),
                            ],
                            selected: {_inputType},
                            onSelectionChanged: (s) =>
                                _onTypeChanged(s.first),
                          ),

                          const SizedBox(height: 12),

                          // 金額
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '金額',
                              suffixText: '円',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // カテゴリ
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'カテゴリ',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _mode == 'daily'
                                    ? _dailyCategory
                                    : _monthlyCategory,
                                isDense: true,
                                items: (_mode == 'daily'
                                        ? _currentDailyCats
                                        : _currentMonthlyCats)
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  if (_mode == 'daily') {
                                    _dailyCategory = v;
                                  } else {
                                    _monthlyCategory = v;
                                  }
                                }),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // メモ
                          TextField(
                            controller: _commentCtrl,
                            decoration: const InputDecoration(
                              labelText: 'メモ（任意）',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 日付/年月セレクター
                          if (_mode == 'daily')
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                DateFormat('yyyy年M月d日（E）', 'ja_JP')
                                    .format(_selectedDate),
                                style: const TextStyle(fontSize: 15),
                              ),
                            )
                          else ...[
                            OutlinedButton.icon(
                              onPressed: _pickMonth,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(
                                '${_selectedMonth.year}年${_selectedMonth.month}月',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 月ごとのみ: 日付（任意）
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '日付（任意）',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  value: _monthlyDay,
                                  isDense: true,
                                  items: [
                                    const DropdownMenuItem(
                                        value: null, child: Text('指定なし')),
                                    ...List.generate(
                                      DateUtils.getDaysInMonth(
                                          _selectedMonth.year,
                                          _selectedMonth.month),
                                      (i) => DropdownMenuItem(
                                          value: i + 1,
                                          child: Text('${i + 1}日')),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _monthlyDay = v),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // 追加ボタン
                          FilledButton.icon(
                            onPressed: _mode == 'daily'
                                ? _addDailyEntry
                                : _addMonthlyEntry,
                            icon: const Icon(Icons.add),
                            label: const Text('追加する'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 履歴 ────────────────────────────────────────────
                  if (_mode == 'daily' && _dailyEntries.isNotEmpty) ...[
                    Text(
                      '${_selectedDate.month}月${_selectedDate.day}日の記録',
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.outline),
                    ),
                    const SizedBox(height: 4),
                    ..._dailyEntries.asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      final isIncome = e['type'] == 'income';
                      final color =
                          isIncome ? Colors.green : Colors.red;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
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
                              style:
                                  TextStyle(color: color, fontSize: 11),
                            ),
                          ),
                          title: Text(e['title'] ?? ''),
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
                                icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('確認'),
                                      content: const Text('削除しますか？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('削除'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) _deleteDailyEntry(i);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  if (_mode == 'monthly' && _monthlyEntries.isNotEmpty) ...[
                    Text(
                      '${_selectedMonth.year}年${_selectedMonth.month}月の記録',
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.outline),
                    ),
                    const SizedBox(height: 4),
                    ..._monthlyEntries.asMap().entries.map((mapEntry) {
                      final e = mapEntry.value;
                      final isIncome = e['entryType'] == 'income';
                      final color =
                          isIncome ? Colors.green : Colors.red;
                      final sameTypeList = _monthlyEntries
                          .where((x) => x['entryType'] == e['entryType'])
                          .toList();
                      final sameTypeIndex = sameTypeList.indexOf(e);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
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
                              style:
                                  TextStyle(color: color, fontSize: 11),
                            ),
                          ),
                          title: Text(e['title'] ?? ''),
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
                                icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('確認'),
                                      content: const Text('削除しますか？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('削除'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    _deleteMonthlyEntry(
                                        e['entryType']!, sameTypeIndex);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
