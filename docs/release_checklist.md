# 온유 출시 체크리스트

> 베타 → 정식 출시까지의 마스터 플레이북. 항목별로 완료되면 체크해 나가세요.

---

## Phase 0 — 의사결정 / 사전 준비

- [ ] **법인/사업자 형태** 결정 (개인 사업자 vs 법인) → 스토어 등록 시 표시되는 publisher 이름
- [ ] **상호** 확정 ("온유"가 가칭이라면 정식 명칭 결정)
- [ ] **지원 이메일** (예: `support@onyu.app`) 확보
- [ ] **회사 도메인** 확보 (개인정보처리방침/약관 호스팅용; 최소 `onyu.app` + GitHub Pages도 OK)
- [ ] **앱 아이콘** 디자인 (1024x1024 PNG, 투명배경 X)
- [ ] **스플래시 이미지** 디자인 (light/dark 양쪽)
- [ ] **로고 SVG** (스토어 배너 + 마케팅용)

---

## Phase 1 — 외부 계정 셋업

### Apple
- [ ] **Apple Developer Program** 가입 ($99/년) → https://developer.apple.com/programs
- [ ] **App Store Connect** 접속 → 새 앱 생성
  - Bundle ID: `com.sungsik.onyu`
  - 카테고리: Lifestyle (또는 Entertainment)
- [ ] **In-App Purchase 키** 생성 (App Store Connect → 사용자 및 액세스 → 키)
  - Issuer ID, Key ID, .p8 파일 보관
- [ ] **구독 그룹** 생성 → `onyu_premium_monthly` 상품 등록
  - 가격: 월 9,900원 (KRW Tier에서 선택)
- [ ] **샌드박스 테스터** 계정 생성 (App Store Connect → 사용자 및 액세스 → 샌드박스)

### Google
- [ ] **Google Play Console** 가입 ($25 1회)
- [ ] **새 앱** 생성 (Application ID: `com.sungsik.onyu`)
- [ ] **결제 프로필** 등록 (수익 창출 → 결제 프로필)
- [ ] **구독 상품** 등록: `onyu_premium_monthly`, 월 9,900원
- [ ] **API access** 활성화 → service account JSON 다운로드 (영수증 검증용)
- [ ] **라이센스 테스터** 등록 (설정 → 라이센스 테스트)

