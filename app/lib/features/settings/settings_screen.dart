import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/links.dart';
import '../../core/providers.dart';
import '../../data/account_repository.dart';
import '../../domain/usage_info.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).whenOrNull(data: (s) => s);
    final usageAsync = ref.watch(usageInfoProvider);
    final email = session?.user.email ?? '';
    final usage = usageAsync.whenOrNull(data: (u) => u);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        children: [
          _SectionHeader(label: '계정'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('이메일'),
            subtitle: Text(email),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('구독 상태'),
            subtitle: Text(_subscriptionLabel(usage)),
            trailing: usage?.isPremium == true
                ? TextButton(
                    onPressed: () => _openExternal(AppLinks.manageSubscriptionUrl),
                    child: const Text('관리'),
                  )
                : TextButton(
                    onPressed: () => context.push('/premium'),
                    child: const Text('업그레이드'),
                  ),
          ),

          _SectionHeader(label: '약관 및 정책'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보처리방침'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openExternal(AppLinks.privacyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('이용약관'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openExternal(AppLinks.termsUrl),
          ),

          _SectionHeader(label: '지원'),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('문의하기'),
            subtitle: const Text(AppLinks.supportEmail),
            onTap: () => _openExternal('mailto:$AppLinks.supportEmail'),
          ),
          const _AppVersionTile(),

          _SectionHeader(label: '계정 관리'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(sajuProfileProvider);
              ref.invalidate(usageInfoProvider);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              '계정 삭제',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmDelete(context, ref),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _subscriptionLabel(UsageInfo? info) {
    if (info == null) return '확인 중…';
    if (info.isPremium) {
      final exp = info.premiumExpiresAt;
      if (exp == null) return '프리미엄 (무제한)';
      final m = exp.month.toString().padLeft(2, '0');
      final d = exp.day.toString().padLeft(2, '0');
      return '프리미엄 · ${exp.year}-$m-$d 까지';
    }
    return '무료 (오늘 ${info.usedToday}/${info.dailyLimit}회)';
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정말 삭제하시겠어요?'),
        content: const Text(
          '계정과 모든 사주 정보·대화 내역이 영구적으로 삭제됩니다. '
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      // Sign out to clear local session; router redirects to /sign-in.
      await ref.read(authRepositoryProvider).signOut();
      ref.invalidate(sajuProfileProvider);
      ref.invalidate(usageInfoProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('계정이 삭제되었습니다.')),
      );
    } on AccountException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('삭제 실패: ${e.code}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _AppVersionTile extends StatefulWidget {
  const _AppVersionTile();
  @override
  State<_AppVersionTile> createState() => _AppVersionTileState();
}

class _AppVersionTileState extends State<_AppVersionTile> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('앱 버전'),
      subtitle: Text(_version.isEmpty ? '…' : _version),
    );
  }
}
