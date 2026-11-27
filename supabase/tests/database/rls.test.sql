-- Billfern: Row Level Security and sync-function tests (pgTAP).
--
-- Run against a LOCAL Supabase stack:   supabase test db
-- Uses two distinct authenticated users (A, B) and the anonymous role.
-- Everything runs in one transaction and is rolled back.
--
-- Transaction visibility: sync_pull deliberately returns only rows written by
-- transactions older than every transaction still in progress
-- (change_xid < snapshot xmin), so a cursor can never skip a concurrent
-- write. In this file every write belongs to the test's own open transaction,
-- which is still in progress, so pulls would see nothing. That is asserted
-- below as a regression check. To exercise delivery, pg_temp.simulate_commit()
-- re-stamps the fixture rows as if written by an already-finished
-- transaction. It touches only this transaction's rows and is rolled back.

begin;
create extension if not exists pgtap with schema extensions;

select plan(40);

-- Re-stamps rows written by this (still open) transaction with an older,
-- finished transaction id, as if they had been committed. Runs as the table
-- owner; the write trigger would otherwise re-stamp the current id.
create function pg_temp.simulate_commit()
returns void
language plpgsql
as $fn$
declare
  v_finished xid8 :=
    ((pg_snapshot_xmin(pg_current_snapshot())::text::bigint) - 1)::text::xid8;
begin
  alter table public.subscriptions disable trigger subscriptions_before_write;
  update public.subscriptions
    set change_xid = v_finished
    where change_xid = pg_current_xact_id();
  alter table public.subscriptions enable trigger subscriptions_before_write;
end;
$fn$;

-- Two users.
insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-4000-8000-00000000000a', 'authenticated', 'authenticated',
   'rls-a@example.test', '{}', '{}', now(), now()),
  ('00000000-0000-4000-8000-00000000000b', 'authenticated', 'authenticated',
   'rls-b@example.test', '{}', '{}', now(), now());

create temporary table payload_a as
select jsonb_build_object(
  'id', 'sub-a', 'name', 'Netflix', 'plan', 'Standard', 'priceMinor', 1549,
  'currencyCode', 'USD', 'billingCycle', jsonb_build_object('count', 1, 'unit', 'month'),
  'category', 'entertainment', 'startedOn', '2026-01-01', 'billingAnchor', '2026-12-01',
  'status', 'active', 'reminder', 'oneDayBefore', 'createdAt', '2026-01-01T09:00:00.000Z',
  'priceHistory', jsonb_build_array(jsonb_build_object(
    'until', '2026-06-01', 'priceMinor', 1299, 'currencyCode', 'USD',
    'billingCycle', jsonb_build_object('count', 1, 'unit', 'month'))),
  'pauseHistory', jsonb_build_array(jsonb_build_object('from', '2026-03-01', 'until', '2026-04-01'))
) as p;
grant select on payload_a to authenticated, anon;

-- ---------------------------------------------------------------------------
-- Anonymous client: no access.
-- ---------------------------------------------------------------------------
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok($$ select * from public.subscriptions $$, '42501', null,
  'anon cannot read subscriptions');
-- (TRUNCATE is not covered by RLS, so no role but the owner may use it.)
select throws_ok($$ select * from public.subscription_revisions $$, '42501', null,
  'anon cannot read revisions');
select throws_ok($$ select * from public.profiles $$, '42501', null,
  'anon cannot read profiles');
select throws_ok($$ select * from public.payment_records $$, '42501', null,
  'anon cannot read payment records');
select throws_ok(
  $$ select public.sync_push(gen_random_uuid(), 'sub-x', 'upsert', null, (select p from payload_a)) $$,
  '42501', null, 'anon cannot call sync_push');
select throws_ok($$ select public.sync_pull(null, 0, 10) $$, '42501', null,
  'anon cannot call sync_pull');

-- ---------------------------------------------------------------------------
-- User A creates data through the sync function.
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);

select is(
  (public.sync_push('10000000-0000-4000-8000-000000000001', 'sub-a', 'upsert', null,
    (select p from payload_a)) ->> 'status'),
  'applied', 'A inserts a subscription');

select is(
  (public.sync_push('10000000-0000-4000-8000-000000000001', 'sub-a', 'upsert', null,
    (select p from payload_a)) ->> 'status'),
  'applied', 'repeating the same operation id returns the original result');

select is((select count(*)::int from public.subscriptions), 1,
  'duplicate delivery did not insert twice');

select is((select count(*)::int from public.subscription_revisions), 2,
  'price and pause revisions stored');

select is(
  (public.sync_push(gen_random_uuid(), 'sub-a', 'upsert', 7,
    (select p from payload_a)) ->> 'status'),
  'conflict', 'a stale base version is a conflict');

select ok(
  (select change_xid = pg_current_xact_id() from public.subscriptions where id = 'sub-a'),
  'every write is stamped with its transaction id');

select is((public.sync_pull(null, 0, 10) -> 'records'), '[]'::jsonb,
  'a pull never delivers writes of a transaction still in progress');

-- From here on, A's insert counts as committed.
reset role;
select pg_temp.simulate_commit();
set local role authenticated;

select is(
  (public.sync_pull(null, 0, 10) -> 'records' -> 0 -> 'payload' ->> 'priceMinor')::int,
  1549, 'A pulls its own subscription with integer minor units');

