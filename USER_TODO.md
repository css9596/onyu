# 출시까지 사용자가 직접 해야 할 일

> 코드/문서/스크립트는 모두 준비됨. 아래는 외부 계정·자격증명·디자인이 필요해서
> 제가 대신할 수 없는 작업 목록입니다. 순서대로 진행하면 출시까지 갑니다.

---

## 0. 사전 결정

- [ ] **상호 확정** — "온유"가 정식 명칭이 맞으면 그대로, 아니면 한 번에 변경 (앱 이름/스토어/약관/도메인 일괄)
- [ ] **사업자 형태** — 개인사업자 등록 또는 법인 (앱 결제 매출 발생 시 부가세 신고 필요)
- [ ] **앱 아이콘 — 디자이너 최종본 받으면 일괄 교체** (현재는 placeholder sunset wordmark)
  - 같은 spec (1024×1024) 받아서 `app/assets/branding/` 의 4개 SVG 또는 PNG 교체
  - 그 후 `./generate.sh` → `dart run flutter_launcher_icons` → `dart run flutter_native_splash:create`
  - **놓치기 쉬운 곳**: 이메일 템플릿 안 HTML 아이콘 (`docs/email_templates.md`) — 현재 인라인 HTML로 그린 옛 아이콘 그대로. 디자이너 본 받으면 `<img src="...">` 로 교체 + Supabase Studio 5개 템플릿 다시 paste 필수
  - 약관 페이지 `docs/legal/site/icon.png` 도 같이 교체 (favicon + 헤더)
  - 자세한 체크리스트는 메모리 `onyu_branding_todos.md` 참고

---

## 1. GitHub Pages 활성화 (5분)

GitHub OAuth 토큰에 workflow 권한이 없어 Pages 워크플로우 push가 막혔어요. 한 줄로 해결:

```bash
cd /Users/sungsik/workspace/onyu

# 1. workflow scope 추가 (브라우저 열림 → GitHub에서 승인)
gh auth refresh -h github.com -s workflow

# 2. 워크플로우 파일 활성화
mv .github/workflows/pages.yml.pending .github/workflows/pages.yml
git add .github/workflows/pages.yml
git commit -m "Enable Pages deploy workflow"
git push

# 3. GitHub repo 페이지에서 Settings → Pages → Source = "GitHub Actions"
```

성공하면 자동 빌드 후 다음 URL 접근 가능:
- https://css9596.github.io/onyu/ (목록)
- https://css9596.github.io/onyu/privacy.html
- https://css9596.github.io/onyu/terms.html

이 URL들은 이미 앱 코드(`lib/core/links.dart`)에 하드코딩되어 있어 별도 수정 불필요.

---

## 2. Anthropic API 키 발급 (10분)

1. https://console.anthropic.com 가입
2. **결제 수단 등록** → 신용카드 (월 한도 설정 권장: 시작은 $50/월)
3. **사용량 알림 설정** — Account → Usage Limits → Email Alert at $30
4. **API 키 발급** — Account → API Keys → Create Key
5. 발급된 `sk-ant-...` 키를 안전한 곳에 저장 (Supabase secrets에 등록할 때 사용)

> **중요**: 이 키가 유출되면 누군가 본인 명의로 무한 호출 가능. 깃이나 코드에 절대 두지 말 것.

---

## 3. Supabase 프로덕션 프로젝트 (15분)

1. https://supabase.com/dashboard 가입
2. **New project** 클릭
   - Name: `onyu-prod` (마음대로)
   - Database password: 강한 비밀번호 (1Password 등 저장)
   - Region: **Northeast Asia (Seoul)** ← 한국 사용자 latency
3. 프로젝트 생성 완료 후 (5분 정도) Project Ref 복사 (URL 의 일부, `xxxxx.supabase.co`)
4. 터미널에서:
   ```bash
   cd /Users/sungsik/workspace/onyu
   supabase link --project-ref <복사한-ref>
   # DB 비밀번호 묻는 질문에 위에서 만든 비밀번호 입력

   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

   ./scripts/deploy_supabase.sh
   ```
