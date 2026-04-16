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

  // 日々の収支
  List<Map<String, String>> _dailyIncomeList = [];
  List<Map<String, String>> _dailyExpenseList = [];

  // 月ごとの収支（固定費）
  List<Map<String, String>> _fixedIncomeList = [];
  List<Map<String, String>> _fixedExpenseList = [];

  // サブスク（当月適用分）
  List<Map<String, String>> _subIncomeList = [];
  List<Map<String, String>> _subExpenseList = [];

  bool _loading = true;

  void reload() => _loadData();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 日付から「論理月」を計算
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

    // ── 日々の収支 ────────────────────────────────
    final dailyIncList = <Map<String, String>>[];
    final dailyExpList = <Map<String, String>>[];

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
        final map = {
          'title': e['title'] ?? '不明',
          'amount': '$amount',
          'type': e['type'] ?? 'expense',
          'comment': e['comment'] ?? '',
          'date': '$month/$day',
        };
        if (e['type'] == 'income') {
          dailyIncList.add(map);
        } else {
          dailyExpList.add(map);
        }
      }
    }
    dailyIncList.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
    dailyExpList.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));

    // ── 月ごとの収支（固定費）────────────────────
    final incomeEntries =
        await FirestoreService.getMonthlyEntries('income', _month);
    final expenseEntries =
        await FirestoreService.getMonthlyEntries('expense', _month);

    final fixedIncList = incomeEntries.map((e) {
      final d = e['day'] ?? '';
      return {
        'title': e['title'] ?? '収入',
        'amount': e['amount'] ?? '0',
        'type': 'income',
        'comment': e['comment'] ?? '',
        'date': d.isNotEmpty ? '$d日' : '月固定',
      };
    }).toList();

    final fixedExpList = expenseEntries.map((e) {
      final d = e['day'] ?? '';
      return {
        'title': e['title'] ?? '支出',
        'amount': e['amount'] ?? '0',
        'type': 'expense',
        'comment': e['comment'] ?? '',
        'date': d.isNotEmpty ? '$d日' : '月固定',
      };
    }).toList();

    // ── サブスク（当月適用分）──────────────────────
    final allSubs = await FirestoreService.getSubscriptions();
    final subIncList = <Map<String, String>>[];
    final subExpList = <Map<String, String>>[];

    for (final s in allSubs) {
      if (!_isSubApplicable(s, _month)) continue;
      final isYearly = s['cycle'] == 'yearly';
      final raw = int.tryParse(s['amount'] ?? '0') ?? 0;
      final monthlyAmt = isYearly ? (raw / 12).round() : raw;
      final map = {
        'title': s['title'] ?? '',
        'amount': '$monthlyAmt',
        'type': s['type'] ?? 'expense',
        'comment': s['memo'] ?? '',
        'billingDay': s['billingDay'] ?? '',
        'cycle': s['cycle'] ?? 'monthly',
      };
      if (s['type'] == 'income') {
        subIncList.add(map);
      } else {
        subExpList.add(map);
      }
    }

    if (!mounted) return;
    setState(() {
      _dailyIncomeList = dailyIncList;
      _dailyExpenseList = dailyExpList;
      _fixedIncomeList = fixedIncList;
      _fixedExpenseList = fixedExpList;
      _subIncomeList = subIncList;
      _subExpenseList = subExpList;
      _loading = false;
    });
  }

  String _fmt(int amount) => NumberFormat('#,###').format(amount);

  int _sum(List<Map<String, String>> list) => list.fold(
      0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

  @override
  Widget build(BuildContext context) {
    final hasAny = _dailyIncomeList.isNotEmpty ||
        _dailyExpenseList.isNotEmpty ||
        _fixedIncomeList.isNotEmpty ||
        _fixedExpenseList.isNotEmpty ||
        _subIncomeList.isNotEmpty ||
        _subExpenseList.isNotEmpty;

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
            // コンテンツ
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
                            // 日々の収支
                            if (_dailyIncomeList.isNotEmpty ||
                                _dailyExpenseList.isNotEmpty) ...[
                              _SectionCard(
                                icon: Icons.calendar_today_outlined,
                                title: '日々の収支',
                                headerColor: Colors.blue.shade700,
                                incomeList: _dailyIncomeList,
                                expenseList: _dailyExpenseList,
                                formatAmount: _fmt,
                                rowBuilder: _buildDailyRow,
                              ),
                              const SizedBox(height: 12),
                            ],
                            // 月ごとの収支
                            if (_fixedIncomeList.isNotEmpty ||
                                _fixedExpenseList.isNotEmpty) ...[
                              _SectionCard(
                                icon: Icons.event_repeat_outlined,
                                title: '月ごとの収支',
                                headerColor: Colors.purple.shade700,
                                incomeList: _fixedIncomeList,
                                expenseList: _fixedExpenseList,
                                formatAmount: _fmt,
                                rowBuilder: _buildDailyRow,
                              ),
                              const SizedBox(height: 12),
                            ],
                            // サブスク
                            if (_subIncomeList.isNotEmpty ||
                                _subExpenseList.isNotEmpty)
                              _buildSubCard(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // 日々 / 月固定 行ウィジェット
  Widget _buildDailyRow(Map<String, String> e) {
    final isIncome = e['type'] == 'income';
    final color = isIncome ? Colors.green : Colors.red;
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
            '¥${_fmt(int.tryParse(e['amount'] ?? '0') ?? 0)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // サブスクカード
  Widget _buildSubCard() {
    final incTotal = _sum(_subIncomeList);
    final expTotal = _sum(_subExpenseList);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(Icons.repeat_outlined,
                    size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text('サブスク・定期払い',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700)),
              ],
            ),
            const Divider(height: 16),
            if (_subIncomeList.isNotEmpty) ...[
              _subHeader('収入（定期）', _fmt(incTotal), Colors.green),
              const SizedBox(height: 4),
              ..._subIncomeList.map(_buildSubRow),
            ],
            if (_subExpenseList.isNotEmpty) ...[
              if (_subIncomeList.isNotEmpty) const SizedBox(height: 10),
              _subHeader('支出（定期）', _fmt(expTotal), Colors.red),
              const SizedBox(height: 4),
              ..._subExpenseList.map(_buildSubRow),
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

  Widget _buildSubRow(Map<String, String> s) {
    final isIncome = s['type'] == 'income';
    final color = isIncome ? Colors.green : Colors.red;
    final isYearly = s['cycle'] == 'yearly';
    final billingDay = s['billingDay'] ?? '';
    final memo = s['comment'] ?? '';

    final label = isYearly
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
            child:
                Text(label, style: TextStyle(fontSize: 11, color: color)),
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
                '¥${_fmt(int.tryParse(s['amount'] ?? '0') ?? 0)}/月',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: color),
              ),
              if (isYearly)
                Text('(年払)',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── セクションカード（日々 / 月固定 共通）────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color headerColor;
  final List<Map<String, String>> incomeList;
  final List<Map<String, String>> expenseList;
  final String Function(int) formatAmount;
  final Widget Function(Map<String, String>) rowBuilder;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.headerColor,
    required this.incomeList,
    required this.expenseList,
    required this.formatAmount,
    required this.rowBuilder,
  });

  int _sum(List<Map<String, String>> list) => list.fold(
      0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

  @override
  Widget build(BuildContext context) {
    final incTotal = _sum(incomeList);
    final expTotal = _sum(expenseList);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(icon, size: 16, color: headerColor),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: headerColor)),
              ],
            ),
            const Divider(height: 16),

            if (incomeList.isNotEmpty) ...[
              _subHeader('収入', formatAmount(incTotal), Colors.green),
              const SizedBox(height: 4),
              ...incomeList.map(rowBuilder),
            ],
            if (expenseList.isNotEmpty) ...[
              if (incomeList.isNotEmpty) const SizedBox(height: 10),
              _subHeader('支出', formatAmount(expTotal), Colors.red),
              const SizedBox(height: 4),
              ...expenseList.map(rowBuilder),
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
}
