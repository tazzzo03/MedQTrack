class AlertDto {
  final int id;
  final String title;
  final String? body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  AlertDto({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AlertDto.fromJson(Map<String, dynamic> j) {
    // API uses notification_id as PK
    final dynamic idVal = j['notification_id'] ?? j['id'];
    return AlertDto(
      id: idVal is String ? int.tryParse(idVal) ?? 0 : (idVal ?? 0) as int,
      title: (j['title'] ?? '').toString(),
      body: j['body']?.toString(),
      type: (j['type'] ?? 'system').toString(),
      isRead: j['is_read'] == true || j['is_read'] == 1 || j['is_read'] == '1',
      createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

