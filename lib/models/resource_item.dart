enum ResourceType { folder, file }

class ResourceItem {
  final String id;
  final String name;
  final ResourceType type;
  final String? parentId; // null = root
  final String? filePath;
  final int? size; // bytes

  const ResourceItem({
    required this.id,
    required this.name,
    this.type = ResourceType.file,
    this.parentId,
    this.filePath,
    this.size,
  });

  bool get isFolder => type == ResourceType.folder;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'parentId': parentId,
    'filePath': filePath,
    'size': size,
  };

  factory ResourceItem.fromJson(Map<String, dynamic> json) => ResourceItem(
    id: json['id'] as String,
    name: json['name'] as String,
    type: ResourceType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => ResourceType.file,
    ),
    parentId: json['parentId'] as String?,
    filePath: json['filePath'] as String?,
    size: json['size'] as int?,
  );

  ResourceItem copyWith({
    String? id,
    String? name,
    ResourceType? type,
    String? parentId,
    String? filePath,
    int? size,
    bool clearParentId = false,
    bool clearFilePath = false,
    bool clearSize = false,
  }) => ResourceItem(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    parentId: clearParentId ? null : (parentId ?? this.parentId),
    filePath: clearFilePath ? null : (filePath ?? this.filePath),
    size: clearSize ? null : (size ?? this.size),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ResourceItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class LibraryCategory {
  final int id;
  final String name;
  final String slug;
  final String description;
  const LibraryCategory({
    required this.id,
    required this.name,
    this.slug = '',
    this.description = '',
  });
  factory LibraryCategory.fromJson(Map<String, dynamic> json) =>
      LibraryCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}

class LibraryResource {
  final int id;
  final int categoryId;
  final String title;
  final String description;
  final String coverUrl;
  final String fileUrl;
  final String externalUrl;
  final String fileType;
  final int fileSize;
  final int viewCount;
  final int downloadCount;
  final String tags;
  final LibraryCategory? category;
  const LibraryResource({
    required this.id,
    required this.categoryId,
    required this.title,
    this.description = '',
    this.coverUrl = '',
    this.fileUrl = '',
    this.externalUrl = '',
    this.fileType = '',
    this.fileSize = 0,
    this.viewCount = 0,
    this.downloadCount = 0,
    this.tags = '',
    this.category,
  });
  factory LibraryResource.fromJson(Map<String, dynamic> json) =>
      LibraryResource(
        id: (json['id'] as num).toInt(),
        categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        coverUrl: json['cover_url'] as String? ?? '',
        fileUrl: json['file_url'] as String? ?? '',
        externalUrl: json['external_url'] as String? ?? '',
        fileType: json['file_type'] as String? ?? '',
        fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
        viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
        downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
        tags: json['tags'] as String? ?? '',
        category: json['category'] is Map<String, dynamic>
            ? LibraryCategory.fromJson(json['category'] as Map<String, dynamic>)
            : null,
      );
}
