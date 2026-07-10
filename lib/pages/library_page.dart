import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/resource_item.dart';
import '../services/api_service.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<LibraryCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchLibraryCategories();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('资料库')),
    body: FutureBuilder<List<LibraryCategory>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Retry(
            message: '资料分类加载失败',
            onRetry: () => setState(() => _future = fetchLibraryCategories()),
          );
        }
        final categories = snapshot.data ?? [];
        if (categories.isEmpty) return const Center(child: Text('暂无资料分类'));
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              leading: const Icon(Icons.folder_outlined, color: Colors.amber),
              title: Text(category.name),
              subtitle: category.description.isEmpty
                  ? null
                  : Text(category.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResourceListPage(category: category),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class ResourceListPage extends StatefulWidget {
  final LibraryCategory category;
  const ResourceListPage({super.key, required this.category});
  @override
  State<ResourceListPage> createState() => _ResourceListPageState();
}

class _ResourceListPageState extends State<ResourceListPage> {
  final _search = TextEditingController();
  late Future<
    ({
      List<LibraryResource> items,
      int total,
      int page,
      int pageSize,
      int totalPages,
    })
  >
  _future;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = fetchLibraryResources(
    categoryId: widget.category.id,
    query: _search.text,
    page: _page,
  );
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.category.name)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => setState(() {
              _page = 1;
              _load();
            }),
            decoration: InputDecoration(
              hintText: '搜索资料',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  setState(() {
                    _page = 1;
                    _load();
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child:
              FutureBuilder<
                ({
                  List<LibraryResource> items,
                  int total,
                  int page,
                  int pageSize,
                  int totalPages,
                })
              >(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _Retry(
                      message: '资料加载失败',
                      onRetry: () => setState(_load),
                    );
                  }
                  final data = snapshot.data!;
                  if (data.items.isEmpty) {
                    return const Center(child: Text('暂无资料'));
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: data.items.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            final item = data.items[index];
                            return ListTile(
                              leading: Icon(
                                _iconFor(item.fileType),
                                color: Colors.grey[600],
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                '${_formatSize(item.fileSize)} · ${item.viewCount} 次浏览',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ResourceDetailPage(id: item.id),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      _Pager(
                        page: data.page,
                        totalPages: data.totalPages,
                        onChanged: (page) => setState(() {
                          _page = page;
                          _load();
                        }),
                      ),
                    ],
                  );
                },
              ),
        ),
      ],
    ),
  );
}

class ResourceDetailPage extends StatefulWidget {
  final int id;
  const ResourceDetailPage({super.key, required this.id});
  @override
  State<ResourceDetailPage> createState() => _ResourceDetailPageState();
}

class _ResourceDetailPageState extends State<ResourceDetailPage> {
  late Future<LibraryResource> _future;
  @override
  void initState() {
    super.initState();
    _future = fetchLibraryResource(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('资料详情')),
    body: FutureBuilder<LibraryResource>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Retry(
            message: '详情加载失败',
            onRetry: () =>
                setState(() => _future = fetchLibraryResource(widget.id)),
          );
        }
        final item = snapshot.data!;
        final target = item.fileUrl.isNotEmpty
            ? item.fileUrl
            : item.externalUrl;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (item.description.isNotEmpty) Text(item.description),
            const SizedBox(height: 12),
            Text('文件类型：${item.fileType.isEmpty ? '未知' : item.fileType}'),
            Text('文件大小：${_formatSize(item.fileSize)}'),
            Text('浏览：${item.viewCount} · 下载：${item.downloadCount}'),
            if (target.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开资料'),
                  onPressed: () async {
                    await recordLibraryDownload(item.id);
                    final uri = Uri.tryParse(target);
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _Pager extends StatelessWidget {
  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => totalPages <= 1
      ? const SizedBox(height: 12)
      : Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: page > 1 ? () => onChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$page / $totalPages'),
              IconButton(
                onPressed: page < totalPages ? () => onChanged(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        );
}

class _Retry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Retry({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

IconData _iconFor(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow;
    case 'doc':
    case 'docx':
      return Icons.description;
    default:
      return Icons.insert_drive_file;
  }
}

String _formatSize(int bytes) {
  if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(1)} MB';
  if (bytes >= 1000) return '${(bytes / 1000).toStringAsFixed(0)} KB';
  return '$bytes B';
}
