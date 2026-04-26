// Map saju 한자 (heavenly stems + earthly branches) to 한글 readings.
//
// A pillar like '庚午' becomes '경오'. Falls back to the input character
// when no mapping exists, so unrelated input is preserved unchanged.

const Map<String, String> _heavenlyStems = {
  '甲': '갑',
  '乙': '을',
  '丙': '병',
  '丁': '정',
  '戊': '무',
  '己': '기',
  '庚': '경',
  '辛': '신',
  '壬': '임',
  '癸': '계',
};

const Map<String, String> _earthlyBranches = {
  '子': '자',
  '丑': '축',
  '寅': '인',
  '卯': '묘',
  '辰': '진',
  '巳': '사',
  '午': '오',
  '未': '미',
  '申': '신',
  '酉': '유',
  '戌': '술',
  '亥': '해',
};

/// Returns the 한글 reading for a 2-character pillar, or '' if input is null/empty.
String pillarHangul(String? hanja) {
  if (hanja == null || hanja.isEmpty) return '';
  final buf = StringBuffer();
  for (final r in hanja.runes) {
    final c = String.fromCharCode(r);
    buf.write(_heavenlyStems[c] ?? _earthlyBranches[c] ?? c);
  }
  return buf.toString();
}
