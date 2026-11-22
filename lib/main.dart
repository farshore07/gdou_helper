import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 不阻断首屏绘制；initNotifications 内部具备失败捕获与图标回退
  unawaited(initNotifications());
  runApp(const ProviderScope(child: App()));
}
