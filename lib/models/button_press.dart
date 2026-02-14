class ButtonPress {
  final String id;
  final String buttonId;
  final DateTime pressedAt;

  ButtonPress({
    required this.id,
    required this.buttonId,
    required this.pressedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buttonId': buttonId,
      'pressedAt': pressedAt.toIso8601String(),
    };
  }

  factory ButtonPress.fromMap(Map<String, dynamic> map) {
    return ButtonPress(
      id: map['id'] as String,
      buttonId: map['buttonId'] as String,
      pressedAt: DateTime.parse(map['pressedAt'] as String),
    );
  }
}
