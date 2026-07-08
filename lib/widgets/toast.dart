import 'package:flutter/material.dart';

enum ToastType { success, error, info }

// ── 规范化 Toast 消息 ──
class Toast {
  static void show(BuildContext context, String message,
      {ToastType type = ToastType.info,
      Duration duration = const Duration(seconds: 2)}) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, IconData icon) = switch (type) {
      ToastType.success => (Colors.green.shade700, Icons.check_circle),
      ToastType.error => (cs.error, Icons.error),
      ToastType.info => (cs.primary, Icons.info),
    };

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 14))),
        ]),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: duration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ── 快捷方法 ──
  static void success(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.success);

  static void error(BuildContext context, String msg) =>
      show(context, msg,
          type: ToastType.error, duration: const Duration(seconds: 3));

  static void info(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.info);

  // ── 预定义消息 ──
  static void sessionExpired(BuildContext context) =>
      error(context, '会话已过期，正在尝试重新登录…');

  static void reLoginSuccess(BuildContext context) =>
      success(context, '已恢复登录');

  static void reLoginFailed(BuildContext context) =>
      error(context, '自动登录失败，请手动重新登录');

  static void networkError(BuildContext context) =>
      error(context, '网络连接失败，请检查网络后重试');

  static void serverError(BuildContext context) =>
      error(context, '服务器繁忙，请稍后重试');

  static void operationSuccess(BuildContext context, [String? action]) =>
      success(context, action != null ? '$action成功' : '操作成功');

  static void operationFailed(BuildContext context, String reason) =>
      error(context, '操作失败：$reason');

  static void dataRefreshed(BuildContext context) =>
      success(context, '数据已刷新');

  static void cacheCleared(BuildContext context) =>
      success(context, '缓存已清除，正在重新加载');

  static void noData(BuildContext context, [String? label]) =>
      info(context, label != null ? '暂无$label' : '暂无数据');

  static void noNetwork(BuildContext context) =>
      error(context, '无法连接服务器，请检查网络或服务器地址');

  static void loginExpired(BuildContext context) =>
      error(context, '登录已过期，请重新登录');
}
