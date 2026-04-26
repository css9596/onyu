# 온유 데이터 모델 (v0.1 — 초안)

> 이 문서는 운영 중인 스키마의 **단일 진실 원천(Single Source of Truth)**.
> 변경 시 이 문서와 `supabase/migrations/*.sql`을 함께 업데이트한다.

## 설계 원칙

- 모든 테이블 `snake_case` 복수형 (CLAUDE.md 컨벤션).
- 모든 사용자 데이터 테이블에 `created_at`, `updated_at` 컬럼 + RLS 활성화 필수.
- `auth.users`(Supabase Auth 내장)를 사용자 마스터로 사용. 앱 데이터는 `profiles` 테이블에서 1:1로 확장.
- 사주 정보는 가입 시 한 번만 계산해 저장 (재계산 금지).
- 무료 사용자 일일 한도는 서버에서 검증 (트리거 또는 Edge Function).
- 모든 `updated_at`은 트리거로 자동 갱신.

---

## 테이블 일람

| 테이블 | 목적 | 1행당 의미 |
|--------|------|----------|
| `auth.users` | Supabase 내장 — 인증 정보 | 한 명의 인증 계정 |
| `profiles` | 앱 측 사용자 메타 (구독 티어 등) | 한 명의 앱 사용자 |
| `saju_profiles` | 가입 시 1회 계산된 사주 데이터 | 한 사람의 사주 |
| `conversations` | 상담 세션 묶음 | 한 번의 상담 주제/스레드 |
| `messages` | 사용자/AI 메시지 | 한 줄의 대화 |
| `subscriptions` | 구독 결제 영수증 + 만료 | 한 건의 결제 |
| `daily_usage_view` | 일일 사용량 집계 (VIEW) | (user_id, 날짜)당 사용 횟수 |

---

## 상세 스키마

### `profiles`
앱 측 사용자 메타데이터. `auth.users`와 1:1 (id가 곧 auth.users.id).

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | `uuid` PK, FK→`auth.users(id) ON DELETE CASCADE` | 인증 사용자 ID |
| `display_name` | `text` | 사용자 표시 이름 (선택) |
| `subscription_tier` | `text` NOT NULL DEFAULT `'free'` | `'free'` \| `'premium'` (CHECK 제약) |
| `daily_message_limit` | `int` NOT NULL DEFAULT `3` | 무료 한도 (관리자가 사용자별 조정 가능하도록 컬럼화) |
| `created_at` | `timestamptz` NOT NULL DEFAULT `now()` | |
| `updated_at` | `timestamptz` NOT NULL DEFAULT `now()` | 트리거로 갱신 |

**RLS**:
- SELECT/UPDATE: `auth.uid() = id`
- INSERT: 트리거로 `auth.users` INSERT 시 자동 생성 (`handle_new_user()`)
- DELETE: 차단 (계정 삭제는 별도 경로)

---

### `saju_profiles`
가입 직후 만세력 계산해 저장. 이후 수정 불가 원칙.

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | `uuid` PK DEFAULT `gen_random_uuid()` | |
| `user_id` | `uuid` UNIQUE NOT NULL FK→`profiles(id) ON DELETE CASCADE` | 1:1 |
| `birth_date` | `date` NOT NULL | 생년월일 |
| `birth_time` | `time` NULL | 출생 시각 (모를 경우 NULL — "시 미상" 케이스) |
| `birth_calendar` | `text` NOT NULL | `'solar'` \| `'lunar'` (음력 입력 시 양력 변환 후에도 원본 보존) |
| `birth_is_leap_month` | `bool` NOT NULL DEFAULT `false` | 음력 윤달 여부 |
| `birth_location` | `text` NULL | 지역명 (진태양시 보정용, 없으면 표준시 사용) |
| `pillars` | `jsonb` NOT NULL | 만세력 결과 전체 (천간/지지/오행/십신 등 lib 출력) |
| `created_at` | `timestamptz` NOT NULL DEFAULT `now()` | |
| `updated_at` | `timestamptz` NOT NULL DEFAULT `now()` | |

**`pillars` JSONB 예상 형태** (만세력 lib 결정 후 확정):
```json
{
  "year":  { "stem": "갑", "branch": "자" },
  "month": { "stem": "병", "branch": "인" },
  "day":   { "stem": "경", "branch": "오" },
  "hour":  { "stem": "임", "branch": "신" },
  "elements": { "wood": 2, "fire": 1, "earth": 0, "metal": 3, "water": 2 }
}
```

