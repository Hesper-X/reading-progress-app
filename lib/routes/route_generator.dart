import 'package:flutter/material.dart';
import '../pages/splash_page.dart';
import '../pages/add_book_page.dart';
import '../pages/finish_book_page.dart';
import '../pages/main_shell.dart';
import '../pages/pro_page.dart';
import '../pages/wish_book_page.dart';
import '../pages/add_done_book_page.dart';
import '../pages/book_notes_page.dart';
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
        String? initialLibraryTab;
        final args = settings.arguments;
        if (args is Map<String, dynamic> && args['tab'] is String) {
          initialLibraryTab = args['tab'] as String;
        }
        return MaterialPageRoute(
          builder: (_) => MainShell(initialIndex: 1, initialLibraryTab: initialLibraryTab),
        );

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
        final wishArgs = settings.arguments;
        if (wishArgs is Book) {
          return MaterialPageRoute(builder: (_) => WishBookPage(editBook: wishArgs));
        }
        return MaterialPageRoute(builder: (_) => const WishBookPage());

      case AppRoutes.addDone:
        final addDoneArgs = settings.arguments;
        if (addDoneArgs is Book) {
          return MaterialPageRoute(
            builder: (_) => AddDoneBookPage(editBook: addDoneArgs),
          );
        }
        return MaterialPageRoute(builder: (_) => const AddDoneBookPage());

      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 4));

      case AppRoutes.bookNotes:
        final bookId = settings.arguments;
        if (bookId is int) {
          return MaterialPageRoute(
            builder: (_) => BookNotesPage(bookId: bookId),
          );
        }
        return MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 1));

      default:
        // 未知路由 → 回到首页
        return MaterialPageRoute(
          builder: (_) => const MainShell(initialIndex: 0),
        );
    }
  }
}
