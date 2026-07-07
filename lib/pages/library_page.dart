import 'package:flutter/material.dart';

import '../models/resource_item.dart';

final _folders = [
  const ResourceItem(id: 'f1', name: '课件', type: ResourceType.folder),
  const ResourceItem(id: 'f2', name: '历年试卷', type: ResourceType.folder),
  const ResourceItem(id: 'f3', name: '教材电子版', type: ResourceType.folder),
  const ResourceItem(id: 'f4', name: '实验报告', type: ResourceType.folder),
];

final _files = {
  'f1': [
    const ResourceItem(id: 'c1', name: '高等数学-ch01-函数与极限.pdf', type: ResourceType.file, size: 2400000),
    const ResourceItem(id: 'c2', name: '数据结构-树与图.pptx', type: ResourceType.file, size: 5800000),
    const ResourceItem(id: 'c3', name: '操作系统-进程管理.pdf', type: ResourceType.file, size: 3100000),
  ],
  'f2': [
    const ResourceItem(id: 'e1', name: '20-21-1 高数期末 A卷.pdf', type: ResourceType.file, size: 1200000),
    const ResourceItem(id: 'e2', name: '21-22-1 数据结构期末.pdf', type: ResourceType.file, size: 980000),
    const ResourceItem(id: 'e3', name: '22-23-2 操作系统期中.pdf', type: ResourceType.file, size: 1500000),
  ],
  'f3': [
    const ResourceItem(id: 'b1', name: '计算机网络-谢希仁.pdf', type: ResourceType.file, size: 45000000),
    const ResourceItem(id: 'b2', name: '数据库系统概论.pdf', type: ResourceType.file, size: 32000000),
  ],
  'f4': [
    const ResourceItem(id: 'l1', name: '操作系统实验1-进程调度.docx', type: ResourceType.file, size: 350000),
    const ResourceItem(id: 'l2', name: '数据结构实验2-二叉树.docx', type: ResourceType.file, size: 280000),
  ],
};

final _iconFor = {
  '.pdf': Icons.picture_as_pdf,
  '.pptx': Icons.slideshow,
  '.docx': Icons.description,
};

IconData _fileIcon(String name) {
  for (final ext in _iconFor.keys) {
    if (name.endsWith(ext)) return _iconFor[ext]!;
  }
  return Icons.insert_drive_file;
}

String _formatSize(int bytes) {
  if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(1)} MB';
  if (bytes >= 1000) return '${(bytes / 1000).toStringAsFixed(0)} KB';
  return '$bytes B';
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资料库')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _folders.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) {
          final folder = _folders[index];
          final count = _files[folder.id]?.length ?? 0;
          return ListTile(
            leading: const Icon(Icons.folder_outlined, color: Colors.amber),
            title: Text(folder.name),
            subtitle: Text('$count 个文件', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FileListPage(
                  title: folder.name,
                  files: _files[folder.id] ?? [],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FileListPage extends StatelessWidget {
  final String title;
  final List<ResourceItem> files;

  const _FileListPage({required this.title, required this.files});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: files.isEmpty
          ? const Center(child: Text('暂无文件'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: files.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) {
                final f = files[i];
                return ListTile(
                  leading: Icon(_fileIcon(f.name), color: Colors.grey[600]),
                  title: Text(f.name, style: const TextStyle(fontSize: 14)),
                  trailing: Text(_formatSize(f.size ?? 0),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                );
              },
            ),
    );
  }
}
