import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/chat_repository.dart';
import '../../domain/message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  /// `conversationId` null  → start a brand new conversation.
  /// `conversationId` given → load that conversation's messages.
  const ChatScreen({super.key, this.conversationId});
  final String? conversationId;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _conversationId;
  final List<Message> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _initialLoading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _loadInitial();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      if (_conversationId == null) {
        // brand-new conversation: nothing to load.
        if (mounted) setState(() => _initialLoading = false);
        return;
      }
      final history = await repo.fetchMessages(_conversationId!);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
        _initialLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _error = '대화를 불러오지 못했습니다: $e';
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final optimistic = Message.optimisticUser(text);
    setState(() {
      _messages.add(optimistic);
      _input.clear();
      _sending = true;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final result = await ref.read(chatRepositoryProvider).sendMessage(
            conversationId: _conversationId,
            content: text,
          );
      if (!mounted) return;
      setState(() {
        _conversationId = result.conversationId;
        _messages
          ..removeWhere((m) => m.id == optimistic.id)
          ..add(result.userMessage)
          ..add(result.assistantMessage);
      });
      ref.invalidate(usageInfoProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == optimistic.id);
        _error = _humanize(e);
      });
      // 429 case bumps usage on the server side, refresh client view.
      if (e.code == 'daily_limit_reached') {
        ref.invalidate(usageInfoProvider);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == optimistic.id);
        _error = '오류: $e';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _humanize(ChatException e) {
    switch (e.code) {
      case 'daily_limit_reached':
        return '오늘 무료 대화 ${e.limit}회를 모두 사용하셨어요. 내일 다시 만나요.';
      case 'saju_profile_required':
        return '먼저 사주 정보를 등록해주세요.';
      case 'content_too_long':
        return '메시지가 너무 길어요. (최대 4000자)';
      default:
        return '오류: ${e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final usageAsync = ref.watch(usageInfoProvider);
    final usage = usageAsync.whenOrNull(data: (u) => u);
    final atLimit = usage?.isAtLimit ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상담'),
        leading: BackButton(onPressed: () => Navigator.maybePop(context)),
        bottom: usage == null || usage.isPremium
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '오늘 ${usage.usedToday}/${usage.dailyLimit}회',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(
            child: _initialLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const _EmptyChatHint()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length) {
                            return const _TypingIndicator();
                          }
                          return _MessageBubble(message: _messages[i]);
                        },
                      ),
          ),
          if (atLimit) const _UpgradeBanner(),
          _Composer(
            controller: _input,
            enabled: !_sending && !atLimit,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(Icons.workspace_premium, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '오늘 무료 대화를 모두 사용했어요.\n프리미엄으로 무제한 상담을 이용해보세요.',
              style: TextStyle(color: scheme.onPrimaryContainer, height: 1.3),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => context.push('/premium'),
            child: const Text('업그레이드'),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatHint extends StatelessWidget {
  const _EmptyChatHint();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '편하게 고민을 들려주세요.\n사주를 바탕으로 상담해드릴게요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isUser ? scheme.primary : scheme.surfaceContainerHigh;
    final textColor = isUser ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: textColor, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('답변을 준비하고 있어요…'),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: enabled ? onSend : null,
              child: const Text('전송'),
            ),
          ],
        ),
      ),
    );
  }
}
