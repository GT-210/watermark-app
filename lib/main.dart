import 'package:flutter/material.dart';
import 'pages.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WatermarkApp());
}

/// App 根组件：只负责全局主题与首页挂载。
class WatermarkApp extends StatelessWidget {
  const WatermarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '图片水印大师',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
