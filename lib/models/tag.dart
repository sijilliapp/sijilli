import 'dart:ui';

class Tag {
  final String id;
  final String name;
  final String colorHex;
  final String userId;

  const Tag({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.userId,
  });

  /// Parse hex color safely. Expects colorHex to be a 6-character hex string (e.g. "4F46E5").
  Color get color {
    final hexCode = colorHex.replaceAll('#', '').trim();
    if (hexCode.length == 6) {
      return Color(int.parse('FF$hexCode', radix: 16));
    } else if (hexCode.length == 8) {
      return Color(int.parse(hexCode, radix: 16));
    }
    return const Color(0xFF6B7280); // Default gray
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      colorHex: json['color'] ?? '6B7280',
      userId: json['user'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': colorHex,
      'user': userId,
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    String? colorHex,
    String? userId,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      userId: userId ?? this.userId,
    );
  }
}
