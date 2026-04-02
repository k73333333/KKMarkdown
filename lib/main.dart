/*
 * @Author: fukaidong qiji777@yeah.net
 * @Date: 2026-03-11 09:44:26
 * @LastEditors: fukaidong qiji777@yeah.net
 * @LastEditTime: 2026-03-11 09:48:16
 * @Description: .
 */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/app_provider.dart';
import 'pages/home_page.dart';
import 'utils/logger.dart';

/**
 * 应用程序入口
 */
void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器 (仅桌面端)
  try {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // 隐藏系统标题栏，但保留系统的窗口控制按钮（最小化、最大化、关闭）
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      // 防止因为隐藏标题栏导致窗口默认太小或没有最大化按钮
      await windowManager.setPreventClose(false);
    });
  } catch (e) {
    Logger.warn('窗口管理器初始化失败 (非桌面环境可忽略): $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
      ],
      child: const KKMarkdownApp(),
    ),
  );
}

/**
 * 应用根组件
 */
class KKMarkdownApp extends StatelessWidget {
  const KKMarkdownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        return MaterialApp(
          title: 'KKMarkdown',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: appProvider.themeColor),
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: appProvider.themeColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: appProvider.themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
