import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:math';
import '../services/firestore_service.dart';

// カテゴリ色パレット
const _palette = [
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFF00BCD4),
  Color(0xFFE91E63),
  Color(0xFFFF5722),
  Color(0xFF607D8B),
  Color(0xFF795548),
  Color(0xFF009688),
];

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => AnalysisScreenState();
}

class AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _monthInnerTabController;

  // 月の開始日
  int _monthStartDay = 1;

  void reload() {
    _loadMonthlyData();
    _loadYearlyData();
  }

  void reloadAndSetMonth(DateTime month) {
    _tabController.animateTo(0);
    setState(() => _month = month);
    _loadMonthlyData();
  }

  // 日付から「論理月」を計算するヘルパー
  (int year, int month) _logicalYearMonth(DateTime date) {
    if (_monthStartDay <= 1 || date.day < _monthStartDay) {
      return (date.year, date.month);
    }
    final next = DateTime(date.year, date.month + 1);
    return (next.year, next.month);
  }

  // 月ごと
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, int> _expenseByCategory = {};
  Map<String, int> _incomeByCategory = {};
  int _totalIncome = 0;
  int _totalExpense = 0;

  // 明細: 日々の収支
  List<Map<String, String>> _dailyIncomeList = [];
  List<Map<String, String>> _dailyExpenseList = [];

  // 明細: 月ごとの収支（月固定費）
  List<Map<String, String>> _fixedIncomeList = [];
  List<Map<String, String>> _fixedExpenseList = [];

  // 明細: サブスク（当月適用分）
  List<Map<String, String>> _monthSubList = [];

  // 年ごと
  int _year = DateTime.now().year;
  List<Map<String, int>> _monthlyData =
      List.generate(12, (_) => {'income': 0, 'expense': 0});
  Map<String, int> _yearlyExpenseByCategory = {};
  Map<String, int> _yearlyIncomeByCategory = {};
  Map<String, List<int>> _yearlyExpenseCategoryMonthly = {};
  Map<String, List<int>> _yearlyIncomeCategoryMonthly = {};
  int _yearlyTotalIncome = 0;
  int _yearlyTotalExpense = 0;

  // カテゴリカードへのスクロール用キー
  final _expenseCatKeys = <String, GlobalKey>{};
  final _incomeCatKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _monthInnerTabController = TabController(length: 2, vsync: this);
    _loadMonthlyData();
    _loadYearlyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _monthInnerTabController.dispose();
    super.dispose();
  }

  // サブスクが指定月に適用可能か判定
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

  Future<void> _loadMonthlyData() async {
    final settings = await FirestoreService.getSettings();
    _monthStartDay = (settings['month_start_day'] as int?) ?? 1;
    final expMap = <String, int>{};
    final incMap = <String, int>{};
    final dailyIncList = <Map<String, String>>[];
    final dailyExpList = <Map<String, String>>[];
    int totalInc = 0;
    int totalExp = 0;

    // ── 日々の収支 ────────────────────────────────
    final allDaily = await FirestoreService.getAllDailyEntries();
    for (final entry in allDaily.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;

      final (lYear, lMonth) = _logicalYearMonth(DateTime(year, month, day));
      if (lYear != _month.year || lMonth != _month.month) continue;

      for (final e in entry.value) {
        final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
        final category = e['title'] ?? '不明';
        if (e['type'] == 'income') {
          incMap[category] = (incMap[category] ?? 0) + amount;
          totalInc += amount;
          dailyIncList.add({
            'title': category,
            'amount': '$amount',
            'type': 'income',
            'comment': e['comment'] ?? '',
            'date': '$month/$day',
          });
        } else {
          expMap[category] = (expMap[category] ?? 0) + amount;
          totalExp += amount;
          dailyExpList.add({
            'title': category,
            'amount': '$amount',
            'type': 'expense',
            'comment': e['comment'] ?? '',
            'date': '$month/$day',
          });
        }
      }
    }

    // ── 月ごとの収支（固定費）────────────────────
    final incomeEntries =
        await FirestoreService.getMonthlyEntries('income', _month);
    final expenseEntries =
        await FirestoreService.getMonthlyEntries('expense', _month);
    final fixedIncList = <Map<String, String>>[];
    final fixedExpList = <Map<String, String>>[];

    for (final e in incomeEntries) {
      final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
      final category = e['title'] ?? '収入';
      incMap[category] = (incMap[category] ?? 0) + amount;
      totalInc += amount;
      final d = e['day'] ?? '';
      fixedIncList.add({
        'title': category,
        'amount': '$amount',
        'type': 'income',
        'comment': e['comment'] ?? '',
        'date': d.isNotEmpty ? '$d日' : '月固定',
      });
    }
    for (final e in expenseEntries) {
      final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
      final category = e['title'] ?? '支出';
      expMap[category] = (expMap[category] ?? 0) + amount;
      totalExp += amount;
      final d = e['day'] ?? '';
      fixedExpList.add({
        'title': category,
        'amount': '$amount',
        'type': 'expense',
        'comment': e['comment'] ?? '',
        'date': d.isNotEmpty ? '$d日' : '月固定',
      });
    }

    // ── サブスク（当月適用分）──────────────────────
    final allSubs = await FirestoreService.getSubscriptions();
    final monthSubList = allSubs
        .where((s) => _isSubApplicable(s, _month))
        .map((s) {
          final isYearly = s['cycle'] == 'yearly';
          final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
          final monthlyAmt = isYearly ? (raw / 12).round() : raw;
          final isIncome = s['type'] == 'income';
          if (isIncome) {
            incMap[s['title'] ?? ''] =
                (incMap[s['title'] ?? ''] ?? 0) + monthlyAmt;
            totalInc += monthlyAmt;
          } else {
            expMap[s['title'] ?? ''] =
                (expMap[s['title'] ?? ''] ?? 0) + monthlyAmt;
            totalExp += monthlyAmt;
          }
          return {
            'title': s['title'] ?? '',
            'amount': '$monthlyAmt',
            'type': s['type'] ?? 'expense',
            'comment': s['memo'] ?? '',
            'date': isYearly ? '年払' : '定期',
            'cycle': s['cycle'] ?? 'monthly',
            'billingDay': s['billingDay'] ?? '',
          };
        })
        .toList();

    if (!mounted) return;
    setState(() {
      _expenseByCategory = expMap;
      _incomeByCategory = incMap;
      _totalIncome = totalInc;
      _totalExpense = totalExp;
      _dailyIncomeList = dailyIncList
        ..sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
      _dailyExpenseList = dailyExpList
        ..sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
      _fixedIncomeList = fixedIncList;
      _fixedExpenseList = fixedExpList;
      _monthSubList = monthSubList;
    });
  }

  Future<void> _loadYearlyData() async {
    final settings = await FirestoreService.getSettings();
    _monthStartDay = (settings['month_start_day'] as int?) ?? 1;
    final monthlyData =
        List.generate(12, (_) => {'income': 0, 'expense': 0});
    final expMap = <String, int>{};
    final incMap = <String, int>{};
    final expCatMonthly = <String, List<int>>{};
    final incCatMonthly = <String, List<int>>{};
    int totalInc = 0;
    int totalExp = 0;

    final allDaily = await FirestoreService.getAllDailyEntries();
    for (final entry in allDaily.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;

      final (lYear, lMonth) = _logicalYearMonth(DateTime(year, month, day));
      if (lYear != _year || lMonth < 1 || lMonth > 12) continue;

      for (final e in entry.value) {
        final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
        final category = e['title'] ?? '不明';
        if (e['type'] == 'income') {
          monthlyData[lMonth - 1]['income'] =
              (monthlyData[lMonth - 1]['income'] ?? 0) + amount;
          incMap[category] = (incMap[category] ?? 0) + amount;
          incCatMonthly.putIfAbsent(category, () => List.filled(12, 0));
          incCatMonthly[category]![lMonth - 1] += amount;
          totalInc += amount;
        } else {
          monthlyData[lMonth - 1]['expense'] =
              (monthlyData[lMonth - 1]['expense'] ?? 0) + amount;
          expMap[category] = (expMap[category] ?? 0) + amount;
          expCatMonthly.putIfAbsent(category, () => List.filled(12, 0));
          expCatMonthly[category]![lMonth - 1] += amount;
          totalExp += amount;
        }
      }
    }

    final allMonthly = await FirestoreService.getAllMonthlyEntries();
    for (final entry in allMonthly.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final type = parts[0];
      final year = int.tryParse(parts[1]);
      final m = int.tryParse(parts[2]);
      if (year == null || m == null || year != _year || m < 1 || m > 12) continue;

      for (final e in entry.value) {
        final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
        if (type == 'income') {
          final category = e['title'] ?? '収入';
          monthlyData[m - 1]['income'] =
              (monthlyData[m - 1]['income'] ?? 0) + amount;
          incMap[category] = (incMap[category] ?? 0) + amount;
          incCatMonthly.putIfAbsent(category, () => List.filled(12, 0));
          incCatMonthly[category]![m - 1] += amount;
          totalInc += amount;
        } else {
          final category = e['title'] ?? '支出';
          monthlyData[m - 1]['expense'] =
              (monthlyData[m - 1]['expense'] ?? 0) + amount;
          expMap[category] = (expMap[category] ?? 0) + amount;
          expCatMonthly.putIfAbsent(category, () => List.filled(12, 0));
          expCatMonthly[category]![m - 1] += amount;
          totalExp += amount;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _monthlyData = monthlyData;
      _yearlyExpenseByCategory = expMap;
      _yearlyIncomeByCategory = incMap;
      _yearlyExpenseCategoryMonthly = expCatMonthly;
      _yearlyIncomeCategoryMonthly = incCatMonthly;
      _yearlyTotalIncome = totalInc;
      _yearlyTotalExpense = totalExp;
      _expenseCatKeys.removeWhere((k, _) => !expCatMonthly.containsKey(k));
      for (final k in expCatMonthly.keys) {
        _expenseCatKeys.putIfAbsent(k, GlobalKey.new);
      }
      _incomeCatKeys.removeWhere((k, _) => !incCatMonthly.containsKey(k));
      for (final k in incCatMonthly.keys) {
        _incomeCatKeys.putIfAbsent(k, GlobalKey.new);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '月ごと'),
            Tab(text: '年ごと'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMonthlyView(),
          _buildYearlyView(),
        ],
      ),
    );
  }

  // ── 月ごとビュー ──────────────────────────────────────────────

  Widget _buildMonthlyView() {
    final balance = _totalIncome - _totalExpense;

    return Column(
      children: [
        // 月セレクター + サマリー
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              _buildMonthSelector(),
              const SizedBox(height: 8),
              _buildSummaryCard(items: [
                ('収入', _totalIncome, Colors.green),
                ('支出', _totalExpense, Colors.red),
                ('合計', balance, balance >= 0 ? Colors.blue : Colors.orange),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
        // グラフ / 明細 サブタブ
        TabBar(
          controller: _monthInnerTabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'グラフ'),
            Tab(text: '明細'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _monthInnerTabController,
            children: [
              _buildChartPage(),
              _buildDetailPage(),
            ],
          ),
        ),
      ],
    );
  }

  // ── グラフページ（円グラフ）────────────────────────────────────
  Widget _buildChartPage() {
    final hasData =
        _expenseByCategory.isNotEmpty || _incomeByCategory.isNotEmpty;

    if (!hasData) {
      return const Center(
        child: Text('この月のデータがありません',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (_expenseByCategory.isNotEmpty) ...[
          _buildPieSection('支出内訳', _expenseByCategory, _totalExpense,
              Colors.red.shade300),
          const SizedBox(height: 16),
        ],
        if (_incomeByCategory.isNotEmpty)
          _buildPieSection('収入内訳', _incomeByCategory, _totalIncome,
              Colors.green.shade300),
      ],
    );
  }

  // ── 明細ページ（3セクション）────────────────────────────────────
  Widget _buildDetailPage() {
    final hasDailyInc = _dailyIncomeList.isNotEmpty;
    final hasDailyExp = _dailyExpenseList.isNotEmpty;
    final hasFixed =
        _fixedIncomeList.isNotEmpty || _fixedExpenseList.isNotEmpty;
    final hasSub = _monthSubList.isNotEmpty;

    if (!hasDailyInc && !hasDailyExp && !hasFixed && !hasSub) {
      return const Center(
        child: Text('この月のデータがありません',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // ── 日々の収支 ──
        if (hasDailyInc || hasDailyExp) ...[
          _buildDetailSection(
            icon: Icons.calendar_today_outlined,
            title: '日々の収支',
            color: Colors.blue,
            incomeList: _dailyIncomeList,
            expenseList: _dailyExpenseList,
          ),
          const SizedBox(height: 12),
        ],

        // ── 月ごとの収支 ──
        if (hasFixed) ...[
          _buildDetailSection(
            icon: Icons.event_repeat_outlined,
            title: '月ごとの収支',
            color: Colors.purple,
            incomeList: _fixedIncomeList,
            expenseList: _fixedExpenseList,
          ),
          const SizedBox(height: 12),
        ],

        // ── サブスク ──
        if (hasSub)
          _buildSubSection(),
      ],
    );
  }

  // 日々 / 月固定 共通セクションカード
  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Map<String, String>> incomeList,
    required List<Map<String, String>> expenseList,
  }) {
    final incTotal = incomeList.fold(
        0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));
    final expTotal = expenseList.fold(
        0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
            const Divider(height: 16),

            // 収入リスト
            if (incomeList.isNotEmpty) ...[
              _subHeader('収入', _formatAmount(incTotal), Colors.green),
              const SizedBox(height: 4),
              ...incomeList.map((e) => _buildEntryRow(e, Colors.green)),
            ],

            // 支出リスト
            if (expenseList.isNotEmpty) ...[
              if (incomeList.isNotEmpty) const SizedBox(height: 10),
              _subHeader('支出', _formatAmount(expTotal), Colors.red),
              const SizedBox(height: 4),
              ...expenseList.map((e) => _buildEntryRow(e, Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  // サブスクセクションカード
  Widget _buildSubSection() {
    final incSubs =
        _monthSubList.where((s) => s['type'] == 'income').toList();
    final expSubs =
        _monthSubList.where((s) => s['type'] != 'income').toList();
    final incTotal =
        incSubs.fold(0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));
    final expTotal =
        expSubs.fold(0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.repeat_outlined, size: 16,
                    color: Colors.orange),
                const SizedBox(width: 6),
                const Text('サブスク・定期払い',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange)),
              ],
            ),
            const Divider(height: 16),

            if (incSubs.isNotEmpty) ...[
              _subHeader('収入（定期）', _formatAmount(incTotal), Colors.green),
              const SizedBox(height: 4),
              ...incSubs.map((s) => _buildSubRow(s, Colors.green)),
            ],
            if (expSubs.isNotEmpty) ...[
              if (incSubs.isNotEmpty) const SizedBox(height: 10),
              _subHeader('支出（定期）', _formatAmount(expTotal), Colors.red),
              const SizedBox(height: 4),
              ...expSubs.map((s) => _buildSubRow(s, Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subHeader(String label, String total, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text('合計 ¥$total',
                style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      );

  Widget _buildEntryRow(Map<String, String> e, Color color) {
    final comment = e['comment'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(e['date'] ?? '',
                style: TextStyle(fontSize: 11, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e['title'] ?? '',
                    style: const TextStyle(fontSize: 13)),
                if (comment.isNotEmpty)
                  Text(comment,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            '¥${_formatAmount(int.tryParse(e['amount'] ?? '0') ?? 0)}',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSubRow(Map<String, String> s, Color color) {
    final isYearly = s['cycle'] == 'yearly';
    final billingDay = s['billingDay'] ?? '';
    final memo = s['comment'] ?? '';

    final subLabel = isYearly
        ? (billingDay.isNotEmpty ? '毎年$billingDay月' : '年払')
        : (billingDay.isNotEmpty ? '毎月$billingDay日' : '定期');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(subLabel,
                style: TextStyle(fontSize: 11, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['title'] ?? '',
                    style: const TextStyle(fontSize: 13)),
                if (memo.isNotEmpty)
                  Text(memo,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${_formatAmount(int.tryParse(s['amount'] ?? '0') ?? 0)}/月',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12, color: color),
              ),
              if (isYearly)
                Text(
                  '(年払)',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(
                  () => _month = DateTime(_month.year, _month.month - 1));
              _loadMonthlyData();
            }),
        Text(
          '${_month.year}年${_month.month}月',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(
                  () => _month = DateTime(_month.year, _month.month + 1));
              _loadMonthlyData();
            }),
      ],
    );
  }

  Widget _buildPieSection(
      String title, Map<String, int> data, int total, Color baseColor) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ratios = entries
        .map((e) => total > 0 ? e.value / total : 0.0)
        .toList();
    final colors =
        List.generate(entries.length, (i) => _palette[i % _palette.length]);

    return _sectionCard(
      title: title,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(
                painter: _PieChartPainter(ratios: ratios, colors: colors),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < entries.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: colors[i],
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(entries[i].key,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '¥${_formatAmount(entries[i].value)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                '${(ratios[i] * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 年ごとビュー ──────────────────────────────────────────────

  Widget _buildYearlyView() {
    final yearlyBalance = _yearlyTotalIncome - _yearlyTotalExpense;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _year--);
                  _loadYearlyData();
                }),
            Text(
              '$_year年',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() => _year++);
                  _loadYearlyData();
                }),
          ],
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(items: [
          ('年間収入', _yearlyTotalIncome, Colors.green),
          ('年間支出', _yearlyTotalExpense, Colors.red),
          ('収支', yearlyBalance,
              yearlyBalance >= 0 ? Colors.blue : Colors.orange),
        ]),
        const SizedBox(height: 16),
        _sectionCard(
          title: '月別推移',
          children: [
            _buildTwoSeriesLegend('収入', Colors.green, '支出', Colors.red),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _LineChartPainter(
                  seriesList: <_SeriesData>[
                    _SeriesData(
                      data: _monthlyData
                          .map((m) => m['income'] ?? 0)
                          .toList(),
                      color: Colors.green,
                    ),
                    _SeriesData(
                      data: _monthlyData
                          .map((m) => m['expense'] ?? 0)
                          .toList(),
                      color: Colors.red,
                    ),
                  ],
                  formatAmount: _formatAmount,
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_yearlyExpenseCategoryMonthly.isNotEmpty) ...[
          _buildCategoryLineSection(
              '支出カテゴリ別（月別）', _yearlyExpenseCategoryMonthly, _expenseCatKeys),
          const SizedBox(height: 16),
        ],
        if (_yearlyIncomeCategoryMonthly.isNotEmpty)
          _buildCategoryLineSection(
              '収入カテゴリ別（月別）', _yearlyIncomeCategoryMonthly, _incomeCatKeys),
        if (_yearlyExpenseByCategory.isEmpty &&
            _yearlyIncomeByCategory.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('この年のデータがありません',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryLineSection(
      String title,
      Map<String, List<int>> categoryData,
      Map<String, GlobalKey> keys) {
    final categories = categoryData.keys.toList()
      ..sort((a, b) => categoryData[b]!.reduce((x, y) => x + y)
          .compareTo(categoryData[a]!.reduce((x, y) => x + y)));

    final colors = List.generate(
        categories.length, (i) => _palette[i % _palette.length]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final color = colors[i];
              return ActionChip(
                visualDensity: VisualDensity.compact,
                backgroundColor: color.withValues(alpha: 0.12),
                side: BorderSide(color: color),
                label: Text(cat,
                    style: TextStyle(fontSize: 12, color: color)),
                onPressed: () {
                  final keyCtx = keys[cat]?.currentContext;
                  if (keyCtx != null) {
                    Scrollable.ensureVisible(
                      keyCtx,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < categories.length; i++) ...[
          Card(
            key: keys[categories[i]],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: colors[i], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(categories[i],
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        '年間 ¥${_formatAmount(categoryData[categories[i]]!.reduce((a, b) => a + b))}',
                        style:
                            TextStyle(fontSize: 12, color: colors[i]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: CustomPaint(
                      painter: _LineChartPainter(
                        seriesList: [
                          _SeriesData(
                            data: List<int>.from(
                                categoryData[categories[i]] ?? []),
                            color: colors[i],
                          ),
                        ],
                        formatAmount: _formatAmount,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i < categories.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildTwoSeriesLegend(
      String label1, Color color1, String label2, Color color2) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _legendDot(color1),
        const SizedBox(width: 4),
        Text(label1, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 12),
        _legendDot(color2),
        const SizedBox(width: 4),
        Text(label2, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ── 共通ウィジェット ──────────────────────────────────────────

  Widget _buildSummaryCard(
      {required List<(String, int, Color)> items}) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final (label, amount, color) in items)
              _summaryItem(label, amount, color),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
      {required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, int amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '¥${_formatAmount(amount)}',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _formatAmount(int amount) {
    return NumberFormat('#,###').format(amount);
  }
}

// ── 円グラフ ──────────────────────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final List<double> ratios;
  final List<Color> colors;

  _PieChartPainter({required this.ratios, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 2;
    const gap = 0.012;

    double startAngle = -pi / 2;
    for (int i = 0; i < ratios.length; i++) {
      final sweep = (ratios[i] * 2 * pi - gap).clamp(0.0, 2 * pi);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gap / 2,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      startAngle += ratios[i] * 2 * pi;
    }

    canvas.drawCircle(center, radius * 0.52,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── 折れ線グラフ ──────────────────────────────────────────────────

class _SeriesData {
  final List<int> data;
  final Color color;
  const _SeriesData({required this.data, required this.color});
}

class _LineChartPainter extends CustomPainter {
  final List<_SeriesData> seriesList;
  final String Function(int) formatAmount;

  _LineChartPainter({required this.seriesList, required this.formatAmount});

  static const _leftPad = 52.0;
  static const _rightPad = 8.0;
  static const _topPad = 8.0;
  static const _bottomPad = 28.0;
  static const _gridCount = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;

    final maxVal = seriesList
        .expand((s) => s.data)
        .fold(1, (a, b) => a > b ? a : b)
        .toDouble();

    _drawGrid(canvas, chartW, chartH, maxVal);
    _drawXLabels(canvas, chartW, chartH);
    for (final s in seriesList) {
      _drawSeries(canvas, s.data, s.color, chartW, chartH, maxVal);
    }
  }

  void _drawGrid(Canvas canvas, double chartW, double chartH, double maxVal) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= _gridCount; i++) {
      final y = _topPad + chartH * (1 - i / _gridCount);
      canvas.drawLine(
          Offset(_leftPad, y), Offset(_leftPad + chartW, y), gridPaint);

      final label = formatAmount((maxVal * i / _gridCount).toInt());
      _drawText(canvas, label, Offset(0, y - 5),
          textAlign: TextAlign.right, maxWidth: _leftPad - 6);
    }
  }

  void _drawXLabels(Canvas canvas, double chartW, double chartH) {
    const months = [
      '1', '2', '3', '4', '5', '6',
      '7', '8', '9', '10', '11', '12'
    ];
    for (int i = 0; i < 12; i++) {
      final x = _leftPad + chartW * i / 11;
      canvas.drawLine(
        Offset(x, _topPad),
        Offset(x, _topPad + chartH),
        Paint()
          ..color = const Color(0xFFF5F5F5)
          ..strokeWidth = 0.5,
      );
      _drawText(
        canvas,
        '${months[i]}月',
        Offset(x - 10, _topPad + chartH + 6),
        maxWidth: 22,
      );
    }
  }

  void _drawSeries(Canvas canvas, List<int> data, Color color,
      double chartW, double chartH, double maxVal) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = _leftPad + chartW * i / 11;
      final y = _topPad + chartH * (1 - data[i] / maxVal);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (data.any((v) => v > 0)) canvas.drawPath(path, linePaint);

    final dotFill = Paint()..color = color;
    final dotBg = Paint()..color = Colors.white;
    for (int i = 0; i < data.length; i++) {
      if (data[i] == 0) continue;
      final x = _leftPad + chartW * i / 11;
      final y = _topPad + chartH * (1 - data[i] / maxVal);
      canvas.drawCircle(Offset(x, y), 4.5, dotBg);
      canvas.drawCircle(Offset(x, y), 3.0, dotFill);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset,
      {TextAlign textAlign = TextAlign.left, double maxWidth = 60}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 10)),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
