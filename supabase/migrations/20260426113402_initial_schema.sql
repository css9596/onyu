-- Onyu (사주 상담 앱) — initial schema.
-- Design reference: docs/data_model.md
--
-- Conventions:
--   * snake_case plural table names
--   * every row-owning table has created_at, updated_at, RLS enabled
--   * updated_at maintained by handle_updated_at() trigger
--   * timezone-sensitive math uses Asia/Seoul

-- ============================================================
-- Extensions
-- ============================================================
create extension if not exists pgcrypto;

-- ============================================================
-- Helper: bump updated_at on UPDATE
-- ============================================================
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
-- profiles  (1:1 with auth.users; auto-created on signup)
-- ============================================================
create table public.profiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  display_name         text,
  subscription_tier    text not null default 'free'
                         check (subscription_tier in ('free','premium')),
  daily_message_limit  int  not null default 3
                         check (daily_message_limit >= 0),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy profiles_select_own on public.profiles
  for select using (auth.uid() = id);

create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- INSERT happens via handle_new_user() trigger only.
-- DELETE is intentionally not policied (use account-deletion flow).

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

-- Auto-provision profile when a new auth user is inserted.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data->>'display_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- saju_profiles  (1:1 with profiles, immutable after insert)
-- ============================================================
create table public.saju_profiles (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null unique
                          references public.profiles(id) on delete cascade,
  birth_date            date not null,
  birth_time            time,
  birth_calendar        text not null
                          check (birth_calendar in ('solar','lunar')),
  birth_is_leap_month   boolean not null default false,
  birth_location        text,
  pillars               jsonb not null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

alter table public.saju_profiles enable row level security;

create policy saju_profiles_select_own on public.saju_profiles
  for select using (auth.uid() = user_id);

create policy saju_profiles_insert_own on public.saju_profiles
  for insert with check (auth.uid() = user_id);

-- UPDATE / DELETE intentionally not policied (immutable record).

create trigger saju_profiles_set_updated_at
  before update on public.saju_profiles
  for each row execute function public.handle_updated_at();

-- ============================================================
-- conversations
-- ============================================================
create table public.conversations (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles(id) on delete cascade,
  title             text,
  last_message_at   timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index conversations_user_recent_idx
  on public.conversations (user_id, last_message_at desc);

alter table public.conversations enable row level security;

create policy conversations_all_own on public.conversations
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create trigger conversations_set_updated_at
  before update on public.conversations
  for each row execute function public.handle_updated_at();

-- ============================================================
-- messages  (immutable; no updated_at)
-- ============================================================
create table public.messages (
  id                uuid primary key default gen_random_uuid(),
  conversation_id   uuid not null references public.conversations(id) on delete cascade,
  role              text not null check (role in ('user','assistant')),
  content           text not null,
  tokens_input      int,
  tokens_output     int,
  created_at        timestamptz not null default now()
);

create index messages_conversation_time_idx
  on public.messages (conversation_id, created_at);

alter table public.messages enable row level security;

create policy messages_select_own on public.messages
  for select using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.user_id = auth.uid()
    )
  );

create policy messages_insert_own on public.messages
  for insert with check (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.user_id = auth.uid()
    )
  );

-- UPDATE / DELETE intentionally not policied.

-- Bump conversations.last_message_at on insert.
create or replace function public.bump_conversation_last_message_at()
returns trigger
language plpgsql
as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

create trigger messages_bump_conversation
  after insert on public.messages
  for each row execute function public.bump_conversation_last_message_at();

-- ============================================================
-- subscriptions  (server-managed; client read-only)
-- ============================================================
create table public.subscriptions (
  id                          uuid primary key default gen_random_uuid(),
  user_id                     uuid not null references public.profiles(id) on delete cascade,
  store                       text not null check (store in ('appstore','playstore')),
  product_id                  text not null,
  original_transaction_id     text not null,
  latest_transaction_id       text not null,
  status                      text not null
                                check (status in ('active','expired','in_grace_period','revoked')),
  expires_at                  timestamptz not null,
  raw_payload                 jsonb not null,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  unique (store, original_transaction_id)
);

create index subscriptions_user_idx on public.subscriptions (user_id);

alter table public.subscriptions enable row level security;

create policy subscriptions_select_own on public.subscriptions
  for select using (auth.uid() = user_id);

-- INSERT / UPDATE only via service_role (Edge Function); no client policy.

create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.handle_updated_at();

-- ============================================================
-- daily_usage_view
-- Counts user-role messages per Asia/Seoul calendar day.
-- security_invoker = true so the view inherits caller's RLS on
-- the underlying messages/conversations tables.
-- ============================================================
create or replace view public.daily_usage_view
with (security_invoker = true) as
select
  c.user_id,
  (timezone('Asia/Seoul', m.created_at))::date as usage_date,
  count(*) filter (where m.role = 'user') as user_message_count
from public.messages m
join public.conversations c on c.id = m.conversation_id
group by 1, 2;

grant select on public.daily_usage_view to authenticated, service_role;
