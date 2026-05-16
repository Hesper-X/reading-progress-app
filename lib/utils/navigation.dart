import 'package:flutter/material.dart';

/// 导航封装工具类

class Navigation {
  Navigation._();

  static void push(BuildContext context, String route, {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  static void pushReplacement(BuildContext context, String route,
      {Object? arguments}) {
    Navigator.pushReplacementNamed(context, route, arguments: arguments);
  }

  static void pushAndRemoveUntil(BuildContext context, String route,
      {Object? arguments}) {
    Navigator.pushNamedAndRemoveUntil(
        context, route, (route) => false,
        arguments: arguments);
  }

  static void pop(BuildContext context, [Object? result]) {
    Navigator.pop(context, result);
  }
}