select is(
  (with first as (select public.sync_pull(null, 0, 10) as page)
   select public.sync_pull(page -> 'cursor' ->> 'xid', (page -> 'cursor' ->> 'seq')::bigint, 10)
            -> 'records'
   from first),
  '[]'::jsonb, 'pulling after the returned cursor repeats nothing');

select lives_ok($$ insert into public.payment_records
  (user_id, subscription_id, subscription_name, amount_minor, currency_code, paid_on, status, source)
  values ('00000000-0000-4000-8000-00000000000a', 'sub-a', 'Netflix', 1549, 'USD', '2026-11-01', 'confirmed', 'manual') $$,
  'A records a payment for its own subscription');

select lives_ok($$ insert into public.profiles (user_id, display_currency)
  values ('00000000-0000-4000-8000-00000000000a', 'NOK') $$, 'A creates its profile');

select throws_ok($$ insert into public.payment_records
  (user_id, subscription_id, subscription_name, amount_minor, currency_code, paid_on, status, source)
  values ('00000000-0000-4000-8000-00000000000a', 'sub-a', 'Netflix', 1549, 'USD', '2026-11-02', 'confirmed', 'bank') $$,
  '42501', null, 'clients cannot record bank-sourced payments');

update public.profiles set created_at = '2000-01-01', updated_at = '2000-01-01';
select ok(
  (select created_at > '2001-01-01' and updated_at > '2001-01-01' from public.profiles),
  'profile timestamps are server-assigned');

select throws_ok(
  $$ select public.sync_push(gen_random_uuid(), 'sub-a', null, null, (select p from payload_a)) $$,
  '22023', null, 'an operation without a kind is rejected');

select throws_ok($$ select public.touch_updated_at() $$, '42501', null,
  'trigger functions are not executable by clients');

select throws_ok($$ update public.subscription_revisions set price_minor = 1 $$,
  '42501', null, 'revisions cannot be edited directly');

select throws_ok($$ update public.subscriptions set deleted_at = null, version = 99 $$,
  '42501', null, 'A cannot bypass sync_push with direct writes');

-- ---------------------------------------------------------------------------
-- User B: no access to A's data.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);

select is_empty($$ select * from public.subscriptions $$, 'B cannot read A''s subscriptions');
select is_empty($$ select * from public.subscription_revisions $$, 'B cannot read A''s revisions');
select is_empty($$ select * from public.payment_records $$, 'B cannot read A''s payments');
select is_empty($$ select * from public.profiles $$, 'B cannot read A''s profile');
select is((public.sync_pull(null, 0, 10) -> 'records'), '[]'::jsonb, 'B pulls nothing of A''s');

select throws_ok($$ insert into public.subscriptions
  (user_id, id, name, category, price_minor, currency_code, billing_unit, billing_count,
   started_on, status, reminder)
  values ('00000000-0000-4000-8000-00000000000a', 'sub-b-forged', 'X', 'music', 100, 'USD',
          'month', 1, '2026-01-01', 'active', 'none') $$,
  '42501', null, 'B cannot insert under A''s identity');

select throws_ok($$ update public.subscriptions set name = 'Hacked' $$,
  '42501', null, 'B cannot update A''s subscriptions');

select throws_ok($$ delete from public.subscriptions $$,
  '42501', null, 'B cannot delete A''s subscriptions');

select results_eq($$ with d as (delete from public.payment_records returning 1)
  select count(*)::int from d $$, $$ values (0) $$, 'B cannot delete A''s payments');

select throws_ok($$ insert into public.subscription_revisions
  (user_id, subscription_id, kind, effective_from, until_on)
  values ('00000000-0000-4000-8000-00000000000b', 'sub-a', 'pause', '2026-05-01', '2026-05-10') $$,
  '42501', null, 'B cannot write revisions (none can, outside sync_push)');

select throws_ok($$ insert into public.payment_records
  (user_id, subscription_id, subscription_name, amount_minor, currency_code, paid_on, status, source)
  values ('00000000-0000-4000-8000-00000000000b', 'sub-a', 'Netflix', 1, 'USD', '2026-11-01', 'confirmed', 'manual') $$,
  '23503', null, 'B cannot attach a payment to A''s subscription');

select is(
  (public.sync_push(gen_random_uuid(), 'sub-a', 'upsert', null,
    (select p from payload_a)) ->> 'status'),
  'applied', 'B''s own "sub-a" is a separate record (ids are per user)');

-- ---------------------------------------------------------------------------
-- Tombstones: deleted records are not resurrected by outdated devices.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);

select is(
  (public.sync_push(gen_random_uuid(), 'sub-a', 'delete', 1, null) ->> 'status'),
  'applied', 'A deletes (tombstone)');

select is(
  (public.sync_push(gen_random_uuid(), 'sub-a', 'upsert', 1,
    (select p from payload_a)) ->> 'status'),
  'conflict', 'an outdated edit of a deleted record is a conflict, not a resurrection');

select ok(
  (select deleted_at is not null from public.subscriptions where id = 'sub-a'),
  'the tombstone remains');

-- The delete and the rejected edit count as committed from here on.
reset role;
select pg_temp.simulate_commit();
set local role authenticated;

select is(
  (public.sync_pull(null, 0, 10) -> 'records' -> 0 ->> 'deletedAt') is not null,
  true, 'pull delivers the tombstone');

select throws_ok($$ truncate public.subscriptions $$, '42501', null,
  'authenticated users cannot truncate (RLS does not cover TRUNCATE)');

select * from finish();
rollback;
