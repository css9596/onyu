import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/saju_profile.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  bool _timeUnknown = false;
  final _location = TextEditingController(text: '서울');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '생년월일 선택',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0),
      helpText: '출생 시각 선택',
    );
    if (picked != null) {
      setState(() {
        _birthTime = picked;
        _timeUnknown = false;
      });
    }
  }

  String? _validate() {
    if (_birthDate == null) return '생년월일을 선택해주세요';
    return null;
  }

  Future<void> _submit() async {
    final v = _validate();
    if (v != null) {
      setState(() => _error = v);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final timeStr = _timeUnknown || _birthTime == null
        ? null
        : '${_birthTime!.hour.toString().padLeft(2, '0')}:'
            '${_birthTime!.minute.toString().padLeft(2, '0')}';
    try {
      await ref.read(sajuRepositoryProvider).compute(
            birthDate: _birthDate!,
            birthTime: timeStr,
            calendar: SajuCalendar.solar,
            location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          );
      ref.invalidate(sajuProfileProvider);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _birthDate == null
        ? '선택 안 됨'
        : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';
    final timeText = _timeUnknown
        ? '시 미상'
        : (_birthTime == null
            ? '선택 안 됨'
            : _birthTime!.format(context));

    return Scaffold(
      appBar: AppBar(title: const Text('사주 정보 입력')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '사주 풀이를 위해 출생 정보가 필요합니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('생년월일 (양력)'),
                  subtitle: Text(dateText),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _busy ? null : _pickDate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('출생 시각'),
                  subtitle: Text(timeText),
                  trailing: const Icon(Icons.access_time),
                  onTap: _busy || _timeUnknown ? null : _pickTime,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('시 미상'),
                  subtitle: const Text('출생 시각을 모를 때 선택'),
                  value: _timeUnknown,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _timeUnknown = v ?? false;
                            if (_timeUnknown) _birthTime = null;
                          }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: '출생 지역',
                    helperText: '진태양시 보정에 사용 (현재는 표시용)',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('사주 계산하기'),
                ),
                const SizedBox(height: 12),
                Text(
                  '입력하신 출생 정보는 사주 계산 후 변경할 수 없습니다.',
                  style: Theme.of(context).textTheme.bodySmall,
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
