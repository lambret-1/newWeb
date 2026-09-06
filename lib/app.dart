import 'package:flutter/material.dart';

import 'features/browser/browser_screen.dart';

/// NewWeb 应用根组件。
class NewWebApp extends StatelessWidget {
  const NewWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewWeb',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      ),
      home: const BrowserScreen(),
    );
  }
}