### Supabase (프로덕션)
- [ ] **새 프로젝트** 생성 (https://supabase.com/dashboard) — 리전: Northeast Asia (Seoul) 권장
- [ ] **DB 비밀번호** 안전하게 보관
- [ ] **로컬 마이그레이션** 적용:
  ```bash
  supabase link --project-ref <prod-project-ref>
  supabase db push
  ```
- [ ] **Edge Functions 배포**:
  ```bash
  supabase functions deploy compute-saju
  supabase functions deploy chat
  supabase functions deploy verify-purchase
  ```
- [ ] **Secrets 등록**:
  ```bash
  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
  # 추후 IAP 통합 시
  supabase secrets set APPLE_APP_STORE_KEY_ID=...
  supabase secrets set APPLE_APP_STORE_ISSUER_ID=...
  supabase secrets set APPLE_APP_STORE_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"
  supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT="$(cat service-account.json)"
  ```
- [ ] **`MOCK_*` env 미설정 확인** (프로덕션은 mock 모드 OFF)

### Anthropic
- [ ] **Claude API 키** 발급 (https://console.anthropic.com)
- [ ] **결제 수단** 등록 + 사용량 알림 설정 (예: $50/월 도달 시 알림)

---

## Phase 2 — 코드 / 설정 마무리

### 클라이언트 (Flutter)
- [ ] **앱 아이콘** 적용 (`flutter_launcher_icons` 패키지 추천)
- [ ] **스플래시 적용** (`flutter_native_splash`)
- [ ] **버전 번호**: `pubspec.yaml`의 `version: 1.0.0+1` 적절히 셋업 (베타: 1.0.0+N, 출시: 1.0.0+M)
- [ ] **앱 내 링크**: 약관/개인정보처리방침 화면 (Settings 탭에 추가 — 다음 마이너 작업)
- [ ] **에러 메시지 한국어화** (특히 `AuthException.message` Supabase 영어 응답 매핑)
- [ ] **Crash 리포팅** (Sentry 또는 Crashlytics) 도입 — 베타에는 필수
- [ ] **--dart-define** 환경별 값 정리 (dev / staging / prod)

### 백엔드
- [ ] **`docs/system_prompt.md` 최종 검토** + DB 동기화 마이그레이션
- [ ] **`profiles.daily_message_limit` 디폴트** 검토 (현재 3 — 출시 전 마케팅 전략에 맞춰 조정)
- [ ] **이메일 인증** 활성화 (Supabase Studio → Auth → Email confirmations ON)
- [ ] **이메일 템플릿** 한국어로 커스터마이징 (Studio → Auth → Email Templates)
- [ ] **OAuth providers** 설정 (Apple/Google — Phase 4에서 처리해도 OK)
- [ ] **Row counts/한도 모니터링** (Studio Logs/Reports로 비정상 사용 감지)

### 보안 점검
- [ ] **모든 RLS 정책 재검토** (특히 `subscription_tier` 변경 차단)
- [ ] **API 키가 클라이언트에 노출되지 않는지** grep
  ```bash
  grep -r "sk-ant\|sk_live\|service_role" app/lib/
  ```
- [ ] **Supabase service_role key**가 코드/git에 안 들어가는지 확인 (Edge Function env로만)

---

## Phase 3 — 베타 (TestFlight + Play Internal Testing)

자세한 절차는 [`beta_testing.md`](./beta_testing.md) 참고.

- [ ] iOS: TestFlight 빌드 업로드 → 내부/외부 테스터 그룹 초대
- [ ] Android: Play Console → 내부 테스트 트랙 → 빌드 업로드 → 이메일 초대
- [ ] **베타 피드백 채널** 마련 (예: 카카오톡 오픈채팅, 슬랙, Form)
- [ ] **테스트 시나리오** (회원가입 → 사주 입력 → 상담 → 결제 → 무제한 확인) 통과 확인
- [ ] **사주 정확도 샘플 검증** — 알려진 생년월일 5건 이상 외부 만세력 사이트와 비교
- [ ] **상담 응답 품질** 샘플 평가 — 페르소나 일관성, 안전 가이드 준수
- [ ] **결제 흐름 샌드박스** 테스트 (Apple Sandbox + Google License Tester)
- [ ] **버그 발견 시 패치** → 빌드 번호 올리고 재업로드

---

## Phase 4 — 정식 출시

자세한 메타데이터는 [`store_listing.md`](./store_listing.md) 참고.

### Apple App Store
- [ ] App Store Connect → 앱 정보 → 모든 메타데이터 입력 (한국어 + 영어)
- [ ] 스크린샷 업로드 (iPhone 6.9", 6.7", 5.5" 필수)
- [ ] 개인정보처리방침 URL 입력
- [ ] App Privacy 답변 (수집 데이터 명시 — `legal/privacy_policy.md` 참고)
- [ ] In-App Purchase 상품 "검토 대기" → 활성
- [ ] **심사 제출** → 평균 1~3일

### Google Play
- [ ] Play Console → 스토어 등록정보 → 한국어 메타데이터
- [ ] 스크린샷 (휴대전화 최소 2장, 7인치/10인치 태블릿 권장)
- [ ] 콘텐츠 등급 설문 (사주는 보통 만 12세 이상)
- [ ] **데이터 안전 섹션** 작성 (GDPR/PIPA 정보 공개)
- [ ] 개인정보처리방침 URL 입력
- [ ] 구독 상품 "활성"
- [ ] 출시 트랙 → 프로덕션 → **심사 제출** → 평균 수시간

### 둘 다 공통
- [ ] **개인정보처리방침/약관 호스팅** (예: GitHub Pages, Notion 공개 페이지)
- [ ] **랜딩 페이지** (선택) — 앱 소개 + 다운로드 링크
- [ ] **출시 후 모니터링 대시보드** (Supabase Logs, Anthropic 사용량, Sentry crashes)

---

## Phase 5 — 출시 후 첫 1주

- [ ] **사용자 가입수, 사주 등록률, 결제 전환율** 일일 트래킹
- [ ] **Anthropic 토큰 사용량** 모니터링 (이상치 감지)
- [ ] **무료 한도 도달률** 확인 (3회가 적절한지 데이터 기반 검토)
- [ ] **부정 사용 (자해/혐오 등 페르소나 위반 응답)** 샘플 검토 → 시스템 프롬프트 튜닝
- [ ] **버그 리포트** 트리아지 + 핫픽스 사이클
- [ ] **Apple/Google 정책 위반 알림** 모니터링 (앱 카테고리, 정신건강 가이드라인 위반 등)
- [ ] **사용자 리뷰** 응답 (가능한 빠르게)

---

## 엔지니어 입장에서 가장 흔하게 빠뜨리는 것

1. **이메일 인증 잊고 출시** → 가짜 이메일 가입자 폭증. 출시 전 무조건 ON.
2. **Supabase service_role key 노출** → 클라이언트 디컴파일 시 DB 전체 노출. Edge Function 안에만.
3. **Anthropic 사용량 알림 미설정** → 어뷰저 한 명이 하루에 $1000 청구도 가능. 무료 한도 + 알림 둘 다 필수.
4. **개인정보처리방침 누락** → 스토어 심사 즉시 거절.
5. **iOS의 IPv6/IPv4 환경 미테스트** → Apple은 IPv6-only 환경에서 심사. Edge Function 호스트가 IPv6 미지원이면 거절.
6. **사주 = 점술 → 콘텐츠 등급** 부적절 입력 → 심사 거절. "Lifestyle / 12+ / 비격리" 권장.
7. **무료 사용 후 결제 전환 강제 (다크 패턴)** → Apple 가이드라인 3.1.2 위반. 한도 도달 시 안내만, 강제 X.