**RLS**: SELECT/INSERT만 허용, UPDATE/DELETE 차단 (가입 시 1회 INSERT 후 동결).

---

### `conversations`
하나의 상담 주제(스레드) — 사용자가 새 채팅을 시작할 때마다 생성.

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | `uuid` PK DEFAULT `gen_random_uuid()` | |
| `user_id` | `uuid` NOT NULL FK→`profiles(id) ON DELETE CASCADE` | |
| `title` | `text` NULL | 첫 메시지 기반 자동 생성 또는 사용자 지정 |
| `last_message_at` | `timestamptz` NOT NULL DEFAULT `now()` | 정렬용 (트리거로 갱신) |
| `created_at` | `timestamptz` NOT NULL DEFAULT `now()` | |
| `updated_at` | `timestamptz` NOT NULL DEFAULT `now()` | |

**인덱스**: `(user_id, last_message_at DESC)` — 최근 대화 목록 조회.

**RLS**: ALL `auth.uid() = user_id`.

---

### `messages`
한 conversation 내의 한 줄.

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | `uuid` PK DEFAULT `gen_random_uuid()` | |
| `conversation_id` | `uuid` NOT NULL FK→`conversations(id) ON DELETE CASCADE` | |
| `role` | `text` NOT NULL | `'user'` \| `'assistant'` (CHECK 제약) |
| `content` | `text` NOT NULL | |
| `tokens_input` | `int` NULL | Claude 응답 시 입력 토큰 (모니터링용) |
| `tokens_output` | `int` NULL | Claude 응답 시 출력 토큰 |
| `created_at` | `timestamptz` NOT NULL DEFAULT `now()` | |

**`updated_at` 없음** — 메시지는 immutable.

**인덱스**: `(conversation_id, created_at)` — 대화 시간순 조회.

**RLS**: 자기 conversation의 메시지만:
```sql
USING (EXISTS (SELECT 1 FROM conversations c WHERE c.id = conversation_id AND c.user_id = auth.uid()))
```

**트리거**: INSERT 후 부모 `conversations.last_message_at = now()` 갱신.

---

### `subscriptions`
인앱결제 영수증 검증 결과 저장. 한 사용자가 여러 영수증을 가질 수 있음 (갱신/재구매).

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | `uuid` PK DEFAULT `gen_random_uuid()` | |
| `user_id` | `uuid` NOT NULL FK→`profiles(id) ON DELETE CASCADE` | |
| `store` | `text` NOT NULL | `'appstore'` \| `'playstore'` |
| `product_id` | `text` NOT NULL | `'onyu_premium_monthly'` 등 |
| `original_transaction_id` | `text` NOT NULL | 같은 구독 갱신을 묶는 키 |
| `latest_transaction_id` | `text` NOT NULL | |
| `status` | `text` NOT NULL | `'active'` \| `'expired'` \| `'in_grace_period'` \| `'revoked'` |
| `expires_at` | `timestamptz` NOT NULL | 다음 갱신/만료 시점 |
| `raw_payload` | `jsonb` NOT NULL | 영수증 검증 응답 원본 (감사용) |
| `created_at` | `timestamptz` NOT NULL DEFAULT `now()` | |
| `updated_at` | `timestamptz` NOT NULL DEFAULT `now()` | |

**UNIQUE**: `(store, original_transaction_id)`.

**RLS**: SELECT만 사용자 본인. INSERT/UPDATE는 service_role(=Edge Function)만.

**트리거**: `subscriptions.status='active' AND expires_at > now()` 조건이 만족되면 `profiles.subscription_tier='premium'`으로 동기화. (단순화를 위해 Edge Function에서 처리해도 됨.)

---

### `daily_usage_view` (VIEW)

별도 테이블 대신 VIEW로 — 데이터 중복 회피, 카운트는 인덱스로 빠름.

```sql
CREATE VIEW daily_usage_view AS
SELECT
  c.user_id,
  date_trunc('day', m.created_at AT TIME ZONE 'Asia/Seoul')::date AS usage_date,
  count(*) FILTER (WHERE m.role = 'user') AS user_message_count
FROM messages m
JOIN conversations c ON c.id = m.conversation_id
GROUP BY 1, 2;
```

