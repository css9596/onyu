enum SubscriptionTier { free, premium }

class UsageInfo {
  const UsageInfo({
    required this.tier,
    required this.dailyLimit,
    required this.usedToday,
  });

  final SubscriptionTier tier;
  final int dailyLimit;
  final int usedToday;

  bool get isFree => tier == SubscriptionTier.free;
  bool get isPremium => tier == SubscriptionTier.premium;
  bool get isAtLimit => isFree && usedToday >= dailyLimit;
  int get remaining => isPremium
      ? -1
      : (dailyLimit - usedToday).clamp(0, dailyLimit);
}
