-- Billfern: synchronization RPCs.
--
-- sync_push and sync_pull are SECURITY DEFINER with an empty search_path:
-- clients have no direct write privileges on subscriptions, revisions or
-- sync operations, so these audited functions are the only write path.
-- Because definer functions bypass RLS, EVERY statement below filters by
-- v_uid := auth.uid(), and the functions refuse to run without a user.
-- No caller-supplied user id is ever used. The helper functions are not
-- executable by clients at all.
--
-- Payloads use the app's local record format (SubscriptionCodec, schema 2):
--   { id, name, plan, priceMinor, currencyCode, billingCycle {count, unit},
--     category, startedOn, billingAnchor, catalogId, websiteDomain,
--     customColor, customGlyph, status, pausedOn, pauseHistory [{from, until}],
--     priceHistory [{until, priceMinor, currencyCode, billingCycle}],
--     reminder, notes, createdAt (UTC ISO-8601), endedOn }

-- The app record of a subscription row, including its history.
create function public.subscription_payload(s public.subscriptions)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'schema', 2,
    'id', s.id,
    'name', s.name,
    'plan', s.plan,
    'priceMinor', s.price_minor,
    'currencyCode', s.currency_code,
    'billingCycle', jsonb_build_object('count', s.billing_count, 'unit', s.billing_unit),
    'category', s.category,
    'startedOn', to_char(s.started_on, 'YYYY-MM-DD'),
    'billingAnchor', to_char(s.billing_anchor, 'YYYY-MM-DD'),
    'catalogId', s.catalog_id,
    'websiteDomain', s.website_domain,
    'customColor', s.custom_color,
    'customGlyph', s.custom_glyph,
    'status', s.status,
    'pausedOn', to_char(s.paused_on, 'YYYY-MM-DD'),
    'pauseHistory', coalesce((
      select jsonb_agg(jsonb_build_object(
          'from', to_char(r.effective_from, 'YYYY-MM-DD'),
          'until', to_char(r.until_on, 'YYYY-MM-DD'))
        order by r.until_on)
      from public.subscription_revisions r
      where r.user_id = s.user_id and r.subscription_id = s.id and r.kind = 'pause'
    ), '[]'::jsonb),
    'priceHistory', coalesce((
      select jsonb_agg(jsonb_build_object(
          'until', to_char(r.until_on, 'YYYY-MM-DD'),
          'priceMinor', r.price_minor,
          'currencyCode', r.currency_code,
          'billingCycle', jsonb_build_object('count', r.billing_count, 'unit', r.billing_unit))
        order by r.until_on)
      from public.subscription_revisions r
      where r.user_id = s.user_id and r.subscription_id = s.id and r.kind = 'price'
    ), '[]'::jsonb),
    'reminder', s.reminder,
    'notes', s.notes,
    'createdAt', to_char(s.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'endedOn', to_char(s.ended_on, 'YYYY-MM-DD')
  );
$$;

-- What sync returns for a subscription: version, sequence, tombstone, data.
create function public.subscription_record(s public.subscriptions)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', s.id,
    'version', s.version,
    'serverSequence', s.server_seq,
    'deletedAt', s.deleted_at,
    'payload', public.subscription_payload(s)
  );
$$;

-- Adds immutable revisions from a payload (existing ones are kept as-is).
create function public.sync_store_revisions(p_user uuid, p_id text, p_payload jsonb)
returns void
language sql
security invoker
set search_path = ''
as $$
  insert into public.subscription_revisions
    (user_id, subscription_id, kind, until_on, price_minor, currency_code,
     billing_unit, billing_count)
  select p_user, p_id, 'price', (e ->> 'until')::date,
         (e ->> 'priceMinor')::bigint, e ->> 'currencyCode',
         e #>> '{billingCycle,unit}', (e #>> '{billingCycle,count}')::integer
  from jsonb_array_elements(coalesce(p_payload -> 'priceHistory', '[]'::jsonb)) as e
  on conflict do nothing;

  insert into public.subscription_revisions
    (user_id, subscription_id, kind, effective_from, until_on)
  select p_user, p_id, 'pause', (e ->> 'from')::date, (e ->> 'until')::date
  from jsonb_array_elements(coalesce(p_payload -> 'pauseHistory', '[]'::jsonb)) as e
  on conflict do nothing;
$$;

