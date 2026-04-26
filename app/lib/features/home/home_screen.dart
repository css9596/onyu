import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/saju_glyph.dart';
import '../../domain/usage_info.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).whenOrNull(data: (s) => s);
    final sajuAsync = ref.watch(sajuProfileProvider);
    final usageAsync = ref.watch(usageInfoProvider);
    final email = session?.user.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('온유'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              ref.invalidate(sajuProfileProvider);
              ref.invalidate(usageInfoProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '상담 기록',
            onPressed: () => context.push('/conversations'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: sajuAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('사주 정보를 불러오지 못했습니다: $e'),
            data: (profile) {
              if (profile == null) {
                return const Text('온보딩이 필요합니다.');
              }
              final pillars = [
                ('년주', profile.yearPillar),
                ('월주', profile.monthPillar),
                ('일주', profile.dayPillar),
                ('시주', profile.hourPillar),
              ];
              final textTheme = Theme.of(context).textTheme;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('환영합니다, $email', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _UsageBadge(usageAsync: usageAsync),
                  const SizedBox(height: 24),
                  Text('사주', style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final (label, char) in pillars)
                        Column(
                          children: [
                            Text(label, style: textTheme.bodySmall),
                            Text(char ?? '—', style: textTheme.headlineMedium),
                            if (char != null)
                              Text(
                                pillarHangul(char),
                                style: textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => context.push('/chat'),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('상담 시작'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UsageBadge extends StatelessWidget {
  const _UsageBadge({required this.usageAsync});
  final AsyncValue<UsageInfo?> usageAsync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return usageAsync.when(
      loading: () => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (info) {
        if (info == null) return const SizedBox.shrink();
        if (info.isPremium) {
          return Chip(
            avatar: Icon(Icons.workspace_premium, color: scheme.primary, size: 18),
            label: const Text('프리미엄 · 무제한'),
          );
        }
        return Chip(
          avatar: const Icon(Icons.bolt, size: 18),
          label: Text('무료 · 오늘 ${info.usedToday}/${info.dailyLimit}회'),
        );
      },
    );
  }
}
