import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key});

  @override
  State<DetailScreen> createState() => DetailScreenState();
}

class DetailScreenState extends State<DetailScreen> {
  int _monthStartDay = 1;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  // カテゴリ別にグループ化した収支（支出は日々のみ）
  Map<String, List<Map<String, String>>> _expenseByCategory = {};
  Map<String, List<Map<String, String>>> _incomeByCategory = {};
  Map<String, int> _budgets = {};

  // 設定の並び順
  List<String> _expenseCategoryOrder = [];
  List<String> _incomeCategoryOrder = [];

  bool _loading = true;

  void reload() => _loadData();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  (int year, int month) _logicalYearMonth(DateTime date) {
    if (_monthStartDay <= 1 || date.day < _monthStartDay) {
      return (date.year, date.month);
    }
    final next = DateTime(date.year, date.month + 1);
    return (next.year, next.month);
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

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final settings = await FirestoreService.getSettings();
    _monthStartDay = (settings['month_start_day'] as int?) ?? 1;
    _expenseCategoryOrder = [
      ...List<String>.from(settings['categories'] ?? []),
      ...List<String>.from(settings['monthly_expense_categories'] ?? []),
    ];
    _incomeCategoryOrder = [
      ...List<String>.from(settings['income_categories'] ?? []),
      ...List<String>.from(settings['monthly_income_categories'] ?? []),
    ];

    final expByCat = <String, List<Map<String, String>>>{};
    final incByCat = <String, List<Map<String, String>>>{};

    void add(Map<String, List<Map<String, String>>> map, String cat,
        Map<String, String> entry) {
      map.putIfAbsent(cat, () => []).add(entry);
    }

    // 日々の収支
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
        final cat = e['title'] ?? '不明';
        final row = {
          'amount': e['amount'] ?? '0',
          'type': e['type'] ?? 'expense',
          'comment': e['comment'] ?? '',
          'label': '$month/$day',
          'sortKey': '${month.toString().padLeft(2, '0')}${day.toString().padLeft(2, '0')}',
        };
        if (e['type'] == 'income') {
          add(incByCat, cat, row);
        } else {
          add(expByCat, cat, row);
        }
      }
    }

    // 支出カテゴリ設定にある項目を0円として補完（未使用カテゴリも表示）
    final dailyExpCats =
        List<String>.from(settings['categories'] ?? []);
    for (final cat in dailyExpCats) {
      expByCat.putIfAbsent(cat, () => []);
    }

    // 月固定（収入のみ）
    final incEntries =
        await FirestoreService.getMonthlyEntries('income', _month);

    for (final e in incEntries) {
      final cat = e['title'] ?? '収入';
      final d = e['day'] ?? '';
      add(incByCat, cat, {
        'amount': e['amount'] ?? '0',
        'type': 'income',
        'comment': e['comment'] ?? '',
        'label': d.isNotEmpty ? '$d日' : '月固定',
        'sortKey': '00${d.padLeft(2, '0')}',
      });
    }

    // サブスク（収入のみ）
    final allSubs = await FirestoreService.getSubscriptions();
    for (final s in allSubs) {
      if (!_isSubApplicable(s, _month)) continue;
      if (s['type'] != 'income') continue;
      final isYearly = s['cycle'] == 'yearly';
      final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
      final monthlyAmt = isYearly ? (raw / 12).round() : raw;
      final billingDay = s['billingDay'] ?? '';
      final label = isYearly
          ? (billingDay.isNotEmpty ? '毎年$billingDay月' : '年払')
          : (billingDay.isNotEmpty ? '毎月$billingDay日' : '定期');
      final catKey = s['category']?.isNotEmpty == true
          ? s['category']!
          : (s['title'] ?? '');
      add(incByCat, catKey, {
        'amount': '$monthlyAmt',
        'type': 'income',
        'comment': s['title'] ?? '',
        'label': label,
        'sortKey': '9999',
      });
    }

    // 予算
    final budgets = await FirestoreService.getBudgets(_month);

    if (!mounted) return;
    setState(() {
      _expenseByCategory = expByCat;
      _incomeByCategory = incByCat;
      _budgets = budgets;
      _loading = false;
    });
  }

  String _fmt(int amount) => NumberFormat('#,###').format(amount);

  int _catTotal(List<Map<String, String>> list) =>
      list.fold(0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

  @override
  Widget build(BuildContext context) {
    final hasAny =
        _expenseByCategory.isNotEmpty || _incomeByCategory.isNotEmpty;

    int orderIdx(String key, List<String> order) {
      final i = order.indexOf(key);
      return i == -1 ? order.length : i;
    }
    final sortedExp = _expenseByCategory.entries.toList()
      ..sort((a, b) => orderIdx(a.key, _expenseCategoryOrder)
          .compareTo(orderIdx(b.key, _expenseCategoryOrder)));
    final sortedInc = _incomeByCategory.entries.toList()
      ..sort((a, b) => orderIdx(a.key, _incomeCategoryOrder)
          .compareTo(orderIdx(b.key, _incomeCategoryOrder)));

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
                      setState(() =>
                          _month = DateTime(_month.year, _month.month - 1));
                      _loadData();
                    },
                  ),
                  Text(
                    '${_month.year}年${_month.month}月',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() =>
                          _month = DateTime(_month.year, _month.month + 1));
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
                  : !hasAny
                      ? const Center(
                          child: Text('この月のデータがありません',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                          children: [
                            if (sortedExp.isNotEmpty) ...[
                              _buildTypeHeader('支出（日々）', Colors.red,
                                  _expenseByCategory),
                              const SizedBox(height: 8),
                              for (final e in sortedExp) ...[
                                _buildCategoryCard(
                                    e.key, e.value, Colors.red,
                                    budget: _budgets[e.key]),
                                const SizedBox(height: 6),
                              ],
                              const SizedBox(height: 12),
                            ],
                            if (sortedInc.isNotEmpty) ...[
                              _buildTypeHeader('収入', Colors.green,
                                  _incomeByCategory),
                              const SizedBox(height: 8),
                              for (final e in sortedInc) ...[
                                _buildCategoryCard(
                                    e.key, e.value, Colors.green),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeHeader(String label, Color color,
      Map<String, List<Map<String, String>>> map) {
    final total =
        map.values.fold(0, (s, list) => s + _catTotal(list));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const Spacer(),
          Text('合計 ¥${_fmt(total)}',
              style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
      String category, List<Map<String, String>> entries, Color color,
      {int? budget}) {
    final total = _catTotal(entries);
    final sorted = [...entries]
      ..sort((a, b) => (a['sortKey'] ?? '').compareTo(b['sortKey'] ?? ''));

    final hasBudget = budget != null && budget > 0;
    final ratio =
        hasBudget ? (total / budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = hasBudget && total > budget;
    final Color barColor = overBudget
        ? Colors.red
        : ratio >= 0.8
            ? Colors.orange
            : Colors.green;

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        title: Row(
          children: [
            Expanded(
              child: Text(category,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text(
              '¥${_fmt(total)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: overBudget ? Colors.red : color),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasBudget) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                overBudget
                    ? '予算超過 ¥${_fmt(total - budget)} (¥${_fmt(budget)})'
                    : '予算の${(ratio * 100).toStringAsFixed(0)}% (¥${_fmt(budget)})',
                style: TextStyle(
                    fontSize: 11,
                    color: overBudget ? Colors.red : Colors.grey),
              ),
            ] else
              Text('${entries.length}件',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        children: sorted.map((e) => _buildEntryRow(e, color)).toList(),
      ),
    );
  }

  Widget _buildEntryRow(Map<String, String> e, Color color) {
    final comment = e['comment'] ?? '';
    final amount = int.tryParse(e['amount'] ?? '0') ?? 0;
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
            child: Text(e['label'] ?? '',
                style: TextStyle(fontSize: 11, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: comment.isNotEmpty
                ? Text(comment,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis)
                : const SizedBox.shrink(),
          ),
          Text('¥${_fmt(amount)}',
              style:
                  TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