5. 완료 후 Supabase Dashboard에서:
   - **Authentication → Providers → Email** → Confirm email = ON (가짜 이메일 봇 차단)
   - **Authentication → Email Templates** → 5개 메일 한국어 템플릿 적용 (`docs/email_templates.md` 참고)
   - **Authentication → URL Configuration** → Site URL = `https://css9596.github.io/onyu/` 또는 자체 도메인

---

## 4. Google Play Console 셋업 (1~2시간)

### 4-1. 가입 + 앱 등록
1. https://play.google.com/console 가입 ($25 1회 결제)
2. **모든 앱 → 앱 만들기**
   - 이름: 온유 — AI 사주 상담
   - 기본 언어: 한국어
   - 앱 또는 게임: 앱 / 무료 (앱 자체 무료, 인앱 결제로 수익)
3. **결제 프로필 등록** → 수익 창출 → 결제 프로필 (사업자 정보 + 은행 계좌)

### 4-2. 구독 상품 등록
1. **수익 창출 → 제품 → 구독** → 구독 만들기
2. 제품 ID: **`onyu_premium_monthly`** (코드에 하드코딩되어 있어 정확히 이 값)
3. 이름: `온유 프리미엄`
4. 기본 가격: ₩9,900
5. 결제 주기: 매월
6. 무료 평가판: (선택) 7일 권장

### 4-3. API 액세스 (영수증 검증용)
1. **설정 → API 액세스**
2. **새 서비스 계정 만들기** → JSON 다운로드
3. 권한: `androidpublisher.purchases.subscriptionsv2.get` 부여
4. 다운로드한 JSON을 안전한 곳에 보관 → Supabase secrets에 등록 시 사용 예정

```bash
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT="$(cat ~/path/to/service-account.json)"
```

### 4-4. 라이센스 테스터 등록
1. **설정 → 라이선스 테스트** → 테스터 이메일 추가 (본인 + 베타 테스터)
2. 라이선스 응답 = `RESPOND_NORMALLY`

---

## 5. Android 키스토어 생성 (10분, 한 번만)

```bash
keytool -genkey -v \
  -keystore ~/onyu-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias onyu-upload
```

질문 답변:
- 이름/조직 등: 본인 정보
- **비밀번호**: 강한 비밀번호 (1Password 저장)

> ⚠️ **이 .jks 파일을 잃으면 앱을 영원히 업데이트할 수 없습니다.** 
> - 1Password 첨부파일로 저장
> - 외장 USB 또는 Time Machine 백업
> - GitHub private repo에 올리지 말 것 (이미 .gitignore 됨)

설정 파일 만들기:
```bash
cd /Users/sungsik/workspace/onyu
cp app/android/key.properties.example app/android/key.properties
# 에디터로 열어 비밀번호와 storeFile 경로 채우기
```

---

## 6. AAB 빌드 (5분)

```bash
cd /Users/sungsik/workspace/onyu
export SUPABASE_URL=https://<your-prod-ref>.supabase.co
export SUPABASE_ANON_KEY=<sb_publishable_...>  # supabase status / Dashboard 에서

# Sentry 사용 시:
export SENTRY_DSN=https://<your-dsn>@sentry.io/...

./scripts/build_android_release.sh
```

출력: `app/build/app/outputs/bundle/release/app-release.aab`

> **참고**: SUPABASE_ANON_KEY는 Supabase Dashboard → Project Settings → API Keys에서 "Publishable" 키 복사. 이 키는 클라이언트에 노출되어도 OK (RLS가 보호).

---

## 7. Play Console 업로드 + 베타 (20분)

1. **테스트 → 내부 테스트** → 새 버전 만들기
2. AAB 업로드
3. **출시 노트** (한국어):
   ```
   온유에 오신 것을 환영합니다.
   - 사주 8자를 자동으로 계산해드려요
   - 50대 명리학자의 톤으로 상담받을 수 있어요
   - 무료로 매일 3회 / 프리미엄은 무제한
   ```
4. **테스터 그룹** 생성 → 본인 이메일 + 지인 이메일 추가
5. **저장 → 변경사항 검토 → 내부 테스트로 출시**
6. 옵트인 URL이 생성됨 → 테스터에게 전달
7. 테스터들이 옵트인 + Play Store에서 다운로드 → 실제 결제 흐름까지 테스트

상세 시나리오는 `docs/beta_testing.md` 참고.

