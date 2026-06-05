import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'databases/database_helper.dart';
import 'repositories/book_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/goal_repository.dart';
import 'repositories/checkin_repository.dart';
import 'providers/books_provider.dart';
import 'providers/filter_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/checkin_provider.dart';
import 'services/notification_service.dart';
import 'services/reminder_scheduler.dart';
import 'theme/app_theme.dart';
import 'routes/route_generator.dart';
import 'routes/app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 同步初始化：仅创建单例引用的同步构造，不触发 async 操作
  final dbHelper = DatabaseHelper.instance;
  final bookRepository = BookRepository(dbHelper);
  final settingsRepository = SettingsRepository(dbHelper);
  final goalRepository = GoalRepository(dbHelper);

  // [关键] 通知服务等耗时初始化全部后置到首帧之后
  // 确保 Flutter 引擎启动后立即渲染 SplashPage，消除启动白屏

  runApp(
    _DelayedInitApp(
      bookRepository: bookRepository,
      settingsRepository: settingsRepository,
      goalRepository: goalRepository,
      checkinRepository: CheckinRepository(dbHelper),
    ),
  );
}

/// 包装层：先快速渲染 SplashPage，再在首帧后进行异步初始化
class _DelayedInitApp extends StatelessWidget {
  final BookRepository bookRepository;
  final SettingsRepository settingsRepository;
  final GoalRepository goalRepository;
  final CheckinRepository checkinRepository;

  const _DelayedInitApp({
    required this.bookRepository,
    required this.settingsRepository,
    required this.goalRepository,
    required this.checkinRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CheckinProvider(
            repository: checkinRepository,
            bookRepository: bookRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BooksProvider(
            repository: bookRepository,
            settingsRepository: settingsRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            repository: settingsRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PurchaseProvider(
            repository: settingsRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FilterProvider(
            bookRepository: bookRepository,
            settingsRepository: settingsRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            repository: settingsRepository,
          ),
        ),
      ],
      child: _DelayedInitWrapper(
        bookRepository: bookRepository,
        settingsRepository: settingsRepository,
      ),
    );
  }
}

/// 首帧渲染后执行异步初始化
class _DelayedInitWrapper extends StatefulWidget {
  final BookRepository bookRepository;
  final SettingsRepository settingsRepository;

  const _DelayedInitWrapper({
    required this.bookRepository,
    required this.settingsRepository,
  });

  @override
  State<_DelayedInitWrapper> createState() => _DelayedInitWrapperState();
}

class _DelayedInitWrapperState extends State<_DelayedInitWrapper> {
  @override
  void initState() {
    super.initState();

    // 首帧渲染后再用微任务做耗时初始化，彻底不干扰首帧渲染和动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(_initAfterFirstFrame);
    });
  }

  Future<void> _initAfterFirstFrame() async {
    // 初始化通知服务
    await NotificationService().init();

    if (!mounted) return;

    // 加载数据
    context.read<CheckinProvider>().loadMonthCheckins();
    context.read<BooksProvider>().loadBooks();
    context.read<FilterProvider>().loadInitial();
    context.read<SettingsProvider>().loadSettings();
    context.read<PurchaseProvider>().loadPurchaseStatus();
    context.read<ThemeProvider>().loadTheme();

    // 恢复每日提醒调度
    Future.microtask(() async {
      if (!mounted) return;
      final booksProvider = context.read<BooksProvider>();
      final settingsProvider = context.read<SettingsProvider>();
      await ReminderScheduler().restoreAfterStartup(
        booksProvider: booksProvider,
        settingsProvider: settingsProvider,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: '读书进度条',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          locale: const Locale('zh', 'CN'),
          initialRoute: AppRoutes.splash,
          onGenerateRoute: RouteGenerator.generateRoute,
        );
      },
    );
  }
}
