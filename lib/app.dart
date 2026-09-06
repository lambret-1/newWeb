import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/browser/browser_screen.dart';

/// 未来浏览器 — 应用根组件（全中文界面）。
class NewWebApp extends StatelessWidget {
  const NewWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '未来浏览器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      ),
      // 100% 汉化：系统组件（对话框按钮、文本选择菜单等）使用中文本地化
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      locale: const Locale('zh'),
      home: const BrowserScreen(),
    );
  }
}
