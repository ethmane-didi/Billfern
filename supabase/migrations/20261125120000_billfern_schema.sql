-- Billfern: core schema for optional cloud sync and backup.
--
-- Principles
-- * The device (sembast) is the source of truth; these tables are a sync and
--   backup layer.
-- * Money is integer minor units plus an ISO 4217 code. Never floating point.
-- * Calendar dates (renewals, pauses, start/end) are `date`; event times are
--   UTC `timestamptz`.
-- * Every row is owned by an auth user; relationships use composite keys
--   (user_id, …) so a record can never reference another user's record.
-- * Subscriptions are never physically removed by sync: deletion sets
--   `deleted_at` (tombstone) so outdated devices cannot resurrect them.
-- * Deleting the auth user cascades to all of their data.

-- Server-assigned change sequence. Together with the writing transaction id
-- (change_xid) it forms the pull cursor: independent of device clocks and
-- unique, so equal timestamps never cause skipped or repeated rows.
create sequence public.sync_change_seq as bigint;

-- ---------------------------------------------------------------------------
-- Profiles: minimal, non-sensitive preferences.
-- ---------------------------------------------------------------------------
create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_currency text check (display_currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Subscriptions: current state of each tracked subscription.
-- Identity is (user_id, id). `id` is the stable client id (UUID v4 for new
-- subscriptions; older `sub_…` ids are kept unchanged), unique per user, so
-- ids from different users can never collide.
-- ---------------------------------------------------------------------------
create table public.subscriptions (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  id text not null
    check (char_length(id) between 1 and 64 and id ~ '^[A-Za-z0-9_-]+$'),
  catalog_id text check (catalog_id is null or char_length(catalog_id) <= 64),
  name text not null check (char_length(name) between 1 and 60),
  plan text not null default '' check (char_length(plan) <= 60),
  website_domain text
    check (website_domain is null or char_length(website_domain) <= 253),
  category text not null check (char_length(category) between 1 and 32),
  custom_color bigint
    check (custom_color is null or custom_color between 0 and 4294967295),
  custom_glyph text check (custom_glyph is null or char_length(custom_glyph) <= 32),
  price_minor bigint not null check (price_minor >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  billing_unit text not null check (billing_unit in ('day', 'week', 'month', 'year')),
  billing_count integer not null check (billing_count between 1 and 365),
  started_on date not null,
  billing_anchor date,
  status text not null check (status in ('active', 'paused')),
  paused_on date,
  reminder text not null check (char_length(reminder) between 1 and 32),
  notes text check (notes is null or char_length(notes) <= 500),
  -- When the user added it (client event time, UTC).
  created_at timestamptz,
  -- Archived (removed from the user's list, kept for history).
  ended_on date,
  -- Tombstone: deleted; never resurrected by outdated devices.
  deleted_at timestamptz,
  -- Optimistic concurrency: incremented on every change.
  version bigint not null default 1 check (version >= 1),
  -- Set by trigger on every write.
  server_seq bigint not null default nextval('public.sync_change_seq'),
  change_xid xid8 not null default pg_current_xact_id(),
  inserted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  check ((status = 'paused') = (paused_on is not null)),
  check (ended_on is null or ended_on >= started_on)
);

-- Pull cursor order: (change_xid, server_seq) per user.
create index subscriptions_user_cursor_idx
  on public.subscriptions (user_id, change_xid, server_seq);
create unique index subscriptions_server_seq_idx
  on public.subscriptions (server_seq);

-- ---------------------------------------------------------------------------
-- Subscription revisions: immutable history.
-- * kind 'price': billing terms in force UNTIL `until_on` (price, currency,
--   cycle), so historical analytics never use today's price.
-- * kind 'pause': a finished pause from `effective_from` to `until_on`
--   (the resume date).
-- Archival is `subscriptions.ended_on`.
-- ---------------------------------------------------------------------------
create table public.subscription_revisions (
  user_id uuid not null,
  subscription_id text not null,
  kind text not null check (kind in ('price', 'pause')),
  effective_from date,
  until_on date not null,
  price_minor bigint check (price_minor >= 0),
  currency_code text check (currency_code ~ '^[A-Z]{3}$'),
  billing_unit text check (billing_unit in ('day', 'week', 'month', 'year')),
  billing_count integer check (billing_count between 1 and 365),
  recorded_at timestamptz not null default now(),
  primary key (user_id, subscription_id, kind, until_on),
  foreign key (user_id, subscription_id)
    references public.subscriptions (user_id, id) on delete cascade,
  check (
    (kind = 'price'
      and effective_from is null
      and price_minor is not null and currency_code is not null
      and billing_unit is not null and billing_count is not null)
    or
    (kind = 'pause'
      and effective_from is not null and effective_from < until_on
      and price_minor is null and currency_code is null
      and billing_unit is null and billing_count is null)
  )
);

-- ---------------------------------------------------------------------------
-- Payment records: PREPARED for future confirmed payments (manual or bank).
-- Not written by the app yet. Never generated from expected renewals.
-- ---------------------------------------------------------------------------
create table public.payment_records (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  subscription_id text,
  subscription_name text not null check (char_length(subscription_name) between 1 and 60),
  amount_minor bigint not null check (amount_minor >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  paid_on date not null,
  status text not null check (status in ('confirmed', 'refunded', 'failed')),
  source text not null check (source in ('manual', 'bank')),
  created_at timestamptz not null default now(),
  primary key (user_id, id),
  foreign key (user_id, subscription_id)
    references public.subscriptions (user_id, id) on delete set null (subscription_id)
);

create index payment_records_user_paid_idx
  on public.payment_records (user_id, paid_on);

-- ---------------------------------------------------------------------------
-- Processed sync operations: makes pushes idempotent (a retried operation
-- returns its original result instead of being applied twice).
-- ---------------------------------------------------------------------------
create table public.sync_operations (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  op_id uuid not null,
  subscription_id text not null,
  result jsonb not null,
  processed_at timestamptz not null default now(),
  primary key (user_id, op_id)
);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- Assigns the change sequence and transaction id on every write and keeps
-- ownership and identity immutable.
create function public.subscriptions_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id or new.id is distinct from old.id then
      raise exception 'Subscription ownership and id cannot change'
        using errcode = '42501';
    end if;
  end if;
  new.server_seq := nextval('public.sync_change_seq');
  new.change_xid := pg_current_xact_id();
  new.updated_at := now();
  return new;
end;
$$;

create trigger subscriptions_before_write
  before insert or update on public.subscriptions
  for each row execute function public.subscriptions_before_write();

-- Revisions are history: they can be added, never changed.
create function public.reject_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% rows are immutable', tg_table_name using errcode = '42501';
end;
$$;

create trigger subscription_revisions_immutable
  before update on public.subscription_revisions
  for each row execute function public.reject_update();

create trigger sync_operations_immutable
  before update on public.sync_operations
  for each row execute function public.reject_update();

-- Timestamps are server-assigned (clients cannot forge them): updated_at is
-- the change token for display-currency sync.
create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id then
      raise exception 'Ownership cannot change' using errcode = '42501';
    end if;
    new.created_at := old.created_at;
  else
    new.created_at := now();
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before insert or update on public.profiles
  for each row execute function public.touch_updated_at();

-- Trigger functions are never called directly by clients.
revoke all on function public.subscriptions_before_write() from public, anon, authenticated;
revoke all on function public.reject_update() from public, anon, authenticated;
revoke all on function public.touch_updated_at() from public, anon, authenticated;