-- Applies one client operation. Idempotent per op id; version-checked.
--
-- Returns one of:
--   { "status": "applied", "version": n, "deleted": bool }
--   { "status": "conflict", "record": <subscription_record> | null }
--
-- Rules
-- * upsert, record absent, base null      -> insert (version 1)
-- * upsert, record absent, base not null  -> conflict (removed in the cloud)
-- * upsert/delete, base <> server version -> conflict (changed elsewhere)
-- * upsert on a tombstone with matching base -> restore (explicit user choice)
-- * delete, matching base                 -> tombstone (deleted_at, version+1)
-- * delete of an absent or already deleted record -> applied (no-op)
create function public.sync_push(
  p_op_id uuid,
  p_subscription_id text,
  p_kind text,
  p_base_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_prior jsonb;
  v_row public.subscriptions%rowtype;
  v_found boolean;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_kind is null or p_kind not in ('upsert', 'delete') then
    raise exception 'Unknown operation kind' using errcode = '22023';
  end if;
  if p_op_id is null or p_subscription_id is null then
    raise exception 'Operation id and subscription id are required' using errcode = '22023';
  end if;
  if p_payload is not null and (
       jsonb_typeof(p_payload) <> 'object'
       or octet_length(p_payload::text) > 65536
       or jsonb_array_length(coalesce(p_payload -> 'priceHistory', '[]'::jsonb)) > 500
       or jsonb_array_length(coalesce(p_payload -> 'pauseHistory', '[]'::jsonb)) > 500) then
    raise exception 'Payload too large or malformed' using errcode = '22023';
  end if;

  -- Duplicate delivery: return the original result.
  select o.result into v_prior
  from public.sync_operations o
  where o.user_id = v_uid and o.op_id = p_op_id;
  if found then
    return v_prior;
  end if;

  select * into v_row
  from public.subscriptions s
  where s.user_id = v_uid and s.id = p_subscription_id
  for update;
  v_found := found;

  if p_kind = 'delete' then
    if not v_found then
      v_result := jsonb_build_object('status', 'applied', 'version', 0, 'deleted', true);
    elsif v_row.deleted_at is not null then
      v_result := jsonb_build_object('status', 'applied', 'version', v_row.version, 'deleted', true);
    elsif p_base_version is distinct from v_row.version then
      v_result := jsonb_build_object('status', 'conflict', 'record', public.subscription_record(v_row));
    else
      update public.subscriptions s
      set deleted_at = now(), version = s.version + 1
      where s.user_id = v_uid and s.id = p_subscription_id
      returning * into v_row;
      v_result := jsonb_build_object('status', 'applied', 'version', v_row.version, 'deleted', true);
    end if;
  else
    if p_payload is null or p_payload ->> 'id' is distinct from p_subscription_id then
      raise exception 'Payload does not match the subscription' using errcode = '22023';
    end if;

    if not v_found then
      if p_base_version is not null then
        v_result := jsonb_build_object('status', 'conflict', 'record', null);
      else
        insert into public.subscriptions (
          user_id, id, catalog_id, name, plan, website_domain, category,
          custom_color, custom_glyph, price_minor, currency_code, billing_unit,
          billing_count, started_on, billing_anchor, status, paused_on,
          reminder, notes, created_at, ended_on, version)
        values (
          v_uid, p_subscription_id,
          p_payload ->> 'catalogId',
          p_payload ->> 'name',
          coalesce(p_payload ->> 'plan', ''),
          p_payload ->> 'websiteDomain',
          p_payload ->> 'category',
          (p_payload ->> 'customColor')::bigint,
          p_payload ->> 'customGlyph',
          (p_payload ->> 'priceMinor')::bigint,
          p_payload ->> 'currencyCode',
          p_payload #>> '{billingCycle,unit}',
          (p_payload #>> '{billingCycle,count}')::integer,
          (p_payload ->> 'startedOn')::date,
          (p_payload ->> 'billingAnchor')::date,
          p_payload ->> 'status',
          (p_payload ->> 'pausedOn')::date,
          p_payload ->> 'reminder',
          p_payload ->> 'notes',
          (p_payload ->> 'createdAt')::timestamptz,
          (p_payload ->> 'endedOn')::date,
          1)
        returning * into v_row;
        perform public.sync_store_revisions(v_uid, p_subscription_id, p_payload);
        v_result := jsonb_build_object('status', 'applied', 'version', v_row.version, 'deleted', false);
      end if;
    elsif p_base_version is distinct from v_row.version then
      v_result := jsonb_build_object('status', 'conflict', 'record', public.subscription_record(v_row));
    else
      update public.subscriptions s set
        catalog_id = p_payload ->> 'catalogId',
        name = p_payload ->> 'name',
        plan = coalesce(p_payload ->> 'plan', ''),
        website_domain = p_payload ->> 'websiteDomain',
        category = p_payload ->> 'category',
        custom_color = (p_payload ->> 'customColor')::bigint,
        custom_glyph = p_payload ->> 'customGlyph',
        price_minor = (p_payload ->> 'priceMinor')::bigint,
        currency_code = p_payload ->> 'currencyCode',
        billing_unit = p_payload #>> '{billingCycle,unit}',
        billing_count = (p_payload #>> '{billingCycle,count}')::integer,
        started_on = (p_payload ->> 'startedOn')::date,
        billing_anchor = (p_payload ->> 'billingAnchor')::date,
        status = p_payload ->> 'status',
        paused_on = (p_payload ->> 'pausedOn')::date,
        reminder = p_payload ->> 'reminder',
        notes = p_payload ->> 'notes',
        created_at = (p_payload ->> 'createdAt')::timestamptz,
        ended_on = (p_payload ->> 'endedOn')::date,
        deleted_at = null,
        version = s.version + 1
      where s.user_id = v_uid and s.id = p_subscription_id
      returning * into v_row;
      perform public.sync_store_revisions(v_uid, p_subscription_id, p_payload);
      v_result := jsonb_build_object('status', 'applied', 'version', v_row.version, 'deleted', false);
    end if;
  end if;

  insert into public.sync_operations (user_id, op_id, subscription_id, result)
  values (v_uid, p_op_id, p_subscription_id, v_result);

  return v_result;
end;
$$;

-- Changes after a cursor.
--
-- Cursor = (change_xid, server_seq): rows are returned in TRANSACTION-ID
-- order, and only rows written by transactions that committed before every
-- transaction still in progress (change_xid < snapshot xmin). Any
-- transaction that can still commit has an id >= xmin, i.e. greater than
-- every id already returned, so advancing the cursor can never skip a
-- concurrent write. (Ordering by the sequence alone could: a transaction
-- that takes its id early but its sequence number late may commit a higher
-- sequence before a concurrent writer's lower one.) server_seq orders rows
-- written by the same transaction; pagination never splits or repeats rows.
--
-- p_after_xid: text form of the last cursor xid (null = from the start).
-- Returns { "records": [...], "hasMore": bool,
--           "cursor": { "xid": text, "seq": bigint } | null }.
create function public.sync_pull(
  p_after_xid text,
  p_after_seq bigint,
  p_limit integer default 200
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 500);
  v_after_xid xid8 := coalesce(p_after_xid, '0')::xid8;
  v_after_seq bigint := coalesce(p_after_seq, 0);
  v_xmin xid8 := pg_snapshot_xmin(pg_current_snapshot());
  v_records jsonb;
  v_count integer;
  v_last_xid text;
  v_last_seq bigint;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  with page as (
    select s.id, s.change_xid as xid, s.server_seq as seq
    from public.subscriptions s
    where s.user_id = v_uid
      and (s.change_xid, s.server_seq) > (v_after_xid, v_after_seq)
      and s.change_xid < v_xmin
    order by s.change_xid, s.server_seq
    limit v_limit + 1
  ), numbered as (
    select p.*, row_number() over (order by p.xid, p.seq) as ord
    from page p
  )
  select
    count(*)::integer,
    coalesce(jsonb_agg(public.subscription_record(s) order by n.ord)
      filter (where n.ord <= v_limit), '[]'::jsonb),
    (array_agg(n.xid::text order by n.ord desc) filter (where n.ord <= v_limit))[1],
    (array_agg(n.seq order by n.ord desc) filter (where n.ord <= v_limit))[1]
  into v_count, v_records, v_last_xid, v_last_seq
  from numbered n
  join public.subscriptions s on s.user_id = v_uid and s.id = n.id;

  return jsonb_build_object(
    'records', v_records,
    'hasMore', v_count > v_limit,
    'cursor', case when v_last_xid is null then null
                   else jsonb_build_object('xid', v_last_xid, 'seq', v_last_seq) end
  );
end;
$$;

-- Execution: only authenticated users may call the two sync entry points.
-- Helpers are internal (called by the definer functions as their owner).
revoke all on function public.sync_push(uuid, text, text, bigint, jsonb) from public, anon, authenticated;
revoke all on function public.sync_pull(text, bigint, integer) from public, anon, authenticated;
revoke all on function public.sync_store_revisions(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.subscription_payload(public.subscriptions) from public, anon, authenticated;
revoke all on function public.subscription_record(public.subscriptions) from public, anon, authenticated;

grant execute on function public.sync_push(uuid, text, text, bigint, jsonb) to authenticated;
grant execute on function public.sync_pull(text, bigint, integer) to authenticated;
