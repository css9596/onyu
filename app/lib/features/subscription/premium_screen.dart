import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/subscriptions_repository.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(subscriptionsRepositoryProvider);
    try {
      // Try the real platform IAP first; fall back to mock if the product
      // is not advertised (e.g. before Play Console registration completes).
      final realAvailable = await repo.isRealIapAvailable();
      if (realAvailable) {
        await repo.purchaseReal();
      } else {
        await repo.purchaseMock();
      }
      ref.invalidate(usageInfoProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(realAvailable
              ? '프리미엄으로 전환되었어요.'
              : '프리미엄으로 전환되었어요. (개발 모드 — 실 결제 없음)'),
        ),
      );
      context.pop();
    } on PurchaseException catch (e) {
      if (e.code == 'cancelled') {
        if (mounted) setState(() => _error = null);
        return;
      }
      if (mounted) setState(() => _error = '결제 실패: ${e.code}');
    } catch (e) {
      if (mounted) setState(() => _error = '오류: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프리미엄'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.workspace_premium, size: 72, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  '온유 프리미엄',
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '깊이 있는 사주 상담을 마음껏 이어가세요.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _BenefitRow(text: '하루 무제한 상담 메시지'),
                        SizedBox(height: 10),
                        _BenefitRow(text: '대화 히스토리 영구 보관'),
                        SizedBox(height: 10),
                        _BenefitRow(text: '월 9,900원 / 언제든 해지 가능'),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _purchase,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('구독하기'),
                ),
                const SizedBox(height: 8),
                Text(
                  '* 스토어에 상품이 등록되면 실제 결제 흐름이 자동으로 활성화됩니다.\n'
                  '  현재는 등록 상태에 따라 실 결제 또는 데모 모드로 진행됩니다.',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
