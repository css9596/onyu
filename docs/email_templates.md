# Supabase 이메일 템플릿 (한국어)

> Supabase가 보내는 인증 메일은 기본 영어. 프로덕션 출시 전 아래 템플릿을
> Supabase Dashboard에 붙여넣으세요.
>
> **위치**: Dashboard → Authentication → Email Templates
> **각 항목**: Subject + Message body (HTML)
>
> 사용 가능한 변수:
> - `{{ .ConfirmationURL }}` — 인증/재설정 링크
> - `{{ .Token }}` — 6자리 OTP (사용 시)
> - `{{ .Email }}` — 이용자 이메일
> - `{{ .SiteURL }}` — Auth → URL Configuration 의 Site URL

---

## 1. Confirm signup (회원가입 인증)

**Subject**:
```
[온유] 이메일 인증을 완료해주세요
```

**Message body**:
```html
<div style="font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Noto Sans KR',sans-serif;font-size:15px;line-height:1.6;color:#1c1b1f;max-width:520px;margin:0 auto;padding:32px 20px;">
  <div style="text-align:center;margin-bottom:32px;">
    <div style="width:56px;height:56px;background:#5e35b1;color:#fff;border-radius:14px;display:inline-block;text-align:center;line-height:56px;font-size:32px;font-weight:700;">온</div>
  </div>
  <h2 style="font-size:20px;margin:0 0 16px;">온유에 오신 것을 환영합니다</h2>
  <p>회원가입을 완료하려면 아래 버튼을 눌러 이메일을 인증해주세요.</p>
  <p style="text-align:center;margin:32px 0;">
    <a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#5e35b1;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">이메일 인증하기</a>
  </p>
  <p style="color:#5b5b66;font-size:13px;">버튼이 작동하지 않으면 아래 링크를 복사해 브라우저에 붙여넣어 주세요.</p>
  <p style="word-break:break-all;color:#5b5b66;font-size:12px;">{{ .ConfirmationURL }}</p>
  <hr style="border:none;border-top:1px solid #e6e6ec;margin:32px 0;">
  <p style="color:#5b5b66;font-size:12px;">본인이 가입을 신청하지 않았다면 이 메일을 무시하셔도 됩니다.</p>
</div>
```

---

## 2. Magic Link (매직 링크 로그인) — 사용 안 할 시 비워둬도 OK

**Subject**:
```
[온유] 로그인 링크
```

**Message body**:
```html
<div style="font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Noto Sans KR',sans-serif;font-size:15px;line-height:1.6;color:#1c1b1f;max-width:520px;margin:0 auto;padding:32px 20px;">
  <div style="text-align:center;margin-bottom:32px;">
    <div style="width:56px;height:56px;background:#5e35b1;color:#fff;border-radius:14px;display:inline-block;text-align:center;line-height:56px;font-size:32px;font-weight:700;">온</div>
  </div>
  <h2 style="font-size:20px;margin:0 0 16px;">로그인 링크가 도착했어요</h2>
  <p>아래 버튼을 누르면 자동으로 온유에 로그인됩니다. 링크는 한 시간 동안 유효합니다.</p>
  <p style="text-align:center;margin:32px 0;">
    <a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#5e35b1;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">로그인하기</a>
  </p>
  <hr style="border:none;border-top:1px solid #e6e6ec;margin:32px 0;">
  <p style="color:#5b5b66;font-size:12px;">본인이 요청하지 않았다면 이 메일을 무시해주세요.</p>
</div>
```

---

## 3. Reset Password (비밀번호 재설정)

**Subject**:
```
[온유] 비밀번호를 재설정해주세요
```

