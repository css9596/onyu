class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.lastMessageAt,
    required this.createdAt,
  });

  final String id;
  final String? title;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String?,
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
