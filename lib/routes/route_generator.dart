import 'package:flutter/material.dart';
import '../pages/splash_page.dart';
import '../pages/add_book_page.dart';
import '../pages/finish_book_page.dart';
import '../pages/main_shell.dart';
import '../pages/pro_page.dart';
import '../pages/wish_book_page.dart';
import '../models/book.dart';
import 'app_routes.dart';

/// 路由生成器
class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());

      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 0));

      case AppRoutes.library:
        return MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 1));

      case AppRoutes.add:
        final args = settings.arguments;
        if (args is Map<String, String>) {
          return MaterialPageRoute(
            builder: (_) => AddBookPage(
              initialTitle: args['title'],
              initialAuthor: args['author'],
            ),
          );
        }
        // V3.2：编辑模式，传入 Book 对象
        if (args is Book) {
          return MaterialPageRoute(
            builder: (_) => AddBookPage(editBook: args),
          );
        }
        return MaterialPageRoute(builder: (_) => const AddBookPage());

      case AppRoutes.finish:
        final book = settings.arguments;
        if (book is Book) {
          return MaterialPageRoute(
            builder: (_) => FinishBookPage(book: book),
          );
        }
        return MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 1));

      case AppRoutes.stats:
        return MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 2));

      case AppRoutes.share:
        return MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 3));

      case AppRoutes.pro:
        return MaterialPageRoute(builder: (_) => const ProPage());

      case AppRoutes.wish:
        return MaterialPageRoute(builder: (_) => const WishBookPage());

      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 4));

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('页面不存在')),
            body: const Center(child: Text('404')),
          ),
        );
    }
  }
}
