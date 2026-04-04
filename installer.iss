; installer.iss - Inno Setup script for kakeibo_app_mvp_2
; Generated for Flutter Windows Release build

#define AppName      "家計簿アプリ"
#define AppVersion   "1.0.0"
#define AppPublisher "MyApp"
#define AppExeName   "kakeibo_app_mvp_2.exe"
#define SourceDir    "build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisherURL=
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
; アイコン
SetupIconFile={#SourceDir}\..\..\..\..\..\windows\runner\resources\app_icon.ico
; 出力先・ファイル名
OutputDir=installer_output
OutputBaseFilename=KakeiboApp_Setup_{#AppVersion}
; 圧縮設定
Compression=lzma2/ultra64
SolidCompression=yes
; Windows 10 以降を要求
MinVersion=10.0
; 64bit インストーラ
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; アンインストール情報
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
; ライセンス・情報ページ（不要なら削除可）
; LicenseFile=LICENSE.txt
; InfoBeforeFile=README.txt

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon";    Description: "デスクトップにショートカットを作成(&D)"; GroupDescription: "追加タスク:"
Name: "startmenuicon";  Description: "スタートメニューにショートカットを作成(&S)"; GroupDescription: "追加タスク:"; Flags: checkedonce

[Files]
; 実行ファイル本体
Source: "{#SourceDir}\{#AppExeName}";       DestDir: "{app}"; Flags: ignoreversion
; Flutter ランタイム DLL
Source: "{#SourceDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
; data フォルダ（app.so / icudtl.dat / flutter_assets 含む）
Source: "{#SourceDir}\data\*";              DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; スタートメニュー（常時作成）
Name: "{group}\{#AppName}";           Filename: "{app}\{#AppExeName}"
Name: "{group}\{#AppName} のアンインストール"; Filename: "{uninstallexe}"
; デスクトップ（タスク選択時のみ）
Name: "{autodesktop}\{#AppName}";     Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; インストール完了後にアプリを起動するか確認
Filename: "{app}\{#AppExeName}"; Description: "インストール完了後に {#AppName} を起動する"; Flags: nowait postinstall skipifsilent
