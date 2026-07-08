import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';
import '../widgets/toast.dart';

class DormitoryPage extends ConsumerWidget {
  const DormitoryPage({super.key});

  void _showElectricityLogin(BuildContext context, WidgetRef ref) {
    final userCtrl = TextEditingController(text: ref.read(authProvider).username ?? '');
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登录电费账号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: userCtrl, decoration: const InputDecoration(labelText: '电费账号', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: '电费密码', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final ok = await ref.read(authProvider.notifier).doElectricityLogin(userCtrl.text.trim(), passCtrl.text);
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

    Widget body;
    if (asyncData.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (asyncData.hasError) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('加载失败', style: TextStyle(fontSize: 16, color: cs.error)),
              const SizedBox(height: 4),
              Text('${asyncData.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.outline)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(electricityProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    } else {
      final data = asyncData.asData?.value;
      if (data == null) {
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.electrical_services_outlined, size: 48, color: cs.outline),
                const SizedBox(height: 12),
                if (!auth.isLoggedIn)
                  Text('请先在「更多」中登录教务系统', style: TextStyle(color: cs.outline))
                else if (auth.electricityToken == null) ...[
                  Text('电费未登录', style: TextStyle(color: cs.outline, fontSize: 16)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showElectricityLogin(context, ref),
                    icon: const Icon(Icons.login),
                    label: const Text('登录电费'),
                  ),
                ] else ...[
                  Text('没有绑定房间', style: TextStyle(color: cs.outline, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('请绑定房间后查看电费', style: TextStyle(fontSize: 12, color: cs.outline)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _bindRoom(context, ref),
                    icon: const Icon(Icons.add_home, size: 16),
                    label: const Text('绑定房间'),
                  ),
                ],
              ],
            ),
          ),
        );
      } else {
        body = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (data.roomName != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(data.roomName!.replaceAll('->', ' · '),
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => _unbindRoom(context, ref),
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('解绑房间', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _bindRoom(context, ref),
                  icon: const Icon(Icons.add_home, size: 16),
                  label: const Text('绑定房间'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // 空调 / 照明并列
            Row(children: [
              Expanded(child: _balanceCard('空调', data.acBalance, Icons.ac_unit, cs)),
              const SizedBox(width: 12),
              Expanded(child: _balanceCard('照明', data.lightBalance, Icons.lightbulb_outline, cs)),
            ]),
            // 月度对比
            if (data.lastMonthUsage != null && data.currentMonthUsage != null) ...[
              const SizedBox(height: 20),
              Text('月度用电对比', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _statCard('上月', '${data.lastMonthUsage!.toStringAsFixed(1)} 度', Icons.calendar_today, cs)),
                const SizedBox(width: 10),
                Expanded(child: _statCard('本月', '${data.currentMonthUsage!.toStringAsFixed(1)} 度', Icons.calendar_month, cs)),
                if (data.usageChange != null) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('变化', '${data.usageChange! >= 0 ? "+" : ""}${data.usageChange!.toStringAsFixed(1)} 度', Icons.swap_vert, cs)),
                ],
              ]),
            ],
            // 用电日历
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _showConsumeCalendar(context, ref),
              icon: const Icon(Icons.calendar_month, size: 16),
              label: const Text('查看本月用电日历'),
            ),
            // 充值记录
            if (data.recharges.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('充值记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              ...data.recharges.take(5).map((r) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_circle, color: Colors.green, size: 20),
                    title: Text('¥${r.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(r.time, style: const TextStyle(fontSize: 11)),
                    trailing: r.label.isNotEmpty ? Text(r.label, style: TextStyle(fontSize: 11, color: cs.outline)) : null,
                  )),
            ],
            // 扣费记录
            if (data.deductions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('扣费记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              ...data.deductions.take(5).map((r) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                    title: Text('¥${r.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(r.time, style: const TextStyle(fontSize: 11)),
                    trailing: r.label.isNotEmpty ? Text(r.label, style: TextStyle(fontSize: 11, color: cs.outline)) : null,
                  )),
            ],
          ],
        );
      }
    }

    return Scaffold(appBar: AppBar(title: const Text('宿舍电费')), body: body);
  }

  Future<void> _bindRoom(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    final token = auth.electricityToken;
    if (token == null || auth.username == null) return;

    try {
    // Step 1: 选楼栋
    final buildingsR = await fetchBuildings(token);
    if (!buildingsR.isOk || buildingsR.data == null) return;
    final buildings = (buildingsR.data as List).cast<Map<String, dynamic>>();
    if (!context.mounted) return;

    final building = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择楼栋'),
        children: buildings
            .map((b) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, b),
                  child: Text(b['name'] as String? ?? ''),
                ))
            .toList(),
      ),
    );
    if (building == null || !context.mounted) return;
    final buildingCode = building['code'] as String? ?? '';

    // Step 2: 选楼层
    final floorsR = await fetchFloors(token, buildingCode);
    if (!floorsR.isOk || floorsR.data == null) return;
    final floors = (floorsR.data as List).cast<Map<String, dynamic>>();
    if (!context.mounted) return;

    final floor = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择楼层'),
        children: floors
            .map((f) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, f),
                  child: Text(f['name'] as String? ?? ''),
                ))
            .toList(),
      ),
    );
    if (floor == null || !context.mounted) return;
    final floorCode = floor['code'] as String? ?? '';

    // Step 3: 选房间
    final roomsR = await searchRooms(token, floorCode, auth.username!);
    if (!roomsR.isOk || roomsR.data == null) return;
    final rooms = (roomsR.data as List).cast<Map<String, dynamic>>();
    if (!context.mounted) return;

    final room = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择房间'),
        children: rooms
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Text(r['name'] as String? ?? ''),
                ))
            .toList(),
      ),
    );
    if (room == null || !context.mounted) return;
    final roomCode = room['code'] as String? ?? '';

    // Step 4: 绑定
    final bindR = await bindRooms(token, auth.username!, [roomCode]);
    if (bindR.isOk && context.mounted) {
      Toast.success(context, '绑定成功');
      ref.invalidate(electricityProvider);
    }
    } catch (e) {
      if (context.mounted) {
        Toast.error(context, '操作失败: $e');
      }
    }
  }

  Future<void> _unbindRoom(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    final token = auth.electricityToken;
    if (token == null || auth.username == null) return;

    try {
    // 查询已绑定房间
    final boundR = await fetchBoundRooms(token, auth.username!);
    if (!boundR.isOk || boundR.data == null) return;
    final raw = boundR.data;
    List<Map<String, dynamic>> bound;
    if (raw is List) {
      bound = raw.cast<Map<String, dynamic>>();
    } else if (raw is Map) {
      bound = ((raw['records'] ?? raw['list'] ?? raw['data'] ?? raw['items']) as List?)?.cast<Map<String, dynamic>>() ?? [];
    } else {
      bound = [];
    }
    if (!context.mounted) return;

    if (bound.isEmpty) {
      Toast.info(context, '暂无已绑定房间');
      return;
    }

    final room = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('解绑房间'),
        children: bound
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Text(r['roomName'] as String? ?? r['areaInfo'] as String? ?? r['roomCode'] as String? ?? ''),
                ))
            .toList(),
      ),
    );
    if (room == null || !context.mounted) return;
    final roomCode = room['roomCode'] as String? ?? '';

    final unbindR = await unbindRooms(token, auth.username!, [roomCode]);
    if (unbindR.isOk && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('解绑成功')));
      ref.invalidate(electricityProvider);
    }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _showConsumeCalendar(
      BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    final token = auth.electricityToken;
    if (token == null || auth.username == null) return;

    // 拿 roomCode
    String? roomCode;
    try {
      final roomsR = await fetchElectricityRooms(token);
      if (roomsR.isOk && roomsR.data != null) {
        final raw = roomsR.data;
        if (raw is List && raw.isNotEmpty) {
          roomCode = (raw[0] as Map<String, dynamic>)['roomCode'] as String?;
        }
      } else {
        if (context.mounted) Toast.error(context, '获取房间失败');
        return;
      }
    } catch (e) {
      if (context.mounted) Toast.error(context, '请求失败: $e');
      return;
    }
    if (roomCode == null) {
      if (context.mounted) Toast.info(context, '未绑定房间，请先绑定');
      return;
    }

    // 请求本月数据
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final end = '${now.year}-${now.month.toString().padLeft(2, '0')}-$lastDay';

    List<Map<String, dynamic>> days = [];
    try {
      final cr = await fetchElectricityConsume(token, roomCode, start, end);
      if (cr.isOk && cr.data != null) {
        // Try various possible keys
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

    // 建 day→value 映射
    final dayMap = <int, double>{};
    for (final d in days) {
      // date 格式 "2026-07-01" → 提取日
      final dateStr = d['date'] as String? ?? '';
      final dayInt = int.tryParse(dateStr.split('-').last) ?? 0;
      final raw = d['useElectric'];
      final double val = raw is num ? raw.toDouble() : 0.0;
      if (dayInt > 0) dayMap[dayInt] = val;
    }

    if (!context.mounted) return;
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text('${now.year}年${now.month}月用电日历',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            // 星期头
            Row(
              children: ['一', '二', '三', '四', '五', '六', '日']
                  .map((s) => Expanded(
                        child: Text(s,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: cs.outline)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            // 日期格子
            _buildMonthGrid(now.year, now.month, dayMap, cs),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            // 详情统计
            _buildDetailSummary(dayMap, cs),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: cs.primary.withAlpha(80),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('用电量越深越多', style: TextStyle(fontSize: 11, color: cs.outline)),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(int year, int month,
      Map<int, double> dayMap, ColorScheme cs) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startOffset = firstDay.weekday - 1; // Monday = 0
    final totalDays = lastDay.day;
    final maxVal = dayMap.isEmpty ? 1.0 : dayMap.values.reduce((a, b) => a > b ? a : b);

    final cells = <Widget>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= totalDays; d++) {
      final val = dayMap[d] ?? 0;
      final alpha = maxVal > 0 ? (val / maxVal * 200).clamp(0, 200).toInt() + 30 : 30;
      cells.add(
        Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: val > 0
                ? cs.primary.withAlpha(alpha)
                : Colors.grey.withAlpha(20),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$d', style: TextStyle(fontSize: 11, fontWeight: val > 0 ? FontWeight.w600 : FontWeight.normal, color: val > 0 ? cs.onPrimary : cs.outline)),
            if (val > 0) Text(val.toStringAsFixed(1), style: TextStyle(fontSize: 7, color: val > maxVal * 0.5 ? cs.onPrimary : cs.outline)),
          ]),
        ),
      );
    }
    // Pad to full rows
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return Column(
      children: List.generate(cells.length ~/ 7, (row) {
        return Row(
          children: List.generate(7, (col) {
            return Expanded(child: SizedBox(height: 40, child: cells[row * 7 + col]));
          }),
        );
      }),
    );
  }

  Widget _buildDetailSummary(Map<int, double> dayMap, ColorScheme cs) {
    if (dayMap.isEmpty) return const SizedBox.shrink();
    final values = dayMap.values.where((v) => v > 0).toList();
    if (values.isEmpty) return const SizedBox.shrink();
    final total = values.fold(0.0, (a, b) => a + b);
    final avg = total / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final maxDay = dayMap.entries.firstWhere((e) => e.value == max).key;
    final minDay = dayMap.entries.firstWhere((e) => e.value == min).key;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text('用电详情', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _detailItem('本月总计', '${total.toStringAsFixed(1)} 度', cs),
          _detailItem('日均', '${avg.toStringAsFixed(1)} 度', cs),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _detailItem('最高', '${max.toStringAsFixed(1)} 度\n$maxDay日', cs),
          _detailItem('最低', '${min.toStringAsFixed(1)} 度\n$minDay日', cs),
        ]),
      ]),
    );
  }

  Widget _detailItem(String label, String value, ColorScheme cs) => Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
          Text(value, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
        ],
      );

  Widget _balanceCard(String label, double amount, IconData icon, ColorScheme cs) {
    final color = amount >= 50 ? Colors.green : (amount >= 20 ? Colors.orange : cs.error);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: cs.outline)),
          const SizedBox(height: 4),
          Text('¥${amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
        ]),
      );
}
