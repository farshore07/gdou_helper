import 'package:flutter/material.dart';

enum ToastType { success, error, info }

class Toast {
  static void show(BuildContext context, String message,
      {ToastType type = ToastType.info, Duration duration = const Duration(seconds: 2)}) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, IconData icon) = switch (type) {
      ToastType.success => (Colors.green.shade700, Icons.check_circle),
      ToastType.error => (cs.error, Icons.error),
      ToastType.info => (cs.primary, Icons.info),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ]),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: duration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  static void success(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.success);

  static void error(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.error, duration: const Duration(seconds: 3));

  static void info(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.info);
}
