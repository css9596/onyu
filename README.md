# 온유 (Onyu)

AI 사주 상담 앱. 사용자의 사주 정보와 현재 고민을 LLM(Claude)에 전달해 매번 새로운 상담을 생성하는 모바일 앱.

> 자세한 제품/기술 컨텍스트는 [`CLAUDE.md`](./CLAUDE.md) 참고.

## 구성

```
.
├── app/        # Flutter 모바일 클라이언트 (com.sungsik.onyu)
├── supabase/   # Supabase 백엔드 (Auth, DB, Edge Functions)
└── docs/       # 시스템 프롬프트, 데이터 모델 등 문서
```

## 사전 요구사항

- Flutter SDK (개발 시 3.41+ 검증)
- Docker Desktop (로컬 Supabase 스택용)
- Supabase CLI (`brew install supabase/tap/supabase`)
- Node.js (Edge Function 개발 시)

## 로컬 개발 셋업

### 1. 저장소 클론 후 의존성 설치

```bash
cd app
flutter pub get
```

### 2. Supabase 로컬 스택 실행

프로젝트 루트에서:

```bash
supabase start
```

처음 실행 시 Docker 이미지를 받느라 몇 분 걸립니다. 완료되면 출력 끝에 `API URL`, `anon key`, `service_role key`가 나옵니다.

상태 확인:
```bash
supabase status
```

스택 종료:
```bash
supabase stop
```

### 3. Edge Function 서빙 (선택)

Claude 호출/구매 검증 등을 로컬에서 시험하려면:

```bash
# mock 모드 (Anthropic 키 없이도 OK)
supabase functions serve --env-file supabase/functions/chat/.env.local
```

`compute-saju`, `chat`, `verify-purchase` 셋 다 동시에 서빙됩니다.

### 4. Flutter 앱에 환경 변수 주입

`app/`에서 다음 형태로 실행 (URL/키는 `supabase status` 출력값):

```bash
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<로컬-publishable-key>
```

> **주의**: API 키, 결제 비밀, 개인 사주 데이터는 절대 커밋/로깅하지 않습니다 (`CLAUDE.md` 보안 원칙).
> Android 에뮬레이터는 `127.0.0.1` 대신 `10.0.2.2`로 호스트 접근.

## 플랫폼 지원

- Android: minSdk 24 (Android 7.0)
- iOS: 13.0+

## 프로덕션 배포

자세한 절차는 [`docs/release_checklist.md`](./docs/release_checklist.md)에 있습니다. 핵심만 요약:

```bash
# Supabase 클라우드 프로젝트와 연결
supabase link --project-ref <prod-ref>

# 마이그레이션 적용
supabase db push

# Edge Function 배포
supabase functions deploy compute-saju
supabase functions deploy chat
supabase functions deploy verify-purchase

# Anthropic 키 등 secrets 등록
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

`MOCK_*` 환경변수는 프로덕션에서는 절대 설정하지 않습니다.

## 문서

| 문서 | 내용 |
|------|------|
| [`CLAUDE.md`](./CLAUDE.md) | 제품/기술 컨텍스트 + 진행 상황 |
| [`docs/data_model.md`](./docs/data_model.md) | DB 스키마 단일 진실 원천 |
| [`docs/system_prompt.md`](./docs/system_prompt.md) | 채팅 시스템 프롬프트 (SSoT) |
| [`docs/release_checklist.md`](./docs/release_checklist.md) | 베타 → 출시 마스터 체크리스트 |
| [`docs/store_listing.md`](./docs/store_listing.md) | 스토어 한국어 메타데이터 |
| [`docs/beta_testing.md`](./docs/beta_testing.md) | TestFlight + Play 베타 가이드 |
| [`docs/legal/privacy_policy.md`](./docs/legal/privacy_policy.md) | 개인정보처리방침 템플릿 (변호사 검토 필수) |
| [`docs/legal/terms_of_service.md`](./docs/legal/terms_of_service.md) | 이용약관 템플릿 (변호사 검토 필수) |

## 진행 상황

`CLAUDE.md`의 "현재 진행 상황" 체크리스트 참고.
