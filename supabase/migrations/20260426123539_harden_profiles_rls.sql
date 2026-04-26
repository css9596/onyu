-- Harden profiles: end-users may only update their own display_name.
-- subscription_tier and daily_message_limit must be changed by service_role
-- (i.e. by Edge Functions like verify-purchase or by admins via Studio).
--
-- The existing RLS policy `profiles_update_own` already requires auth.uid() = id,
-- but it does not restrict which columns may be modified. We add column-level
-- privileges as a second layer.

-- Strip the broad UPDATE grant that PostgREST/Supabase auto-issues to
-- the authenticated/anon roles, then re-grant only the safe columns.
revoke update on public.profiles from authenticated, anon;
grant update (display_name) on public.profiles to authenticated;

-- service_role retains full UPDATE (granted at table creation by
-- the supabase_admin role; not affected by the revoke above).
