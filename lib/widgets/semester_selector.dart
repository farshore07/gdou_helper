import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/semester_provider.dart';

class SemesterSelector extends ConsumerWidget {
  const SemesterSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(semesterProvider);

    return PopupMenuButton<String>(
      initialValue: current,
      tooltip: '切换学期',
      icon: const Icon(Icons.filter_list),
      onSelected: (v) => ref.read(semesterProvider.notifier).select(v),
      itemBuilder: (_) => allSemesters
          .map((s) => PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    if (s == current)
                      const Icon(Icons.check, size: 16, color: Colors.blue)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(semesterLabel(s)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
