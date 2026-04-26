# CLAUDE.md

이 파일은 Claude Code가 매 세션마다 자동으로 읽는 프로젝트 컨텍스트입니다.
프로젝트 루트(/)에 두세요.

---

## 프로젝트 개요

**제품명**: 온유 (Onyu) — AI 사주 상담 앱 (가칭, 변경 가능)

**한 줄 설명**: 사용자의 사주를 기반으로 일상 고민을 대화형으로 상담해주는 모바일 앱.

**차별화 포인트**: 기존 사주 앱은 정형화된 풀이 텍스트를 보여주지만, 이 앱은 사용자의 사주 정보 + 현재 고민 맥락을 LLM에 전달해 매번 새로운 상담을 생성한다. 페르소나는 "50대 후반 여성 명리학자, 차분하면서 따뜻한 톤".

**수익 모델**: 프리미엄 구독 (월 9,900원). 무료 사용자는 하루 3회 대화 제한.

---

## 기술 스택

### 클라이언트
- **Flutter** (Dart)
- 상태관리: Riverpod
- 라우팅: go_router
- HTTP: dio
- 로컬 저장소: flutter_secure_storage (토큰), shared_preferences (일반 설정)

### 백엔드 (서버리스)
- **Supabase**
  - Auth (이메일/소셜 로그인)
  - PostgreSQL (사용자, 사주, 대화, 구독 데이터)
  - Edge Functions (Deno/TypeScript) — Claude API 호출, 결제 검증
  - Row Level Security (RLS) 필수
- **Claude API** (Anthropic)
  - 모델: claude-sonnet-4-5 (출시 시점에 최신 적용)
  - 호출은 반드시 Edge Function을 통해서만. 앱에 API 키 절대 노출 금지.

### 결제
- iOS: StoreKit 2 (in_app_purchase 플러그인)
- Android: Google Play Billing (in_app_purchase 플러그인)
- 영수증 검증: Supabase Edge Function에서 서버 사이드 검증

### 사주 계산
- 만세력 라이브러리는 검증 후 결정 (한국 오픈소스 우선 검토).
- LLM에게 사주 계산을 시키지 않음. 반드시 결정론적 라이브러리 사용.

---

## 핵심 아키텍처 원칙

1. **API 키는 절대 클라이언트에 두지 않는다.** Claude API 호출은 모두 Supabase Edge Function 경유.
2. **사주 정보는 가입 시 한 번만 계산해서 DB에 저장한다.** 매번 재계산하지 않는다.
3. **시스템 프롬프트는 서버에서 관리한다.** 앱에 하드코딩하지 않는다 (튜닝 시 앱 업데이트 없이 변경 가능해야 함).
4. **대화 히스토리는 마지막 N개 메시지만 컨텍스트로 전달한다** (토큰 비용 절감). 현재 N=12 (튜닝됨; 시스템 프롬프트 prompt-caching 병행).
5. **무료 사용자 일일 한도는 서버에서 검증한다.** 클라이언트만 믿지 않는다.

---

## 디렉터리 구조 (계획)

```
/
├── CLAUDE.md                  # 이 파일
├── README.md
├── app/                       # Flutter 클라이언트
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/              # 상수, 테마, 유틸
│   │   ├── data/              # repository, supabase 클라이언트
│   │   ├── domain/            # 모델, usecase
│   │   ├── features/          # 기능별 폴더 (auth, onboarding, chat, subscription)
│   │   └── ui/                # 공통 위젯
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── supabase/                  # Supabase 프로젝트
│   ├── migrations/            # SQL 마이그레이션
│   ├── functions/             # Edge Functions
│   │   ├── chat/              # Claude API 호출
│   │   ├── verify-purchase/   # 결제 검증
│   │   └── _shared/
│   └── config.toml
└── docs/
    ├── system_prompt.md       # 운영 중인 시스템 프롬프트
    └── data_model.md          # ERD
```

---

## 코딩 컨벤션

### Flutter/Dart
- `flutter_lints` 기본 규칙 + `prefer_single_quotes`, `always_declare_return_types`.
- 위젯 파일은 한 파일당 하나의 public 위젯.
- 비동기 함수는 항상 `try-catch`로 감싸고, 에러는 `Result` 패턴 또는 `AsyncValue`로 표현.
- `print` 금지. `debugPrint` 또는 logger 패키지 사용.
- 하드코딩된 문자열은 `core/strings.dart`에 모음 (i18n 대비).

### Edge Functions (TypeScript/Deno)
- 함수 한 개당 한 파일.
- 응답은 항상 `{ data, error }` 형태로 통일.
- 환경변수는 `Deno.env.get(...)`. 키는 절대 코드에 하드코딩 금지.

### SQL/Supabase
- 테이블명은 snake_case 복수형 (예: `users`, `saju_profiles`).
- 모든 테이블에 `created_at`, `updated_at` 컬럼 포함.
- 모든 사용자 데이터 테이블에 RLS 활성화 필수.

---

## 작업할 때 지켜야 할 것

1. **한 번에 너무 많은 걸 만들지 않는다.** 기능 한 개씩, 동작 확인하면서 진행.
2. **테스트 가능한 단위로 쪼갠다.** 각 단계 끝나면 어떻게 검증할지 명시.
3. **불확실하면 질문한다.** 추측해서 진행하지 말 것. 특히 비즈니스 결정이 필요한 부분.
4. **외부 라이브러리 추가 시 이유를 명시한다.** 표준 라이브러리로 가능한 건 표준으로.
5. **민감 정보(API 키, 결제 정보, 사주 데이터) 로깅 금지.**

---

## 현재 진행 상황

(이 섹션은 작업 진행하면서 Claude Code가 업데이트)

- [x] 프로젝트 초기 셋업 (Flutter, Supabase 연결)
- [x] 데이터 모델 설계 및 마이그레이션
- [x] 사주 계산 라이브러리 통합
- [x] 인증 및 온보딩 플로우 (이메일+비밀번호; 소셜 미구현)
- [x] 대화 화면 + Edge Function 연동 (mock 모드 검증 완료; 실 Anthropic 키 추가 필요)
- [x] 시스템 프롬프트 적용 (튜닝은 진행 중)
- [x] 무료/프리미엄 구분 및 일일 한도 (서버 한도 + 클라이언트 표시; IAP는 별도)
- [x] 인앱결제 통합 (mock 검증; 실제 IAP 플러그인 연결은 스토어 등록 후)
- [ ] 베타 테스트 (체크리스트/가이드 문서 작성 완료; 실 빌드/업로드는 외부 계정 필요)
- [ ] 스토어 출시 (메타데이터/약관 템플릿 완료; 심사 제출은 사용자 작업)

---

## 참고 자료

- 시스템 프롬프트 원본: `docs/system_prompt.md`
- Anthropic API 문서: https://docs.claude.com
- Supabase 문서: https://supabase.com/docs
- Flutter 문서: https://docs.flutter.dev
