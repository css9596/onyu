import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../domain/conversation.dart';

final _conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  // Re-fetch when auth changes.
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('conversations')
      .select('id, title, last_message_at, created_at')
      .order('last_message_at', ascending: false);
  return (rows as List)
      .map((r) => Conversation.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
});

class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convAsync = ref.watch(_conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('상담 기록'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: convAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했습니다: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '아직 시작한 상담이 없어요.\n새 상담 버튼으로 시작해보세요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(_conversationsProvider.future),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _ConversationTile(c: list[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat'),
        icon: const Icon(Icons.add),
        label: const Text('새 상담'),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.c});
  final Conversation c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('대화를 삭제하시겠어요?'),
                content: const Text('삭제한 대화는 복구할 수 없어요.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: scheme.error),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('삭제'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        try {
          await ref.read(chatRepositoryProvider).deleteConversation(c.id);
        } finally {
          ref.invalidate(_conversationsProvider);
        }
      },
      child: ListTile(
        title: Text(
          c.title?.isNotEmpty == true ? c.title! : '제목 없음',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_formatRelative(c.lastMessageAt)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/chat?id=${c.id}'),
      ),
    );
  }

  String _formatRelative(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    return '${when.year}-$m-$d';
  }
}
