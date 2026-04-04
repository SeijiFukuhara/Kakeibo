// lib/screens/category_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── トップレベルの設定メニュー ─────────────────────────────────────────
class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  State<CategorySettingsScreen> createState() =>
      _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  int _firstDayOfWeek = 0; // 0=日, 1=月, 6=土

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstDayOfWeek = prefs.getInt('first_day_of_week') ?? 0;
    });
  }

  Future<void> _saveFirstDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('first_day_of_week', day);
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
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
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
            leading: const Icon(Icons.calendar_view_week_outlined),
            title: const Text('先頭の曜日'),
            subtitle: Text(_firstDayLabel(_firstDayOfWeek)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showFirstDayDialog,
          ),
        ],
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

  List<String> _dailyExpense = [];
  List<String> _monthlyExpense = [];
  List<String> _dailyIncome = [];
  List<String> _monthlyIncome = [];

  static const _keys = [
    'categories',
    'monthly_expense_categories',
    'income_categories',
    'monthly_income_categories',
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
    super.dispose();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyExpense =
          prefs.getStringList(_keys[0]) ?? ['食費', '日用品', '交通費'];
      _monthlyExpense =
          prefs.getStringList(_keys[1]) ?? ['家賃', '光熱費', '通信費'];
      _dailyIncome =
          prefs.getStringList(_keys[2]) ?? ['給与', '副収入', 'その他'];
      _monthlyIncome =
          prefs.getStringList(_keys[3]) ?? ['給与', '副収入'];
    });
  }


  Future<void> _save(String key, List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, list);
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
                  dailyKey: _keys[0],
                  monthlyKey: _keys[1],
                ),
                _buildPage(
                  dailyList: _dailyIncome,
                  monthlyList: _monthlyIncome,
                  dailyKey: _keys[2],
                  monthlyKey: _keys[3],
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
    required String dailyKey,
    required String monthlyKey,
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
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('項目がありません',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          )
        else
          ...list.asMap().entries.map(
                (entry) => ListTile(
                  dense: true,
                  title: Text(entry.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _delete(list, key, entry.key),
                  ),
                  onTap: () => _rename(list, key, entry.key),
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
