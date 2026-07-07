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
  }) =>
      ResourceItem(
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