Edge Function의 `chat`에서 사용자 메시지 보내기 전 다음 체크:
```sql
SELECT user_message_count
FROM daily_usage_view
WHERE user_id = $1 AND usage_date = current_date AT TIME ZONE 'Asia/Seoul';
-- >= profiles.daily_message_limit 이고 profiles.subscription_tier = 'free' 이면 거부
```

**RLS**: VIEW에 RLS는 base 테이블 정책을 상속.

---

## 트리거/함수

1. **`handle_updated_at()`** — `BEFORE UPDATE` 트리거. `NEW.updated_at = now()`.
   - `profiles`, `saju_profiles`, `conversations`, `subscriptions`에 적용.
2. **`handle_new_user()`** — `auth.users` INSERT 시 `profiles` 자동 생성 (`SECURITY DEFINER`).
3. **`bump_conversation_last_message_at()`** — `messages` INSERT 시 `conversations.last_message_at` 갱신.

---

## ❓ 합의 필요한 결정 (5개)

답변 주시면 바로 마이그레이션 SQL 작성 들어갑니다. 각 항목에 대한 제 추천도 같이 적었어요.

### Q1. `conversations` 별도 테이블 vs 단일 타임라인
- **(A)** 위 설계대로 conversations + messages (멀티 스레드)
- **(B)** messages만 두고 user_id로 묶어 단일 무한 스크롤
- **추천: (A)**. 사주 상담은 주제별로 따로 쌓이는 게 자연스럽고 (재정/연애/이직 등), 컨텍스트 윈도우(N=20)가 주제 안에서만 흘러야 LLM 응답 품질이 유지됨. 추가 비용은 conversations 테이블 하나뿐.

### Q2. 사주 데이터 형식 — JSONB만 vs 명시 컬럼 + JSONB
- **(A)** `pillars JSONB` 한 컬럼 (위 설계)
- **(B)** `year_stem`, `year_branch`, `month_stem`, ... 8개 컬럼 + 추가 정보만 JSONB
- **추천: (A)**. 만세력 lib별 출력 차이를 흡수하기 좋고, LLM에 넘길 땐 어차피 텍스트로 직렬화. 쿼리/필터링 필요해지면 그때 generated column 추가.

### Q3. 일일 사용량 — VIEW vs 별도 테이블
- **(A)** `daily_usage_view` (위 설계)
- **(B)** `daily_usages(user_id, date, count)` 테이블 + 트리거로 INC
- **추천: (A)**. 데이터 중복 없음, MVP 트래픽에선 카운트 SELECT 빠름. 부하 커지면 materialized view로 전환.

### Q4. 로그인 방식 (Supabase Auth 활성화 범위)
- **(A)** 이메일+비밀번호만
- **(B)** 이메일 + Apple + Google 소셜
- **(C)** 위 + Kakao
- **추천: (B)**. iOS 스토어 정책상 소셜 로그인을 제공하면 Apple Sign In **필수**. Google은 Android 친화. Kakao는 한국 사용자 친화지만 Supabase는 SSO 표준 OAuth만 지원하므로 Kakao 붙이려면 별도 통합 (PKCE flow + custom verify) 필요 → MVP에선 미루는 게 안전.
- 결정에 따라 마이그레이션엔 영향 없지만 `config.toml`의 `[auth.external.*]` 섹션을 켜둘지 결정.

### Q5. 구독 상태 동기화 — 트리거 vs Edge Function
- **(A)** DB 트리거가 `subscriptions.status` 보고 `profiles.subscription_tier` 자동 갱신
- **(B)** 영수증 검증 Edge Function 안에서 명시적으로 두 테이블 모두 UPDATE
- **추천: (B)**. 결제는 외부 콜백(Apple S2S, Google RTDN) + 클라이언트 영수증 두 경로로 들어와서 비즈니스 로직이 한 곳에 있는 게 디버깅하기 쉬움. 트리거에 숨어있으면 추적 어려움.

---

각 질문에 `Q1: A, Q2: A, ...` 식으로 짧게 답해주시면 진행하겠습니다. 모두 추천대로면 "전부 추천대로" 한 마디로 OK.
