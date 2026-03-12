import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ← 追加
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakeibo_app_mvp_2/screens/calendar_screen.dart';

void main() async {
  // ウィジェットの初期化を確実に行う
  WidgetsFlutterBinding.ensureInitialized();

  // 日本語の言語データを読み込んでからアプリを起動
  await initializeDateFormatting('ja_JP', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 右上の「Debug」ラベルを非表示に
      title: '家計簿アプリ',

      // ★ 日本語化のための設定
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'), // 日本語をサポート
      ],
      locale: const Locale('ja', 'JP'), // デフォルトを日本語に設定

      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        // AppBarのデザインを統一
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
      ),
      home: const CalendarScreen(),
    );
  }
}
