-- Allow 'mock' as a valid store value so verify-purchase mock mode (used for
-- local dev and integration tests) can persist subscription rows.
-- Real production data still uses 'appstore' or 'playstore'.

alter table public.subscriptions
  drop constraint subscriptions_store_check;

alter table public.subscriptions
  add constraint subscriptions_store_check
  check (store in ('appstore','playstore','mock'));
