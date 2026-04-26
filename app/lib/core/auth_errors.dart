/// Map Supabase Auth English error messages to user-facing Korean.
/// Matched against `AuthException.message` substrings (Supabase's messages
/// vary by version; we use partial match for resilience).
String humanizeAuthError(String raw) {
  final lower = raw.toLowerCase();

  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid credentials')) {
    return '이메일 또는 비밀번호가 올바르지 않습니다.';
  }
  if (lower.contains('email not confirmed')) {
    return '이메일 인증이 완료되지 않았어요. 메일함을 확인해주세요.';
  }
  if (lower.contains('user already registered') ||
      lower.contains('already exists')) {
    return '이미 가입된 이메일입니다. 로그인해주세요.';
  }
  if (lower.contains('weak password') || lower.contains('password should')) {
    return '비밀번호가 너무 짧아요. 6자 이상 입력해주세요.';
  }
  if (lower.contains('rate limit') || lower.contains('too many')) {
    return '요청이 너무 많아요. 잠시 후 다시 시도해주세요.';
  }
  if (lower.contains('network') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection')) {
    return '인터넷 연결을 확인해주세요.';
  }
  if (lower.contains('invalid email')) {
    return '올바른 이메일 형식이 아니에요.';
  }
  if (lower.contains('user not found')) {
    return '존재하지 않는 계정입니다.';
  }

  return '오류가 발생했어요. 잠시 후 다시 시도해주세요.';
}
