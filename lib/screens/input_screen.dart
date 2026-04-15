import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  // 入力モード: 'daily' | 'monthly' | 'subscription'
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

  // サブスクリプション
  List<Map<String, String>> _subscriptions = [];

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
    await _loadSubscriptions();
  }

  Future<void> _loadCategories() async {
    final data = await FirestoreService.getSettings();
    setState(() {
      _expenseCategories = List<String>.from(
          data['categories'] ?? ['食費', '日用品', '交通費']);
      _incomeCategories = List<String>.from(
          data['income_categories'] ?? ['給与', '副収入', 'その他']);
      _monthlyExpenseCats = List<String>.from(
          data['monthly_expense_categories'] ?? ['家賃', '光熱費', '通信費']);
      _monthlyIncomeCats = List<String>.from(
          data['monthly_income_categories'] ?? ['給与', '副収入']);

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
    final entries = await FirestoreService.getDailyEntries(_selectedDate);
    setState(() => _dailyEntries = entries);
  }

  Future<void> _loadMonthlyEntries() async {
    final incomeEntries =
        await FirestoreService.getMonthlyEntries('income', _selectedMonth);
    final expenseEntries =
        await FirestoreService.getMonthlyEntries('expense', _selectedMonth);
    setState(() {
      _monthlyEntries = [
        ...incomeEntries.map((e) => {...e, 'entryType': 'income'}),
        ...expenseEntries.map((e) => {...e, 'entryType': 'expense'}),
      ];
    });
  }

  Future<void> _loadSubscriptions() async {
    final subs = await FirestoreService.getSubscriptions();
    setState(() => _subscriptions = subs);
  }

  // ── 日ごと追加 ──────────────────────────────────────────────────────
  Future<void> _addDailyEntry() async {
    final amount = int.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || _dailyCategory == null) return;

    final entries = await FirestoreService.getDailyEntries(_selectedDate);
    entries.add({
      'title': _dailyCategory!,
      'amount': '$amount',
      'type': _inputType,
      'comment': _commentCtrl.text,
    });
    await FirestoreService.setDailyEntries(_selectedDate, entries);

    _amountCtrl.clear();
    _commentCtrl.clear();
    await _loadDailyEntries();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました'), duration: Duration(seconds: 2)),
    );
  }

  // ── 月ごと追加 ──────────────────────────────────────────────────────
  Future<void> _addMonthlyEntry() async {
    final amount = int.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || _monthlyCategory == null) return;

    final entries =
        await FirestoreService.getMonthlyEntries(_inputType, _selectedMonth);
    entries.add({
      'title': _monthlyCategory!,
      'amount': '$amount',
      'day': _monthlyDay?.toString() ?? '',
      'comment': _commentCtrl.text,
    });
    await FirestoreService.setMonthlyEntries(_inputType, _selectedMonth, entries);

    _amountCtrl.clear();
    _commentCtrl.clear();
    setState(() => _monthlyDay = null);
    await _loadMonthlyEntries();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました'), duration: Duration(seconds: 2)),
    );
  }

  // ── 日ごとエントリ削除 ──────────────────────────────────────────────
  Future<void> _deleteDailyEntry(int index) async {
    final entries = await FirestoreService.getDailyEntries(_selectedDate);
    entries.removeAt(index);
    await FirestoreService.setDailyEntries(_selectedDate, entries);
    await _loadDailyEntries();
  }

  // ── 月ごとエントリ削除 ──────────────────────────────────────────────
  Future<void> _deleteMonthlyEntry(String entryType, int index) async {
    final entries =
        await FirestoreService.getMonthlyEntries(entryType, _selectedMonth);
    entries.removeAt(index);
    await FirestoreService.setMonthlyEntries(entryType, _selectedMonth, entries);
    await _loadMonthlyEntries();
  }

  // ── 日ごとエントリ編集ダイアログ（カレンダー画面と同仕様）──────────
  Future<void> _editDailyEntryDialog(int index, Map<String, String> e) async {
    String editType = e['type'] ?? 'expense';
    List<String> cats() =>
        editType == 'income' ? _incomeCategories : _expenseCategories;
    String? selectedCat = cats().contains(e['title'])
        ? e['title']
        : (cats().isNotEmpty ? cats()[0] : null);
    DateTime selectedDate = _selectedDate;
    final amountCtrl = TextEditingController(text: e['amount']);
    final commentCtrl = TextEditingController(text: e['comment'] ?? '');

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
                        selected: {editType},
                        onSelectionChanged: (s) => setDs(() {
                          editType = s.first;
                          selectedCat = cats().isNotEmpty ? cats()[0] : null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: '金額',
                            hintText: '例：1000',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            suffixText: '円',
                            border: OutlineInputBorder(),
                            isDense: true),
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
                      TextField(
                        controller: commentCtrl,
                        decoration: const InputDecoration(
                            labelText: 'メモ（任意）',
                            hintText: 'メモを入力',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
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
                          if (amountCtrl.text.isEmpty) return;
                          final origEntries = await FirestoreService
                              .getDailyEntries(_selectedDate);
                          if (index < origEntries.length) {
                            origEntries.removeAt(index);
                          }
                          await FirestoreService.setDailyEntries(
                              _selectedDate, origEntries);
                          final newEntries = await FirestoreService
                              .getDailyEntries(selectedDate);
                          newEntries.add({
                            'title': selectedCat ?? '',
                            'amount': amountCtrl.text,
                            'type': editType,
                            'comment': commentCtrl.text,
                          });
                          await FirestoreService.setDailyEntries(
                              selectedDate, newEntries);
                          await _loadDailyEntries();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('保存'),
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

  // ── 月ごとエントリ編集ダイアログ ────────────────────────────────────
  Future<void> _editMonthlyEntryDialog(
      String entryType, int sameTypeIndex, Map<String, String> e) async {
    String editType = entryType;
    List<String> cats() =>
        editType == 'income' ? _monthlyIncomeCats : _monthlyExpenseCats;
    String? selectedCat = cats().contains(e['title'])
        ? e['title']
        : (cats().isNotEmpty ? cats()[0] : null);
    final amountCtrl = TextEditingController(text: e['amount']);
    final commentCtrl = TextEditingController(text: e['comment'] ?? '');
    int? editDay = int.tryParse(e['day'] ?? '');
    final daysInMonth =
        DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('月ごと記録を編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'income', label: Text('収入')),
                  ButtonSegment(value: 'expense', label: Text('支出')),
                ],
                selected: {editType},
                onSelectionChanged: (s) => setDs(() {
                  editType = s.first;
                  selectedCat = cats().isNotEmpty ? cats()[0] : null;
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '金額', suffixText: '円', isDense: true),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCat,
                decoration:
                    const InputDecoration(labelText: 'カテゴリ', isDense: true),
                items: cats()
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDs(() => selectedCat = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: editDay,
                decoration:
                    const InputDecoration(labelText: '日付（任意）', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('指定なし')),
                  ...List.generate(
                    daysInMonth,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('${i + 1}日')),
                  ),
                ],
                onChanged: (v) => setDs(() => editDay = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                    labelText: 'メモ（任意）', isDense: true),
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
                // 元のタイプで取得 → 削除
                final origEntries = await FirestoreService.getMonthlyEntries(
                    entryType, _selectedMonth);
                if (sameTypeIndex < origEntries.length) {
                  origEntries.removeAt(sameTypeIndex);
                }
                await FirestoreService.setMonthlyEntries(
                    entryType, _selectedMonth, origEntries);
                // 新しいタイプで追加
                final newEntries = await FirestoreService.getMonthlyEntries(
                    editType, _selectedMonth);
                newEntries.add({
                  'title': selectedCat ?? '',
                  'amount': amountCtrl.text,
                  'day': editDay?.toString() ?? '',
                  'comment': commentCtrl.text,
                });
                await FirestoreService.setMonthlyEntries(
                    editType, _selectedMonth, newEntries);
                await _loadMonthlyEntries();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    amountCtrl.dispose();
    commentCtrl.dispose();
  }

  // ── サブスク追加・編集ダイアログ ────────────────────────────────────
  Future<void> _showSubscriptionDialog({
    int? editIndex,
    Map<String, String>? existing,
  }) async {
    final isEdit = existing != null;
    String subType = isEdit ? (existing['type'] ?? 'expense') : 'expense';
    List<String> cats() =>
        subType == 'income' ? _monthlyIncomeCats : _monthlyExpenseCats;
    String? selectedCat = isEdit
        ? (cats().contains(existing['title'])
            ? existing['title']
            : (cats().isNotEmpty ? cats()[0] : null))
        : (cats().isNotEmpty ? cats()[0] : null);
    String cycle = isEdit ? (existing['cycle'] ?? 'monthly') : 'monthly';
    final amountCtrl =
        TextEditingController(text: isEdit ? (existing['amount'] ?? '') : '');
    final memoCtrl =
        TextEditingController(text: isEdit ? (existing['memo'] ?? '') : '');
    int? billingDay =
        isEdit ? int.tryParse(existing['billingDay'] ?? '') : null;

    // 開始・終了月
    String startYM = isEdit ? (existing['startYearMonth'] ?? '') : '';
    String endYM = isEdit ? (existing['endYearMonth'] ?? '') : '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    isEdit ? '定期支払いを編集' : '定期支払いを追加',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'income', label: Text('収入')),
                            ButtonSegment(
                                value: 'expense', label: Text('支出')),
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
                            startYM = '';
                            endYM = '';
                          }),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          autofocus: !isEdit,
                          decoration: InputDecoration(
                              labelText: '金額',
                              suffixText: cycle == 'yearly' ? '円/年' : '円/月',
                              border: const OutlineInputBorder(),
                              isDense: true),
                        ),
                        if (cycle == 'yearly')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Builder(builder: (ctx) {
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
                                        child: Text('毎年${i + 1}月')),
                                  ),
                                ]
                              : [
                                  const DropdownMenuItem(
                                      value: null, child: Text('指定なし')),
                                  ...List.generate(
                                    31,
                                    (i) => DropdownMenuItem(
                                        value: i + 1,
                                        child: Text('毎月${i + 1}日')),
                                  ),
                                ],
                          onChanged: (v) => setDs(() => billingDay = v),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: memoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'メモ（任意）',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                        const SizedBox(height: 12),
                        // 開始・終了（月単位：年月 / 年単位：年のみ）
                        Row(
                          children: [
                            Expanded(
                              child: _YearMonthPicker(
                                label: cycle == 'yearly'
                                    ? '開始年（任意）'
                                    : '開始月（任意）',
                                value: startYM,
                                showMonth: cycle != 'yearly',
                                onChanged: (v) => setDs(() => startYM = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _YearMonthPicker(
                                label: cycle == 'yearly'
                                    ? '終了年（任意）'
                                    : '終了月（任意）',
                                value: endYM,
                                showMonth: cycle != 'yearly',
                                onChanged: (v) => setDs(() => endYM = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
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
                          if (amountCtrl.text.isEmpty || selectedCat == null) {
                            return;
                          }
                          final now = DateTime.now();
                          final effectiveStart = startYM.isNotEmpty
                              ? startYM
                              : (cycle == 'yearly'
                                  ? '${now.year}'
                                  : '${now.year}-${now.month}');
                          final newSub = {
                            'type': subType,
                            'cycle': cycle,
                            'title': selectedCat!,
                            'amount': amountCtrl.text,
                            'billingDay': billingDay?.toString() ?? '',
                            'startYearMonth': effectiveStart,
                            'endYearMonth': endYM,
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

  // ── サブスク削除 ────────────────────────────────────────────────────
  Future<void> _deleteSubscription(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認'),
        content: const Text('この定期支払いを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final subs = List<Map<String, String>>.from(_subscriptions);
    subs.removeAt(index);
    await FirestoreService.setSubscriptions(subs);
    await _loadSubscriptions();
  }

  // ── 今月に適用可能なサブスクを月ごとエントリとして追加 ──────────────
  Future<void> _applySubscriptionsToMonth() async {
    final applicable = _subscriptions.where((s) {
      if (!_isSubApplicable(s, _selectedMonth)) return false;
      return true;
    }).toList();
    if (applicable.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('適用できる定期支払いがありません')),
      );
      return;
    }
    for (final s in applicable) {
      final type = s['type'] ?? 'expense';
      final isYearly = s['cycle'] == 'yearly';
      final rawAmount = int.tryParse(s['amount'] ?? '0') ?? 0;
      final amount = isYearly ? (rawAmount / 12).round() : rawAmount;
      final entries =
          await FirestoreService.getMonthlyEntries(type, _selectedMonth);
      entries.add({
        'title': s['title'] ?? '',
        'amount': '$amount',
        'day': s['billingDay'] ?? '',
        'comment': s['memo'] ?? '',
      });
      await FirestoreService.setMonthlyEntries(type, _selectedMonth, entries);
    }
    await _loadMonthlyEntries();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${applicable.length}件の定期支払いを追加しました')),
    );
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

  // ── 日付選択 ─────────────────────────────────────────────────────────
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

  // ── 年月選択 ─────────────────────────────────────────────────────────
  Future<void> _pickMonth() async {
    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
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
                setState(
                    () => _selectedMonth = DateTime(tempYear, tempMonth));
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
      body: SafeArea(
        child: Column(
          children: [
            // モード切り替え（カスタムタブバー）
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _ModeTabBar(
                mode: _mode,
                onChanged: (newMode) async {
                  setState(() {
                    _mode = newMode;
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
                  if (newMode == 'subscription') await _loadSubscriptions();
                },
              ),
            ),

            Expanded(
              child: _mode == 'subscription'
                  ? _buildSubscriptionTab()
                  : SingleChildScrollView(
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
                                          value: 'income', label: Text('収入')),
                                      ButtonSegment(
                                          value: 'expense', label: Text('支出')),
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
                                      hintText: '例：1000',
                                      floatingLabelBehavior: FloatingLabelBehavior.always,
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
                                      hintText: 'メモを入力',
                                      floatingLabelBehavior: FloatingLabelBehavior.always,
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
                                      icon: const Icon(
                                          Icons.calendar_month_outlined),
                                      label: Text(
                                        '${_selectedMonth.year}年${_selectedMonth.month}月',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
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
                                                value: null,
                                                child: Text('指定なし')),
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

                          const SizedBox(height: 8),

                          // 月ごとモード: 定期分を追加ボタン
                          if (_mode == 'monthly' &&
                              _subscriptions.any((s) =>
                                  _isSubApplicable(s, _selectedMonth)))
                            OutlinedButton.icon(
                              onPressed: _applySubscriptionsToMonth,
                              icon: const Icon(Icons.repeat_outlined, size: 18),
                              label: const Text('定期分を今月に追加'),
                            ),

                          const SizedBox(height: 8),

                          // ── 日ごと履歴 ────────────────────────────────────
                          if (_mode == 'daily' &&
                              _dailyEntries.isNotEmpty) ...[
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
                                  onTap: () =>
                                      _editDailyEntryDialog(i, e),
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isIncome ? '収入' : '支出',
                                      style: TextStyle(
                                          color: color, fontSize: 11),
                                    ),
                                  ),
                                  title: Text(e['title'] ?? ''),
                                  subtitle:
                                      e['comment']?.isNotEmpty == true
                                          ? Text(e['comment']!,
                                              style: const TextStyle(
                                                  fontSize: 11))
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
                                          final ok =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('確認'),
                                              content:
                                                  const Text('削除しますか？'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          ctx, false),
                                                  child: const Text(
                                                      'キャンセル'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          ctx, true),
                                                  child:
                                                      const Text('削除'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            _deleteDailyEntry(i);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],

                          // ── 月ごと履歴 ────────────────────────────────────
                          if (_mode == 'monthly' &&
                              _monthlyEntries.isNotEmpty) ...[
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
                                  .where(
                                      (x) => x['entryType'] == e['entryType'])
                                  .toList();
                              final sameTypeIndex = sameTypeList.indexOf(e);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 4),
                                child: ListTile(
                                  dense: true,
                                  onTap: () => _editMonthlyEntryDialog(
                                      e['entryType']!, sameTypeIndex, e),
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isIncome ? '収入' : '支出',
                                      style: TextStyle(
                                          color: color, fontSize: 11),
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
                                            style: const TextStyle(
                                                fontSize: 11))
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
                                          final ok =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('確認'),
                                              content:
                                                  const Text('削除しますか？'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          ctx, false),
                                                  child: const Text(
                                                      'キャンセル'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          ctx, true),
                                                  child:
                                                      const Text('削除'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            _deleteMonthlyEntry(
                                                e['entryType']!,
                                                sameTypeIndex);
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
      ),
    );
  }

  // ── 定期タブ ──────────────────────────────────────────────────────────
  Widget _buildSubscriptionTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Text('定期支払い一覧',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showSubscriptionDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('追加'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _subscriptions.isEmpty
              ? const Center(
                  child: Text('定期支払いが登録されていません',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _subscriptions.length,
                  itemBuilder: (_, i) {
                    final s = _subscriptions[i];
                    final isIncome = s['type'] == 'income';
                    final isYearly = s['cycle'] == 'yearly';
                    final color = isIncome ? Colors.green : Colors.red;
                    final day = s['billingDay'] ?? '';
                    final memo = s['memo'] ?? '';
                    final startYM = s['startYearMonth'] ?? '';
                    final endYM = s['endYearMonth'] ?? '';
                    final amount = int.tryParse(s['amount'] ?? '0') ?? 0;
                    final monthlyAmount = isYearly ? (amount / 12).round() : amount;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        onTap: () => _showSubscriptionDialog(
                            editIndex: i, existing: s),
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
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
                            if (startYM.isNotEmpty || endYM.isNotEmpty)
                              [
                                if (startYM.isNotEmpty) '$startYM〜',
                                if (endYM.isNotEmpty) '〜$endYM',
                              ].join(''),
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
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
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
                              icon: const Icon(Icons.delete_outline, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: () => _deleteSubscription(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── 年月ピッカー小ウィジェット ───────────────────────────────────────────
class _YearMonthPicker extends StatefulWidget {
  final String label;
  final String value; // 'YYYY-M' or 'YYYY' (year-only) or ''
  final void Function(String) onChanged;
  final bool showMonth; // false のとき年のみ表示（年単位サブスク用）

  const _YearMonthPicker({
    required this.label,
    required this.value,
    required this.onChanged,
    this.showMonth = true,
  });

  @override
  State<_YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<_YearMonthPicker> {
  int? _year;
  int? _month;

  @override
  void initState() {
    super.initState();
    _parse(widget.value);
  }

  @override
  void didUpdateWidget(_YearMonthPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _parse(widget.value);
  }

  void _parse(String v) {
    if (v.isEmpty) {
      _year = null;
      _month = null;
    } else {
      final parts = v.split('-');
      _year = int.tryParse(parts[0]);
      _month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    }
  }

  void _notify() {
    if (!widget.showMonth) {
      // 年のみモード
      widget.onChanged(_year != null ? '$_year' : '');
    } else {
      if (_year != null && _month != null) {
        widget.onChanged('$_year-$_month');
      } else {
        widget.onChanged('');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isSet = _year != null || _month != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(widget.label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (isSet) ...[
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() { _year = null; _month = null; });
                  widget.onChanged('');
                },
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
                    value: _year,
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('---')),
                      ...List.generate(11, (i) {
                        final y = now.year - 1 + i;
                        return DropdownMenuItem(value: y, child: Text('$y年'));
                      }),
                    ],
                    onChanged: (v) {
                      setState(() => _year = v);
                      _notify();
                    },
                  ),
                ),
              ),
            ),
            if (widget.showMonth) ...[
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
                      value: _month,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('---')),
                        ...List.generate(
                            12,
                            (i) => DropdownMenuItem(
                                value: i + 1, child: Text('${i + 1}月'))),
                      ],
                      onChanged: (v) {
                        setState(() => _month = v);
                        _notify();
                      },
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

// ── モード切り替えタブバー ─────────────────────────────────────────────────
class _ModeTabBar extends StatelessWidget {
  final String mode;
  final Future<void> Function(String) onChanged;

  const _ModeTabBar({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final tabs = [
      (value: 'daily',        icon: Icons.today_outlined,           label: '日'),
      (value: 'monthly',      icon: Icons.calendar_month_outlined,  label: '月'),
      (value: 'subscription', icon: Icons.repeat_outlined,          label: '定期'),
    ];

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.map((tab) {
          final selected = mode == tab.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 15,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tab.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