**Message body**:
```html
<div style="font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Noto Sans KR',sans-serif;font-size:15px;line-height:1.6;color:#1c1b1f;max-width:520px;margin:0 auto;padding:32px 20px;">
  <div style="text-align:center;margin-bottom:32px;">
    <div style="width:56px;height:56px;background:#5e35b1;color:#fff;border-radius:14px;display:inline-block;text-align:center;line-height:56px;font-size:32px;font-weight:700;">온</div>
  </div>
  <h2 style="font-size:20px;margin:0 0 16px;">비밀번호 재설정 요청</h2>
  <p>비밀번호 재설정을 신청하셨네요. 아래 버튼을 눌러 새 비밀번호를 설정해주세요.</p>
  <p style="text-align:center;margin:32px 0;">
    <a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#5e35b1;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">비밀번호 재설정</a>
  </p>
  <hr style="border:none;border-top:1px solid #e6e6ec;margin:32px 0;">
  <p style="color:#5b5b66;font-size:12px;">본인이 요청하지 않았다면 이 메일을 무시하시고, 계정 보안이 의심되면 <a href="mailto:css9596@gmail.com">css9596@gmail.com</a>으로 알려주세요.</p>
</div>
```

---

## 4. Change Email (이메일 변경 확인)

**Subject**:
```
[온유] 이메일 주소 변경을 확인해주세요
```

**Message body**:
```html
<div style="font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Noto Sans KR',sans-serif;font-size:15px;line-height:1.6;color:#1c1b1f;max-width:520px;margin:0 auto;padding:32px 20px;">
  <div style="text-align:center;margin-bottom:32px;">
    <div style="width:56px;height:56px;background:#5e35b1;color:#fff;border-radius:14px;display:inline-block;text-align:center;line-height:56px;font-size:32px;font-weight:700;">온</div>
  </div>
  <h2 style="font-size:20px;margin:0 0 16px;">이메일 주소 변경 확인</h2>
  <p>새 이메일 주소({{ .Email }})로 변경을 신청하셨네요. 아래 버튼을 눌러 확인해주세요.</p>
  <p style="text-align:center;margin:32px 0;">
    <a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#5e35b1;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">이메일 변경 확인</a>
  </p>
</div>
```

---

## 5. Invite User (초대) — 사용 안 할 시 비워둬도 OK

**Subject**:
```
[온유] 초대장이 도착했어요
```

**Message body**:
```html
<div style="font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Noto Sans KR',sans-serif;font-size:15px;line-height:1.6;color:#1c1b1f;max-width:520px;margin:0 auto;padding:32px 20px;">
  <div style="text-align:center;margin-bottom:32px;">
    <div style="width:56px;height:56px;background:#5e35b1;color:#fff;border-radius:14px;display:inline-block;text-align:center;line-height:56px;font-size:32px;font-weight:700;">온</div>
  </div>
  <h2 style="font-size:20px;margin:0 0 16px;">온유에 초대받으셨어요</h2>
  <p>아래 버튼을 누르면 가입을 시작할 수 있어요.</p>
  <p style="text-align:center;margin:32px 0;">
    <a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#5e35b1;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">시작하기</a>
  </p>
</div>
```

---

## SMTP 설정 (선택)

기본 Supabase 메일러는 발신 이메일이 `noreply@mail.app.supabase.io` 같은 일반 주소로 가서 스팸함에 들어갈 가능성이 있습니다. 출시 전 자체 도메인 SMTP 권장.

**무료/저렴한 옵션**:
- **Resend** — 월 3,000건 무료, 빠른 셋업
- **SendGrid** — 월 100건/일 무료
- **AWS SES** — 월 62,000건 거의 무료 (EC2/Lambda에서 보낼 시)

**Supabase Dashboard 설정**:
- Project Settings → Authentication → SMTP Settings → Enable Custom SMTP
- Sender Email: `noreply@<your-domain>` (or `support@<your-domain>`)
- Sender Name: `온유`
- Host/Port/Username/Password: SMTP 제공자 정보

**도메인 미보유 시**: SMTP는 나중으로 미루고 일단 Supabase 기본 발신자로 출시. 인증 메일 도착률은 70~80% 수준.

---

## 적용 후 테스트

1. Studio에서 템플릿 저장
2. 테스트 계정으로 회원가입 → Mailpit (로컬) 또는 실제 메일함 확인
3. 한글 깨짐, 버튼 작동, 링크 유효성 확인
4. 모바일 메일 앱에서도 한 번 확인 (다크모드 가독성 등)
