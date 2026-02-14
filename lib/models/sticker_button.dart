class StickerButton {
  final String id;
  final String name;
  final String imagePath;
  final DateTime createdAt;
  final double size;
  final double posX;
  final double posY;

  StickerButton({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.createdAt,
    this.size = 100.0,
    this.posX = -1,
    this.posY = -1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'size': size,
      'posX': posX,
      'posY': posY,
    };
  }

  factory StickerButton.fromMap(Map<String, dynamic> map) {
    return StickerButton(
      id: map['id'] as String,
      name: map['name'] as String,
      imagePath: map['imagePath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      size: (map['size'] as num?)?.toDouble() ?? 100.0,
      posX: (map['posX'] as num?)?.toDouble() ?? -1,
      posY: (map['posY'] as num?)?.toDouble() ?? -1,
    );
  }

  StickerButton copyWith({
    String? id,
    String? name,
    String? imagePath,
    DateTime? createdAt,
    double? size,
    double? posX,
    double? posY,
  }) {
    return StickerButton(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      size: size ?? this.size,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
    );
  }
}
