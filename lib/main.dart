import 'package:flutter/material.dart';

import 'design/theme.dart';

void main() => runApp(const _FoundationApp());

class _FoundationApp extends StatelessWidget {
  const _FoundationApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Budget',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Scaffold(body: Center(child: Text('Student Budget', style: AppText.title))),
    );
  }
}
