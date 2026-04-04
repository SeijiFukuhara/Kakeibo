# クラウドログイン導入計画

> このファイルを参照しながら、不明点をチャットで質問してください。
> 各セクションに番号を振っているので「Q2について聞きたい」のように指定できます。

---

## Q1. 無料枠について ── 何人まで無料で使えるか？

主要な選択肢を比較します。

| サービス | 認証（MAU）| データ保存 | 無料枠の目安人数 |
|----------|-----------|-----------|----------------|
| **Firebase**（Google）| 無制限 | Firestore: 読取5万/日, 書込2万/日, 1GB | 数十人規模なら余裕で無料 |
| **Supabase** | 5万 MAU | PostgreSQL 500MB, 転送5GB/月 | 数十人規模なら無料 |
| **AWS Cognito** | 5万 MAU | DynamoDB 25GB, 読取2億/月 | 数十人規模なら無料 |

### MAU（Monthly Active Users）とは
「1ヶ月以内にログインしたユーザー数」です。  
- 5万 MAU ＝ 月5万人がログインしても無料
- 家族・個人用途なら 5〜10人規模 → 完全無料で問題なし

### 結論
**Firebase が最も Flutter と相性がよく、無料枠も十分です（推奨）。**  
個人・家族利用なら無料枠を超えることはまずありません。

---

## Q2. Flutterで作れる全形式で「どこからでもログイン」は使えるか？

### Flutter が対応するプラットフォーム

| プラットフォーム | Firebase Auth | クラウドデータ同期 | 備考 |
|----------------|--------------|------------------|------|
| Android | ✅ | ✅ | 完全対応 |
| iOS | ✅ | ✅ | 完全対応 |
| Webアプリ（ブラウザ） | ✅ | ✅ | 完全対応 |
| Windows デスクトップ | ✅ | ✅ | Firebase 6.0以降で対応済 |
| macOS デスクトップ | ✅ | ✅ | 完全対応 |
| Linux デスクトップ | ✅ | ✅ | 完全対応 |

**すべてのプラットフォームで有効です。**  
同じ Firebase プロジェクト・同じアカウントを使えば、どの端末でログインしても同じデータにアクセスできます。

### 現在のアプリとの違い
- 現在：SharedPreferences（端末内ローカル保存）→ 他の端末からは見えない
- 変更後：Firestore（クラウド保存）→ どの端末でも同じデータ

---

## Q3. 推奨方法（Firebase）の詳細手順

### 全体の流れ

```
[Step 1] Firebase プロジェクト作成（Webコンソール）
[Step 2] Flutter に Firebase を接続（CLI）
[Step 3] メール認証の有効化
[Step 4] Flutter コードにログイン画面を追加
[Step 5] データ保存先を SharedPreferences → Firestore に変更
[Step 6] 各プラットフォーム向けビルド設定
```

---

### Step 1: Firebase プロジェクト作成

1. ブラウザで https://console.firebase.google.com を開く
2. 「プロジェクトを追加」をクリック
3. プロジェクト名を入力（例: `kakeibo-app`）
4. Google アナリティクスは「今は不要」で OK → 「プロジェクトを作成」
5. 作成完了後、プロジェクトのダッシュボードが開く

---

### Step 2: FlutterFire CLI でプロジェクト接続

**前提：Node.js と Flutter SDK がインストール済みであること**

```bash
# 1. Firebase CLI をインストール
npm install -g firebase-tools

# 2. Firebase にログイン
firebase login

# 3. FlutterFire CLI をインストール
dart pub global activate flutterfire_cli

# 4. プロジェクトフォルダで実行
cd C:\Users\seiji\Flutter\kakeibo_app_mvp_2
flutterfire configure
```

`flutterfire configure` を実行すると：
- Firebaseプロジェクトの一覧が出るので選択
- Android / iOS / Web / Windows などのプラットフォームを選択
- `lib/firebase_options.dart` が自動生成される

---

### Step 3: メール認証を有効化

1. Firebase コンソール → 左メニュー「Authentication」
2. 「始める」→「Sign-in method」タブ
3. 「メール / パスワード」をクリック → 有効にする → 保存

---

### Step 4: Flutter パッケージを追加

`pubspec.yaml` に追記：

```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
```

```bash
flutter pub get
```

---

### Step 5: main.dart を修正

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ja_JP', null);
  runApp(const MyApp());
}
```

---

### Step 6: ログイン画面を作成

新ファイル `lib/screens/login_screen.dart` を作成：

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true; // true=ログイン, false=新規登録
  String? _error;

  Future<void> _submit() async {
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'ログイン' : '新規登録')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _emailController,
              decoration: const InputDecoration(labelText: 'メールアドレス')),
            TextField(controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'パスワード')),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit,
              child: Text(_isLogin ? 'ログイン' : '登録')),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? '新規登録はこちら' : 'ログインはこちら')),
          ],
        ),
      ),
    );
  }
}
```

---

### Step 7: 認証状態に応じて画面を切り替え

`main.dart` の `home:` を変更：

```dart
home: StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    if (snapshot.hasData) {
      return const MainScreen(); // ログイン済み
    }
    return const LoginScreen(); // 未ログイン
  },
),
```

---

### Step 8: データを Firestore に移行

現在の SharedPreferences のキー構造を Firestore に対応させます。

**Firestore のデータ構造（案）：**

```
/users/{uid}/entries/{date}/          ← 日ごとの記録
/users/{uid}/monthly/{year-month}/    ← 月ごとの固定費
```

SharedPreferences の読み書きを Firestore に置き換える作業が必要です。  
（この部分は別途チャットで詳しく進めましょう）

---

### Step 9: Firestore のセキュリティルール設定

Firebase コンソール → Firestore → 「ルール」タブ：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

これにより、**自分のデータしか読み書きできない**セキュリティが確保されます。

---

## 今後の進め方（チャットでの質問例）

- 「Step 2 の flutterfire configure でエラーが出ました：[エラーメッセージ]」
- 「Step 8 の Firestore への移行を進めてください」
- 「ログアウトボタンを設定画面に追加したい」
- 「パスワードリセット機能を追加したい」

---

## コスト感のまとめ

| 用途 | 無料枠で賄えるか |
|------|----------------|
| 家族・個人（〜10人） | ✅ 完全無料 |
| 友人グループ（〜100人） | ✅ 無料 |
| 小規模サービス（〜1000人） | ✅ ほぼ無料（読取数に注意） |
| 商用サービス（1万人〜） | ⚠️ 有料プランを検討 |
