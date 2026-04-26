import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/conversation.dart';
import '../domain/message.dart';

class ChatException implements Exception {
  ChatException(this.code, {this.limit, this.used});
  final String code;
  final int? limit;
  final int? used;
  @override
  String toString() => 'ChatException($code)';
}

class ChatTurn {
  ChatTurn({required this.conversationId, required this.userMessage, required this.assistantMessage});
  final String conversationId;
  final Message userMessage;
  final Message assistantMessage;
}

class ChatRepository {
  ChatRepository(this._client);
  final SupabaseClient _client;

  Future<Conversation?> fetchLatestConversation() async {
    final row = await _client
        .from('conversations')
        .select('id, title, last_message_at, created_at')
        .order('last_message_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return Conversation.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<Message>> fetchMessages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select('id, role, content, tokens_input, tokens_output, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => Message.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<ChatTurn> sendMessage({
    String? conversationId,
    required String content,
  }) async {
    final response = await _client.functions.invoke('chat', body: {
      'conversation_id': ?conversationId,
      'content': content,
    });

    final body = response.data;
    if (body is! Map) {
      throw ChatException('invalid_response_shape');
    }
    final error = body['error'];
    if (error != null) {
      throw ChatException(
        error.toString(),
        limit: body['limit'] as int?,
        used: body['used'] as int?,
      );
    }
    final data = body['data'];
    if (data is! Map) {
      throw ChatException('missing_data');
    }
    final m = Map<String, dynamic>.from(data);
    return ChatTurn(
      conversationId: m['conversation_id'] as String,
      userMessage: Message.fromJson(Map<String, dynamic>.from(m['user_message'] as Map)),
      assistantMessage: Message.fromJson(Map<String, dynamic>.from(m['assistant_message'] as Map)),
    );
  }
}
