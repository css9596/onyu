enum MessageRole { user, assistant }

class Message {
  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.tokensInput,
    this.tokensOutput,
  });

  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final int? tokensInput;
  final int? tokensOutput;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      role: MessageRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      tokensInput: json['tokens_input'] as int?,
      tokensOutput: json['tokens_output'] as int?,
    );
  }

  /// Build a placeholder used for optimistic UI updates before the
  /// server-issued id arrives.
  factory Message.optimisticUser(String content) {
    return Message(
      id: 'optimistic-${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.user,
      content: content,
      createdAt: DateTime.now(),
    );
  }
}