---

## 8. 정식 출시 준비 (1~2일)

### 8-1. 스토어 등록정보 (한국어 + 영어)
**Play Console → 스토어 등록정보 → 메인 스토어 등록정보**

복붙용 텍스트는 `docs/store_listing.md`에 다 있음. 항목별 채워넣기:
- 앱 이름 / 짧은 설명 / 자세한 설명
- 그래픽 자료:
  - 앱 아이콘 (이미 빌드에 포함, 자동)
  - **그래픽 이미지 (1024×500)** ← 직접 만들거나 디자이너 의뢰
  - **휴대전화 스크린샷 (최소 2장, 권장 4~8장, 1080×1920)** ← 시뮬레이터에서 캡처
- 카테고리: 라이프스타일
- 연락처: `css9596@gmail.com`
- 개인정보처리방침 URL: `https://css9596.github.io/onyu/privacy.html`

### 8-2. 콘텐츠 등급
**Play Console → 정책 → 앱 콘텐츠 → 콘텐츠 등급** → 설문지
- 카테고리: 유틸리티 / 생산성 / 통신 → "유틸리티"  
- 폭력/성적/욕설/약물 → 모두 No
- 결제: Yes (인앱 결제 있음)
- → 보통 만 12세 이상 (12+) 으로 분류됨

### 8-3. 데이터 안전 섹션
**Play Console → 정책 → 앱 콘텐츠 → 데이터 안전**
`docs/store_listing.md`의 "App Privacy / 데이터 안전 섹션 답변" 표 그대로 입력.

### 8-4. 정식 출시 트랙
1. 내부 테스트에서 베타 검증 완료 후
2. **테스트 → 프로덕션** → 새 버전 만들기 → 같은 AAB
3. **검토 제출** → 평균 수시간 (구글은 빠른 편)
4. 승인되면 자동으로 Play Store에 게시됨

---

## 9. 출시 후 1주일 모니터링

매일 5분만 확인:
- **Anthropic Console** — 토큰 사용량 (이상치 없는지)
- **Supabase Dashboard** — Database, Logs (Edge Function 에러)
- **Sentry** — 크래시 보고
- **Play Console → 통계** — 설치, 크래시, 평점
- **Play Console → 리뷰** — 사용자 피드백 (가능한 빠른 응답)

세부 체크리스트는 `docs/release_checklist.md` Phase 5 참고.

---

## 10. 변호사 검토 (선택, 출시 후 1개월 내 권장)

지금 약관/정책은 PIPA 표준 구조를 따르는 템플릿. 이걸로 출시는 가능하지만:
- 사용자 100명 넘으면 검토 권장
- 결제 수익 발생하면 환불 정책 정밀화 필요
- 매출 100만원/월 넘으면 필수

한국 IT 전문 변호사 (예: 법무법인 세움, 디라이트 등) 50~100만원선.

---

## 코드 변경 체크리스트 (디자이너/실 IAP/Sentry 받은 뒤)

| 받은 것 | 어디 바꾸나 |
|---------|------------|
| 디자이너 캐릭터 SVG/PNG | `app/assets/branding/character.svg`, `icon.svg`, `icon_foreground.svg`, `splash.svg` 교체 → `./generate.sh` → `dart run flutter_launcher_icons` + `dart run flutter_native_splash:create` |
| Apple Developer Program 가입 | iOS 빌드 위한 keychain/profile 셋업, Bundle ID `com.sungsik.onyu` 등록 (별도 세션) |
| Sentry DSN | 빌드 시 `--dart-define=SENTRY_DSN=...` 추가 (앱 코드 수정 불필요, conditional init) |
| Google Play 상품 활성화 | 코드 수정 불필요. 다음 빌드부터 자동으로 실 IAP 사용 (mock fallback) |

---

## 도움이 필요할 때

다음 중 하나라도 막히면 이어서 진행 가능:
- "Supabase Dashboard에서 X가 안 보인다"
- "Play Console 심사 거절됐다 (사유: …)"
- "키스토어 분실… 복구할 수 있나"
- "결제 후 premium 전환 안 된다"
- "사주 계산이 이상하다 (특정 생년월일)"
- "특정 기능 추가하고 싶다"

언제든 물어봐 주세요.
