import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';
import '../widgets/toast.dart';

class DormitoryPage extends ConsumerWidget {
  const DormitoryPage({super.key});

  void _showElectricityLogin(BuildContext context, WidgetRef ref) {
    final userCtrl = TextEditingController(
      text: ref.read(authProvider).username ?? '',
    );
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登录电费账号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: '电费账号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '电费密码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await ref
                  .read(authProvider.notifier)
                  .doElectricityLogin(userCtrl.text.trim(), passCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (ok) ref.invalidate(electricityProvider);
            },
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final asyncData = ref.watch(electricityProvider);

    final body = asyncData.when(
      loading: () => Center(child: _loading(cs)),
      error: (error, _) => _errorState(context, ref, error, cs),
      data: (data) => data == null
          ? _emptyState(
              context,
              ref,
              auth.isLoggedIn,
              auth.electricityToken != null,
              cs,
            )
          : _dataView(context, ref, data, cs),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('宿舍电费'),
        automaticallyImplyLeading: false,
      ),
      body: body,
    );
  }

  Widget _loading(ColorScheme cs) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: cs.primaryContainer.withAlpha(60),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(
      child: CircularProgressIndicator(color: cs.primary, strokeWidth: 3),
    ),
  );

  Widget _errorState(
    BuildContext context,
    WidgetRef ref,
    Object error,
    ColorScheme cs,
  ) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text('加载失败', style: TextStyle(fontSize: 16, color: cs.error)),
          const SizedBox(height: 4),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(electricityProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );

  Widget _emptyState(
    BuildContext context,
    WidgetRef ref,
    bool jwxtLoggedIn,
    bool electricityLoggedIn,
    ColorScheme cs,
  ) {
    final title = !jwxtLoggedIn
        ? '未登录'
        : !electricityLoggedIn
        ? '电费未登录'
        : '未绑定房间';
    final subtitle = !jwxtLoggedIn
        ? '请先在「更多」中登录教务系统'
        : !electricityLoggedIn
        ? '登录后查看宿舍电费余额'
        : '绑定宿舍房间后查看电费';
    final action = !jwxtLoggedIn
        ? null
        : !electricityLoggedIn
        ? () => _showElectricityLogin(context, ref)
        : () => _bindRoom(context, ref);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 80, 24, 0),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withAlpha(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.electrical_services_outlined,
                size: 36,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: action,
                  icon: Icon(
                    electricityLoggedIn ? Icons.add_home_outlined : Icons.login,
                  ),
                  label: Text(electricityLoggedIn ? '绑定房间' : '登录电费'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dataView(
    BuildContext context,
    WidgetRef ref,
    ElectricityData data,
    ColorScheme cs,
  ) => ListView(
    padding: const EdgeInsets.only(bottom: 32),
    children: [
      _roomCard(context, ref, data.roomName, cs),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _balanceCard('空调', data.acBalance, Icons.ac_unit, cs),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _balanceCard(
                '照明',
                data.lightBalance,
                Icons.lightbulb_outline,
                cs,
              ),
            ),
          ],
        ),
      ),
      if (data.lastMonthUsage != null && data.currentMonthUsage != null) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '月度用电对比',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _statCard(
                  '上月',
                  '${data.lastMonthUsage!.toStringAsFixed(1)} 度',
                  Icons.calendar_today,
                  cs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  '本月',
                  '${data.currentMonthUsage!.toStringAsFixed(1)} 度',
                  Icons.calendar_month,
                  cs,
                ),
              ),
              if (data.usageChange != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard(
                    '变化',
                    '${data.usageChange! >= 0 ? '+' : ''}${data.usageChange!.toStringAsFixed(1)} 度',
                    data.usageChange! >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    cs,
                    change: data.usageChange,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      _calendarEntry(context, ref, cs),
      if (data.recharges.isNotEmpty)
        _recordCard(context, '充值记录', data.recharges.take(3).toList(), true, cs),
      if (data.deductions.isNotEmpty)
        _recordCard(
          context,
          '扣费记录',
          data.deductions.take(3).toList(),
          false,
          cs,
        ),
    ],
  );

  Widget _roomCard(
    BuildContext context,
    WidgetRef ref,
    String? roomName,
    ColorScheme cs,
  ) {
    final bound = roomName != null;
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primaryContainer, cs.surface]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              bound ? Icons.home_outlined : Icons.add_home_outlined,
              size: 22,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bound ? roomName.replaceAll('->', ' · ') : '点击绑定房间',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bound ? '宿舍房间' : '绑定后查看电费余额',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (bound)
            TextButton.icon(
              onPressed: () => _unbindRoom(context, ref),
              icon: Icon(Icons.link_off, size: 16, color: cs.error),
              label: Text(
                '解绑',
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            )
          else
            Icon(Icons.chevron_right, color: cs.outline),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: bound
          ? card
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _bindRoom(context, ref),
                child: card,
              ),
            ),
    );
  }

  Widget _balanceCard(
    String label,
    double amount,
    IconData icon,
    ColorScheme cs,
  ) {
    final color = amount >= 50
        ? cs.primary
        : amount >= 20
        ? cs.tertiary
        : cs.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '¥${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (amount < 20) ...[
                const SizedBox(width: 4),
                Icon(Icons.warning_amber_rounded, size: 14, color: cs.error),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (amount / 100).clamp(0, 1),
              minHeight: 3,
              color: color,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    ColorScheme cs, {
    double? change,
  }) {
    final valueColor = change == null
        ? cs.onSurface
        : change >= 0
        ? cs.error
        : cs.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: valueColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _calendarEntry(BuildContext context, WidgetRef ref, ColorScheme cs) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashColor: cs.primaryContainer.withAlpha(60),
            onTap: () => _showConsumeCalendar(context, ref),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(60),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, size: 24, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本月用电日历',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '查看每日用电详情',
                          style: TextStyle(fontSize: 11, color: cs.outline),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.outline),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _recordCard(
    BuildContext context,
    String title,
    List<ElecRecord> records,
    bool recharge,
    ColorScheme cs,
  ) {
    final color = recharge ? cs.primary : cs.error;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withAlpha(40)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                recharge ? Icons.add_circle : Icons.remove_circle,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '共 ${records.length} 条',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          for (final record in records) _recordRow(record, recharge, cs),
          TextButton(
            onPressed: () => Toast.info(context, '更多记录功能开发中'),
            child: const Text('查看全部'),
          ),
        ],
      ),
    );
  }

  Widget _recordRow(ElecRecord record, bool recharge, ColorScheme cs) {
    final color = recharge ? cs.primary : cs.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              recharge ? Icons.add : Icons.remove,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recharge ? '+' : '-'}¥${record.amount.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
                Text(
                  record.time,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (record.label.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                record.label,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _selectOption(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> options, {
    String? displayKey,
  }) => showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, index) {
                  final option = options[index];
                  final name =
                      option[displayKey ?? 'name'] as String? ??
                      option['name'] as String? ??
                      option['roomName'] as String? ??
                      option['areaInfo'] as String? ??
                      option['roomCode'] as String? ??
                      '';
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: cs.primaryContainer,
                      onTap: () => Navigator.pop(sheetContext, option),
                      child: SizedBox(
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              name,
                              style: TextStyle(color: cs.onSurface),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _bindRoom(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    final token = auth.electricityToken;
    if (token == null || auth.username == null) return;
    try {
      final buildingsR = await fetchBuildings(token);
      if (!buildingsR.isOk || buildingsR.data == null) return;
      if (!context.mounted) return;
      final building = await _selectOption(
        context,
        '选择楼栋',
        (buildingsR.data as List).cast<Map<String, dynamic>>(),
      );
      if (building == null || !context.mounted) return;
      final floorsR = await fetchFloors(
        token,
        building['code'] as String? ?? '',
      );
      if (!floorsR.isOk || floorsR.data == null) return;
      if (!context.mounted) return;
      final floor = await _selectOption(
        context,
        '选择楼层',
        (floorsR.data as List).cast<Map<String, dynamic>>(),
      );
      if (floor == null || !context.mounted) return;
      final roomsR = await searchRooms(
        token,
        floor['code'] as String? ?? '',
        auth.username!,
      );
      if (!roomsR.isOk || roomsR.data == null) return;
      if (!context.mounted) return;
      final room = await _selectOption(
        context,
        '选择房间',
        (roomsR.data as List).cast<Map<String, dynamic>>(),
      );
      if (room == null || !context.mounted) return;
      final bindR = await bindRooms(token, auth.username!, [
        room['code'] as String? ?? '',
      ]);
      if (bindR.isOk && context.mounted) {
        Toast.operationSuccess(context, '绑定');
        ref.invalidate(electricityProvider);
      }
    } catch (e) {
      if (context.mounted) Toast.operationFailed(context, '$e');
    }
  }

  Future<void> _unbindRoom(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    final token = auth.electricityToken;
    if (token == null || auth.username == null) return;
    try {
      final boundR = await fetchBoundRooms(token, auth.username!);
      if (!boundR.isOk || boundR.data == null) return;
      final raw = boundR.data;
      final bound = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : raw is Map
          ? ((raw['records'] ?? raw['list'] ?? raw['data'] ?? raw['items'])
                        as List?)
                    ?.cast<Map<String, dynamic>>() ??
                []
          : <Map<String, dynamic>>[];
      if (!context.mounted) return;
      if (bound.isEmpty) {
        Toast.noData(context, '已绑定房间');
        return;
      }
      final room = await _selectOption(context, '解绑房间', bound);
      if (room == null || !context.mounted) return;
      final unbindR = await unbindRooms(token, auth.username!, [
        room['roomCode'] as String? ?? '',
      ]);
      if (unbindR.isOk && context.mounted) {
        Toast.operationSuccess(context, '解绑');
        ref.invalidate(electricityProvider);
      }
    } catch (e) {
      if (context.mounted) Toast.operationFailed(context, '$e');
    }
  }

  Future<void> _showConsumeCalendar(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    final token = auth.electricityToken;
    if (token == null || auth.username == null) return;
    String? roomCode;
    try {
      final roomsR = await fetchElectricityRooms(token);
      if (roomsR.isOk && roomsR.data != null) {
        final raw = roomsR.data;
        if (raw is List && raw.isNotEmpty) {
          roomCode = (raw[0] as Map<String, dynamic>)['roomCode'] as String?;
        }
      } else {
        if (context.mounted) Toast.serverError(context);
        return;
      }
    } catch (_) {
      if (context.mounted) Toast.networkError(context);
      return;
    }
    if (roomCode == null) {
      if (context.mounted) Toast.info(context, '请先绑定宿舍房间');
      return;
    }
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final end = '${now.year}-${now.month.toString().padLeft(2, '0')}-$lastDay';
    List<Map<String, dynamic>> days = [];
    try {
      final cr = await fetchElectricityConsume(token, roomCode, start, end);
      if (cr.isOk && cr.data != null) {
        var raw = cr.data!['useEleByDayList'];
        raw ??= cr.data!['list'];
        raw ??= cr.data!['records'];
        if (raw is List) days = raw.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      if (context.mounted) Toast.error(context, '获取日历失败: $e');
    }
    if (days.isEmpty && context.mounted) {
      Toast.info(context, '本月暂无用电数据');
      return;
    }
    if (!context.mounted) return;
    final dayMap = <int, double>{};
    for (final day in days) {
      final dayInt =
          int.tryParse((day['date'] as String? ?? '').split('-').last) ?? 0;
      final raw = day['useElectric'];
      if (dayInt > 0) dayMap[dayInt] = raw is num ? raw.toDouble() : 0;
    }
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${now.year}年${now.month}月用电日历',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: ['一', '二', '三', '四', '五', '六', '日']
                  .map(
                    (day) => Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: cs.outline),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            _buildMonthGrid(now.year, now.month, dayMap, cs),
            const SizedBox(height: 12),
            _buildDetailSummary(dayMap, cs),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cs.primary.withAlpha(120),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '用电量越深越多',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(
    int year,
    int month,
    Map<int, double> dayMap,
    ColorScheme cs,
  ) {
    final firstDay = DateTime(year, month, 1);
    final totalDays = DateTime(year, month + 1, 0).day;
    final maxVal = dayMap.isEmpty
        ? 1.0
        : dayMap.values.reduce((a, b) => a > b ? a : b);
    final today = DateTime.now();
    final cells = <Widget>[
      for (var i = 0; i < firstDay.weekday - 1; i++) const SizedBox(),
    ];
    for (var day = 1; day <= totalDays; day++) {
      final value = dayMap[day] ?? 0;
      final ratio = maxVal == 0 ? 0.0 : value / maxVal;
      final alpha = ratio <= .33
          ? 40
          : ratio <= .66
          ? 120
          : 255;
      final isToday =
          today.year == year && today.month == month && today.day == day;
      cells.add(
        Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: value > 0
                ? cs.primary.withAlpha(alpha)
                : cs.surfaceContainerHighest.withAlpha(30),
            borderRadius: BorderRadius.circular(6),
            border: isToday ? Border.all(color: cs.primary, width: 1.5) : null,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal,
                color: value > maxVal * .66 ? cs.onPrimary : cs.outline,
              ),
            ),
          ),
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }
    return Column(
      children: List.generate(
        cells.length ~/ 7,
        (row) => Row(
          children: List.generate(
            7,
            (column) => Expanded(
              child: SizedBox(height: 40, child: cells[row * 7 + column]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSummary(Map<int, double> dayMap, ColorScheme cs) {
    final values = dayMap.values.where((value) => value > 0).toList();
    if (values.isEmpty) return const SizedBox.shrink();
    final total = values.fold(0.0, (sum, value) => sum + value);
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final maxDay = dayMap.entries.firstWhere((entry) => entry.value == max).key;
    final minDay = dayMap.entries.firstWhere((entry) => entry.value == min).key;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '用电详情',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _detailItem('本月总计', '${total.toStringAsFixed(1)} 度', null, cs),
              _detailItem(
                '日均',
                '${(total / values.length).toStringAsFixed(1)} 度',
                null,
                cs,
              ),
              _detailItem('最高', '${max.toStringAsFixed(1)} 度', '$maxDay日', cs),
              _detailItem('最低', '${min.toStringAsFixed(1)} 度', '$minDay日', cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailItem(
    String label,
    String value,
    String? date,
    ColorScheme cs,
  ) => Column(
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      if (date != null)
        Text(
          '($date)',
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
    ],
  );
}
