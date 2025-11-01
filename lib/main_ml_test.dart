import 'package:flutter/material.dart';
import 'ml_test_page.dart';

void main() {
  runApp(const MLTestApp());
}

class MLTestApp extends StatelessWidget {
  const MLTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ML Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepOrange, useMaterial3: true),
      home: const MLTestPage(),
    );
  }
}
