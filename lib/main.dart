import 'dart:io';

import 'package:context_menus/context_menus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_browser/models/browser_model.dart';
import 'package:flutter_browser/models/webview_model.dart';
import 'package:flutter_browser/models/window_model.dart';
import 'package:flutter_browser/util.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager_plus/window_manager_plus.dart';
import 'package:path/path.dart' as p;

import 'browser.dart';

// ignore: non_constant_identifier_names
late final String WEB_ARCHIVE_DIR;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_1;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_2;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_3;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_1 = 0.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_2 = 10.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_3 = 20.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_SCALE_TOP_OFFSET = 250.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_SCALE_BOTTOM_OFFSET = 230.0;

WebViewEnvironment? webViewEnvironment;
Database? db;
File? _privacyConsentFile;

const String _privacyPolicyUrl = 'https://www.shandun.top/privacy';
const String _userAgreementUrl = 'https://www.shandun.top/terms';

int windowId = 0;
String? windowModelId;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Util.isDesktop()) {
    windowId = args.isNotEmpty ? int.tryParse(args[0]) ?? 0 : 0;
    windowModelId = args.length > 1 ? args[1] : null;
    await WindowManagerPlus.ensureInitialized(windowId);
  }

  final appDocumentsDir = await getApplicationDocumentsDirectory();
  _privacyConsentFile =
      File(p.join(appDocumentsDir.path, 'privacy_policy_accepted_v1'));

  if (Util.isDesktop()) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  db = await databaseFactory.openDatabase(
      p.join(appDocumentsDir.path, "databases", "myDb.db"),
      options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (Database db, int version) async {
            await db.execute(
                'CREATE TABLE browser (id INTEGER PRIMARY KEY, json TEXT)');
            await db.execute(
                'CREATE TABLE windows (id TEXT PRIMARY KEY, json TEXT)');
          }));

  if (Util.isDesktop()) {
    WindowOptions windowOptions = WindowOptions(
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle:
          Util.isWindows() ? TitleBarStyle.normal : TitleBarStyle.hidden,
      minimumSize: const Size(1280, 720),
      size: const Size(1280, 720),
    );
    WindowManagerPlus.current.waitUntilReadyToShow(windowOptions, () async {
      if (!Util.isWindows()) {
        await WindowManagerPlus.current.setAsFrameless();
        await WindowManagerPlus.current.setHasShadow(true);
      }
      await WindowManagerPlus.current.show();
      await WindowManagerPlus.current.focus();
    });
  }

  WEB_ARCHIVE_DIR = (await getApplicationSupportDirectory()).path;

  TAB_VIEWER_BOTTOM_OFFSET_1 = 150.0;
  TAB_VIEWER_BOTTOM_OFFSET_2 = 160.0;
  TAB_VIEWER_BOTTOM_OFFSET_3 = 170.0;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    assert(availableVersion != null,
        'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.');

    webViewEnvironment = await WebViewEnvironment.create(
        settings:
            WebViewEnvironmentSettings(userDataFolder: 'flutter_browser_app'));
  }

  if (Util.isMobile()) {
    await FlutterDownloader.initialize(debug: kDebugMode);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => BrowserModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => WebViewModel(),
        ),
        ChangeNotifierProxyProvider<WebViewModel, WindowModel>(
          update: (context, webViewModel, windowModel) {
            windowModel!.setCurrentWebViewModel(webViewModel);
            return windowModel;
          },
          create: (BuildContext context) => WindowModel(id: null),
        ),
      ],
      child: const FlutterBrowserApp(),
    ),
  );
}

class FlutterBrowserApp extends StatefulWidget {
  const FlutterBrowserApp({super.key});

  @override
  State<FlutterBrowserApp> createState() => _FlutterBrowserAppState();
}

class _FlutterBrowserAppState extends State<FlutterBrowserApp>
    with WindowListener {
  // https://github.com/pichillilorenzo/window_manager_plus/issues/5
  AppLifecycleListener? _appLifecycleListener;

  @override
  void initState() {
    super.initState();
    if (Util.isDesktop()) {
      WindowManagerPlus.current.addListener(this);

      // https://github.com/pichillilorenzo/window_manager_plus/issues/5
      if (WindowManagerPlus.current.id > 0 && Platform.isMacOS) {
        _appLifecycleListener = AppLifecycleListener(
          onStateChange: _handleStateChange,
        );
      }
    }
  }

  void _handleStateChange(AppLifecycleState state) {
    // https://github.com/pichillilorenzo/window_manager_plus/issues/5
    if (Util.isDesktop() &&
        WindowManagerPlus.current.id > 0 &&
        Platform.isMacOS &&
        state == AppLifecycleState.hidden) {
      SchedulerBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
  }

  @override
  void dispose() {
    if (Util.isDesktop()) {
      WindowManagerPlus.current.removeListener(this);
    }
    _appLifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialApp = MaterialApp(
      title: '闪盾浏览器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PrivacyConsentGate(),
      },
    );

    return Util.isMobile()
        ? materialApp
        : ContextMenuOverlay(
            child: materialApp,
          );
  }

  @override
  void onWindowFocus([int? windowId]) {
    setState(() {});
    if (Util.isDesktop() && !Util.isWindows()) {
      WindowManagerPlus.current.setMovable(false);
    }
  }

  @override
  void onWindowBlur([int? windowId]) {
    if (Util.isDesktop() && !Util.isWindows()) {
      WindowManagerPlus.current.setMovable(true);
    }
  }
}

class PrivacyConsentGate extends StatefulWidget {
  const PrivacyConsentGate({super.key});

  @override
  State<PrivacyConsentGate> createState() => _PrivacyConsentGateState();
}

class _PrivacyConsentGateState extends State<PrivacyConsentGate> {
  late Future<bool> _acceptedFuture;
  var _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _acceptedFuture = Util.isAndroid()
        ? _hasAcceptedPrivacyPolicy()
        : Future<bool>.value(true);
  }

  Future<bool> _hasAcceptedPrivacyPolicy() async {
    final file = _privacyConsentFile;
    return file == null || file.existsSync();
  }

  Future<void> _acceptPrivacyPolicy() async {
    final file = _privacyConsentFile;
    if (file == null) {
      return;
    }
    await file.create(recursive: true);
    await file.writeAsString(DateTime.now().toIso8601String());
  }

  Future<void> _openPolicyLink(String url, String errorMessage) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _showPrivacyDialog() {
    if (_dialogShown) {
      return;
    }
    _dialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('隐私政策提示'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '欢迎使用闪盾浏览器。请先阅读并同意用户协议和隐私政策，了解服务规则以及我们如何处理必要的设备权限和使用数据。',
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _openPolicyLink(
                  _userAgreementUrl,
                  '无法打开用户协议',
                ),
                child: const Text('查看《用户协议》'),
              ),
              TextButton(
                onPressed: () => _openPolicyLink(
                  _privacyPolicyUrl,
                  '无法打开隐私政策',
                ),
                child: const Text('查看《隐私政策》'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('不同意'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _acceptPrivacyPolicy();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('同意并继续'),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }

      if (accepted == true) {
        setState(() {
          _acceptedFuture = Future<bool>.value(true);
        });
      } else {
        SystemNavigator.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _acceptedFuture,
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return const Browser();
        }

        if (snapshot.connectionState != ConnectionState.waiting) {
          _showPrivacyDialog();
        }

        return const Scaffold(
          body: SizedBox.expand(),
        );
      },
    );
  }
}
