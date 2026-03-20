/*
 * @Author: fukaidong qiji777@yeah.net
 * @Date: 2026-03-11 09:45:42
 * @LastEditors: fukaidong qiji777@yeah.net
 * @LastEditTime: 2026-03-11 09:45:47
 * @Description: .
 */

import 'package:flutter/foundation.dart';

/**
 * 日志工具类
 * 用于统一管理应用日志输出，区分不同级别的日志
 */
class Logger {
  /**
   * 输出错误日志
   * @param message 错误信息
   * @param error 错误对象（可选）
   * @param stackTrace 堆栈信息（可选）
   */
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      consoleLog('❌ [ERROR] $message');
      if (error != null) consoleLog('Error: $error');
      if (stackTrace != null) consoleLog('StackTrace: $stackTrace');
    } else {
      // 生产环境可以对接日志上报系统
      // 避免打印敏感堆栈信息，仅输出关键错误
      print('❌ [ERROR] $message');
    }
  }

  /**
   * 输出警告日志
   * @param message 警告信息
   */
  static void warn(String message) {
    if (kDebugMode) {
      consoleLog('⚠️ [WARN] $message');
    }
  }

  /**
   * 输出普通信息日志
   * @param message 日志信息
   */
  static void info(String message) {
    if (kDebugMode) {
      consoleLog('ℹ️ [INFO] $message');
    }
  }

  /**
   * 内部使用的控制台输出方法
   * @param message 输出内容
   */
  static void consoleLog(String message) {
    // 使用 debugPrint 可以避免长日志被截断
    debugPrint(message);
  }
}
