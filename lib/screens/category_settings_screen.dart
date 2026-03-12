// lib/screens/category_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _expenseCategories =
          prefs.getStringList('categories') ?? ['食費', '日用品', '交通費'];
      _incomeCategories =
          prefs.getStringList('income_categories') ?? ['給与', '副収入', 'その他'];
    });
  }

  Future<void> _saveExpenseCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('categories', _expenseCategories);
  }

  Future<void> _saveIncomeCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('income_categories', _incomeCategories);
  }

  void _addCategory() {
    if (_controller.text.isEmpty) return;
    setState(() {
      if (_tabController.index == 0) {
        _expenseCategories.add(_controller.text);
        _saveExpenseCategories();
      } else {
        _incomeCategories.add(_controller.text);
        _saveIncomeCategories();
      }
      _controller.clear();
    });
  }

  void _deleteCategory(int index) {
    setState(() {
      if (_tabController.index == 0) {
        _expenseCategories.removeAt(index);
        _saveExpenseCategories();
      } else {
        _incomeCategories.removeAt(index);
        _saveIncomeCategories();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('項目の設定'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出カテゴリ'),
            Tab(text: '収入カテゴリ'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: '新しい項目名'),
                    onSubmitted: (_) => _addCategory(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addCategory,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_expenseCategories),
                _buildList(_incomeCategories),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<String> categories) {
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(categories[index]),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteCategory(index),
          ),
        );
      },
    );
  }
}
