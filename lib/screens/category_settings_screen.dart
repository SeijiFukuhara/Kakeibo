// lib/screens/category_settings_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/account_storage.dart';
import '../services/firestore_service.dart';

// ── トップレベルの設定メニュー ─────────────────────────────────────────
class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  State<CategorySettingsScreen> createState() =>
      _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  int _firstDayOfWeek = 0; // 0=日, 1=月, 6=土
  List<SavedAccount> _savedAccounts = [];
  String? _currentEmail;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // サブ画面から戻ったとき用に再読み込みしない（initStateで十分）
  }

  Future<void> _loadSettings() async {
    final data = await FirestoreService.getSettings();
    final accounts = await AccountStorage.loadAccounts();
    if (!mounted) return;
    setState(() {
      _firstDayOfWeek = (data['first_day_of_week'] as int?) ?? 0;
      _savedAccounts = accounts;
      _currentEmail = FirebaseAuth.instance.currentUser?.email;
    });
  }

  Future<void> _saveFirstDay(int day) async {
    await FirestoreService.saveSettings({'first_day_of_week': day});
    if (!mounted) return;
    setState(() => _firstDayOfWeek = day);
  }

  String _firstDayLabel(int day) {
    switch (day) {
      case 1:
        return '月曜日';
      case 6:
        return '土曜日';
      default:
        return '日曜日';
    }
  }

  Future<void> _switchAccount(SavedAccount account) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: account.email,
        password: account.password,
      );
      await AccountStorage.saveAccount(account.email, account.password);
      if (mounted) Navigator.of(context).pop(); // ボトムシートを閉じる
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切り替え失敗: ${e.message}')),
        );
      }
    }
  }

  void _showAccountSwitcher() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'アカウントを切り替え',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_currentEmail != null)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(_currentEmail!),
                subtitle: const Text('現在のアカウント'),
              ),
            ..._savedAccounts
                .where((a) => a.email != _currentEmail)
                .map(
                  (account) => ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: Text(account.email),
                    onTap: () => _switchAccount(account),
                  ),
                ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('ログアウト', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFirstDayDialog() {
    int tempValue = _firstDayOfWeek;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('先頭の曜日'),
          content: RadioGroup<int>(
            groupValue: tempValue,
            onChanged: (v) {
              if (v != null) setDialogState(() => tempValue = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (value, label) in [
                  (0, '日曜日'),
                  (1, '月曜日'),
                  (6, '土曜日'),
                ])
                  RadioListTile<int>(
                    title: Text(label),
                    value: value,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: tempValue != _firstDayOfWeek
                  ? () async {
                      await _saveFirstDay(tempValue);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
              child: const Text('決定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('項目の追加・編集'),
            subtitle: const Text('収支カテゴリの管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _CategoryDetailScreen()),
              );
              await _loadSettings();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('予算の設定'),
            subtitle: const Text('カテゴリごとの月次予算'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _BudgetSettingScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.calendar_view_week_outlined),
            title: const Text('先頭の曜日'),
            subtitle: Text(_firstDayLabel(_firstDayOfWeek)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showFirstDayDialog,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('アカウントを切り替え'),
            subtitle: Text(_currentEmail ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAccountSwitcher,
          ),
        ],
        ),
      ),
    );
  }
}

// ── 項目の設定サブ画面 ────────────────────────────────────────────────
class _CategoryDetailScreen extends StatefulWidget {
  const _CategoryDetailScreen();

  @override
  State<_CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<_CategoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _dailyCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _subscriptionCtrl = TextEditingController();

  List<String> _dailyExpense = [];
  List<String> _monthlyExpense = [];
  List<String> _subscriptionExpense = [];
  List<String> _dailyIncome = [];
  List<String> _monthlyIncome = [];
  List<String> _subscriptionIncome = [];

  static const _keys = [
    'categories',                       // 0: 日々の支出
    'monthly_expense_categories',       // 1: 月ごとの支出
    'income_categories',                // 2: 日々の収入
    'monthly_income_categories',        // 3: 月ごとの収入
    'subscription_expense_categories',  // 4: サブスク支出
    'subscription_income_categories',   // 5: サブスク収入
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dailyCtrl.dispose();
    _monthlyCtrl.dispose();
    _subscriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final data = await FirestoreService.getSettings();

    var monthlyExpense =
        List<String>.from(data[_keys[1]] ?? ['家賃', '光熱費', '通信費']);
    var subscriptionExpense =
        List<String>.from(data[_keys[4]] ?? []);

    // 初回: monthly_expense_categories に含まれる「サブスク」項目を自動移行
    if (!data.containsKey(_keys[4])) {
      final toMove =
          monthlyExpense.where((c) => c.contains('サブスク')).toList();
      if (toMove.isNotEmpty) {
        monthlyExpense =
            monthlyExpense.where((c) => !c.contains('サブスク')).toList();
        subscriptionExpense = toMove;
        await FirestoreService.saveSettings({
          _keys[1]: monthlyExpense,
          _keys[4]: subscriptionExpense,
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _dailyExpense =
          List<String>.from(data[_keys[0]] ?? ['食費', '日用品', '交通費']);
      _monthlyExpense = monthlyExpense;
      _subscriptionExpense = subscriptionExpense;
      _dailyIncome =
          List<String>.from(data[_keys[2]] ?? ['給与', '副収入', 'その他']);
      _monthlyIncome =
          List<String>.from(data[_keys[3]] ?? ['給与', '副収入']);
      _subscriptionIncome =
          List<String>.from(data[_keys[5]] ?? []);
    });
  }

  Future<void> _save(String key, List<String> list) async {
    await FirestoreService.saveSettings({key: list});
  }

  void _add(List<String> list, String key, TextEditingController ctrl) {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => list.add(name));
    ctrl.clear();
    _save(key, list);
  }

  void _delete(List<String> list, String key, int index) {
    setState(() => list.removeAt(index));
    _save(key, list);
  }

  void _rename(List<String> list, String key, int index) {
    final ctrl = TextEditingController(text: list[index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('項目名を変更'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() => list[index] = newName);
                _save(key, list);
              }
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('項目の設定'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '収入'),
          ],
        ),
      ),
      body: Column(
        children: [
          // カテゴリ設定タブ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPage(
                  dailyList: _dailyExpense,
                  monthlyList: _monthlyExpense,
                  subscriptionList: _subscriptionExpense,
                  dailyKey: _keys[0],
                  monthlyKey: _keys[1],
                  subscriptionKey: _keys[4],
                ),
                _buildPage(
                  dailyList: _dailyIncome,
                  monthlyList: _monthlyIncome,
                  subscriptionList: _subscriptionIncome,
                  dailyKey: _keys[2],
                  monthlyKey: _keys[3],
                  subscriptionKey: _keys[5],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage({
    required List<String> dailyList,
    required List<String> monthlyList,
    required List<String> subscriptionList,
    required String dailyKey,
    required String monthlyKey,
    required String subscriptionKey,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSection(
          title: '日ごとの項目',
          list: dailyList,
          key: dailyKey,
          ctrl: _dailyCtrl,
        ),
        const Divider(height: 32, thickness: 1),
        _buildSection(
          title: '月ごとの項目',
          list: monthlyList,
          key: monthlyKey,
          ctrl: _monthlyCtrl,
        ),
        const Divider(height: 32, thickness: 1),
        _buildSection(
          title: 'サブスクの項目',
          list: subscriptionList,
          key: subscriptionKey,
          ctrl: _subscriptionCtrl,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> list,
    required String key,
    required TextEditingController ctrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.swap_vert, size: 14, color: Colors.black38),
              const Text('ドラッグで並び替え',
                  style: TextStyle(fontSize: 11, color: Colors.black38)),
            ],
          ),
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('項目がありません',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
              });
              _save(key, list);
            },
            itemBuilder: (_, index) => ListTile(
              key: ValueKey('$key-$index-${list[index]}'),
              dense: true,
              title: Text(list[index]),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _delete(list, key, index),
              ),
              onTap: () => _rename(list, key, index),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: '新しい項目名',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(list, key, ctrl),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _add(list, key, ctrl),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('追加'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 予算設定画面 ──────────────────────────────────────────────────────────
class _BudgetSettingScreen extends StatefulWidget {
  const _BudgetSettingScreen();

  @override
  State<_BudgetSettingScreen> createState() => _BudgetSettingScreenState();
}

class _BudgetSettingScreenState extends State<_BudgetSettingScreen> {
  List<String> _categories = [];
  Map<String, int> _budgets = {};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await FirestoreService.getSettings();
    final budgets = await FirestoreService.getBudgets(_month);
    final daily =
        List<String>.from(settings['categories'] ?? ['食費', '日用品', '交通費']);
    final monthly = List<String>.from(
        settings['monthly_expense_categories'] ?? ['家賃', '光熱費', '通信費']);
    final seen = <String>{};
    final unique =
        [...daily, ...monthly].where((c) => seen.add(c)).toList();
    if (!mounted) return;
    setState(() {
      _categories = unique;
      _budgets = budgets;
    });
  }

  void _editBudget(String category) {
    final ctrl = TextEditingController(
      text: _budgets.containsKey(category) ? _budgets[category].toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$category の月次予算'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '金額 (円)',
            border: OutlineInputBorder(),
            prefixText: '¥',
          ),
        ),
        actions: [
          if (_budgets.containsKey(category))
            TextButton(
              onPressed: () {
                setState(() => _budgets.remove(category));
                FirestoreService.saveBudgets(_month, _budgets);
                Navigator.pop(ctx);
              },
              child: const Text('削除', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(ctrl.text.replaceAll(',', ''));
              if (amount != null && amount > 0) {
                setState(() => _budgets[category] = amount);
                FirestoreService.saveBudgets(_month, _budgets);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return Scaffold(
      appBar: AppBar(title: const Text('予算の設定')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                      _budgets = {};
                    });
                    _load();
                  },
                ),
                Text(
                  '${_month.year}年${_month.month}月',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                      _budgets = {};
                    });
                    _load();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _categories.isEmpty
                ? const Center(child: Text('支出カテゴリがありません'))
                : ListView.separated(
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final budget = _budgets[cat];
                      return ListTile(
                        title: Text(cat),
                        subtitle: budget != null
                            ? Text('¥${fmt.format(budget)} / 月')
                            : const Text('未設定',
                                style: TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _editBudget(cat),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
