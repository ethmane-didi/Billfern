-- Billfern: Row Level Security.
--
-- Every user-owned table has RLS enabled and owner-only policies based on
-- auth.uid(). Anonymous clients get no privileges at all. Financial records
-- are written only through sync_push. The Flutter UI is never a security
-- boundary.
--
-- `(select auth.uid())` is evaluated once per statement (Supabase guidance).

-- Supabase's default privileges grant ALL (including TRUNCATE, which RLS
-- does not cover) on new public tables to anon and authenticated. Revoke
-- everything first, then grant only what each role needs.
revoke all on table
  public.profiles,
  public.subscriptions,
  public.subscription_revisions,
  public.payment_records,
  public.sync_operations
from public, anon, authenticated;
revoke all on sequence public.sync_change_seq from public, anon, authenticated;

-- Anonymous clients: nothing.

-- Authenticated clients:
-- * subscriptions, revisions and sync operations are READ-ONLY through the
--   Data API (RLS limits rows to the caller). All writes go through the
--   audited sync_push function, so clients cannot bypass version checks,
--   resurrect tombstones or forge history.
-- * profiles: own row, read/write (non-financial preference).
-- * payment_records: own rows (prepared for a later phase).
grant select on public.subscriptions to authenticated;
grant select on public.subscription_revisions to authenticated;
grant select on public.sync_operations to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.payment_records to authenticated;

alter table public.profiles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_revisions enable row level security;
alter table public.payment_records enable row level security;
alter table public.sync_operations enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create policy "profiles_select_own" on public.profiles
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "profiles_insert_own" on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "profiles_delete_own" on public.profiles
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- subscriptions, subscription_revisions, sync_operations: read own rows.
-- No write policies: writes happen only inside sync_push (SECURITY DEFINER,
-- which filters every statement by auth.uid()).
-- ---------------------------------------------------------------------------
create policy "subscriptions_select_own" on public.subscriptions
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "revisions_select_own" on public.subscription_revisions
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "sync_operations_select_own" on public.sync_operations
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- payment_records (prepared for a later phase)
-- ---------------------------------------------------------------------------
create policy "payments_select_own" on public.payment_records
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- Clients may only record MANUAL payments. Bank-sourced records must come
-- from a trusted server process (later phase), never from the device.
create policy "payments_insert_own" on public.payment_records
  for insert to authenticated
  with check ((select auth.uid()) = user_id and source = 'manual');

create policy "payments_update_own" on public.payment_records
  for update to authenticated
  using ((select auth.uid()) = user_id and source = 'manual')
  with check ((select auth.uid()) = user_id and source = 'manual');

create policy "payments_delete_own" on public.payment_records
  for delete to authenticated
  using ((select auth.uid()) = user_id);
