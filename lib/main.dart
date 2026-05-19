import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'databases/database_helper.dart';
import 'repositories/book_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/goal_repository.dart';
import 'providers/books_provider.dart';
import 'providers/filter_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/reminder_scheduler.dart';
import 'theme/app_theme.dart';
import 'routes/route_generator.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库
  final dbHelper = DatabaseHelper.instance;

  // 初始化仓库
  final bookRepository = BookRepository(dbHelper);
  final settingsRepository = SettingsRepository(dbHelper);
  final goalRepository = GoalRepository(dbHelper);

  // 初始化通知服务
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
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
      child: const ReadingProgressApp(),
    ),
  );
}

class ReadingProgressApp extends StatefulWidget {
  const ReadingProgressApp({super.key});

  @override
  State<ReadingProgressApp> createState() => _ReadingProgressAppState();
}

class _ReadingProgressAppState extends State<ReadingProgressApp> {
  @override
  void initState() {
    super.initState();
    // 加载初始数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BooksProvider>().loadBooks();
      context.read<FilterProvider>().loadInitial();
      context.read<SettingsProvider>().loadSettings();
      context.read<PurchaseProvider>().loadPurchaseStatus();
      context.read<ThemeProvider>().loadTheme();

      // 恢复每日提醒调度
      Future.microtask(() async {
        final booksProvider = context.read<BooksProvider>();
        final settingsProvider = context.read<SettingsProvider>();
        await ReminderScheduler().restoreAfterStartup(
          booksProvider: booksProvider,
          settingsProvider: settingsProvider,
        );
      });
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
