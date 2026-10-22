-- Time Pilot, PBI-22: sinkronisasi data lokal (Hive) ke Supabase + jangkar blockchain.
-- Jalankan di Supabase > SQL Editor SETELAH schema.sql. Aman dijalankan ulang.
--
-- Pola sama dengan schema.sql: tabel ditutup dari anon/authenticated (RLS aktif tanpa
-- policy, hak dicabut); aplikasi hanya memanggil fungsi app_sync_* (SECURITY DEFINER)
-- dengan token sesi, dan fungsi mengambil user dari private.session_user_id(p_token).
--
-- Konflik tugas/sesi: last-write-wins berdasarkan updated_at dari perangkat.
-- Kursor tarik data memakai server_updated_at (jam server), bukan jam perangkat,
-- agar selisih jam antar HP tidak membuat data terlewat.
--
-- Blockchain: blok hanya bisa DITAMBAH (insert-only). Server menghitung ulang hash
-- tiap blok dan memeriksa tautan prev_hash ke blok sebelumnya. Blok yang sudah ada
-- tidak pernah diubah, jadi salinan di server menjadi jangkar untuk mendeteksi
-- perubahan data di HP.
--
-- Kode error: SESSION_INVALID, BAD_REQUEST, TOO_MANY, BLOCK_INVALID,
--             BLOCK_HASH_INVALID, CHAIN_BREAK

-- ---------------------------------------------------------------- tabel
create table if not exists public.sync_tasks (
  id                text primary key,
  user_id           uuid not null references public.users(id) on delete cascade,
  title             text not null,
  client_id         text not null,
  deadline_utc      timestamptz not null,
  status            text not null check (status in ('todo', 'inProgress', 'done')),
  created_at        timestamptz not null,
  updated_at        timestamptz not null,
  is_deleted        boolean not null default false,
  server_updated_at timestamptz not null default now()
);
create index if not exists sync_tasks_user_cursor_idx
  on public.sync_tasks (user_id, server_updated_at);

create table if not exists public.sync_work_sessions (
  id                text primary key,
  user_id           uuid not null references public.users(id) on delete cascade,
  task_id           text not null,
  client_id         text not null,
  started_at_utc    timestamptz not null,
  ended_at_utc      timestamptz,
  duration_seconds  integer not null default 0,
  late_minutes      integer not null default 0,
  updated_at        timestamptz not null,
  is_deleted        boolean not null default false,
  server_updated_at timestamptz not null default now()
);
create index if not exists sync_work_sessions_user_cursor_idx
  on public.sync_work_sessions (user_id, server_updated_at);

create table if not exists public.sync_blocks (
  user_id          uuid not null references public.users(id) on delete cascade,
  idx              integer not null check (idx >= 0),
  prev_hash        text not null,
  timestamp_ms     bigint not null,
  session_id       text not null,
  task_id          text not null,
  client_id        text not null,
  duration_seconds integer not null,
  late_minutes     integer not null,
  currency         text not null,
  net_minor        bigint not null,
  hash             text not null,
  received_at      timestamptz not null default now(),   -- jam SERVER saat blok diterima
  primary key (user_id, idx)
);

alter table public.sync_tasks         enable row level security;
alter table public.sync_work_sessions enable row level security;
alter table public.sync_blocks        enable row level security;
revoke all on public.sync_tasks, public.sync_work_sessions, public.sync_blocks
  from anon, authenticated;

-- ---------------------------------------------------------------- tugas
create or replace function public.app_sync_push_tasks(p_token text, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
  v     jsonb;
  v_n   integer := 0;
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then raise exception 'BAD_REQUEST'; end if;
  if jsonb_array_length(p_items) > 500 then raise exception 'TOO_MANY'; end if;

  for v in select e from jsonb_array_elements(p_items) e loop
    insert into sync_tasks (id, user_id, title, client_id, deadline_utc, status,
                            created_at, updated_at, is_deleted)
    values (v->>'id', v_uid, v->>'title', v->>'client_id',
            (v->>'deadline_utc')::timestamptz, v->>'status',
            (v->>'created_at')::timestamptz, (v->>'updated_at')::timestamptz,
            coalesce((v->>'is_deleted')::boolean, false))
    on conflict (id) do update
      set title        = excluded.title,
          client_id    = excluded.client_id,
          deadline_utc = excluded.deadline_utc,
          status       = excluded.status,
          updated_at   = excluded.updated_at,
          is_deleted   = excluded.is_deleted,
          server_updated_at = now()
      where sync_tasks.user_id = v_uid
        and excluded.updated_at > sync_tasks.updated_at;
    if found then v_n := v_n + 1; end if;
  end loop;
  return v_n;
end
$$;

create or replace function public.app_sync_pull_tasks(p_token text, p_since timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', t.id, 'title', t.title, 'client_id', t.client_id,
             'deadline_utc', t.deadline_utc, 'status', t.status,
             'created_at', t.created_at, 'updated_at', t.updated_at,
             'is_deleted', t.is_deleted, 'server_updated_at', t.server_updated_at)
           order by t.server_updated_at)
    from sync_tasks t
    where t.user_id = v_uid
      and (p_since is null or t.server_updated_at > p_since)
  ), '[]'::jsonb);
end
$$;

-- ---------------------------------------------------------------- sesi kerja
create or replace function public.app_sync_push_sessions(p_token text, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
  v     jsonb;
  v_n   integer := 0;
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then raise exception 'BAD_REQUEST'; end if;
  if jsonb_array_length(p_items) > 500 then raise exception 'TOO_MANY'; end if;

  for v in select e from jsonb_array_elements(p_items) e loop
    insert into sync_work_sessions (id, user_id, task_id, client_id, started_at_utc,
                                    ended_at_utc, duration_seconds, late_minutes,
                                    updated_at, is_deleted)
    values (v->>'id', v_uid, v->>'task_id', v->>'client_id',
            (v->>'started_at_utc')::timestamptz,
            nullif(v->>'ended_at_utc', '')::timestamptz,
            coalesce((v->>'duration_seconds')::integer, 0),
            coalesce((v->>'late_minutes')::integer, 0),
            (v->>'updated_at')::timestamptz,
            coalesce((v->>'is_deleted')::boolean, false))
    on conflict (id) do update
      set task_id          = excluded.task_id,
          client_id        = excluded.client_id,
          started_at_utc   = excluded.started_at_utc,
          ended_at_utc     = excluded.ended_at_utc,
          duration_seconds = excluded.duration_seconds,
          late_minutes     = excluded.late_minutes,
          updated_at       = excluded.updated_at,
          is_deleted       = excluded.is_deleted,
          server_updated_at = now()
      where sync_work_sessions.user_id = v_uid
        and excluded.updated_at > sync_work_sessions.updated_at;
    if found then v_n := v_n + 1; end if;
  end loop;
  return v_n;
end
$$;

create or replace function public.app_sync_pull_sessions(p_token text, p_since timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', s.id, 'task_id', s.task_id, 'client_id', s.client_id,
             'started_at_utc', s.started_at_utc, 'ended_at_utc', s.ended_at_utc,
             'duration_seconds', s.duration_seconds, 'late_minutes', s.late_minutes,
             'updated_at', s.updated_at, 'is_deleted', s.is_deleted,
             'server_updated_at', s.server_updated_at)
           order by s.server_updated_at)
    from sync_work_sessions s
    where s.user_id = v_uid
      and (p_since is null or s.server_updated_at > p_since)
  ), '[]'::jsonb);
end
$$;

-- ---------------------------------------------------------------- blockchain
-- Teks yang di-hash HARUS sama dengan Block.canonical di aplikasi (chain.dart):
-- index|prevHash|timestampMs|sessionId|taskId|clientId|durationSeconds|lateMinutes|currency|netMinor
create or replace function public.app_sync_push_blocks(p_token text, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid       uuid := private.session_user_id(p_token);
  v           jsonb;
  v_idx       integer;
  v_prev      text;
  v_hash      text;
  v_existing  text;
  v_expected  text;
  v_inserted  integer := 0;
  v_conflicts jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then raise exception 'BAD_REQUEST'; end if;
  if jsonb_array_length(p_items) > 200 then raise exception 'TOO_MANY'; end if;

  for v in select e from jsonb_array_elements(p_items) e order by (e->>'index')::integer loop
    v_idx  := (v->>'index')::integer;
    v_prev := v->>'prev_hash';
    v_hash := v->>'hash';

    if v_idx is null or v_idx < 0
       or v_hash !~ '^[0-9a-f]{64}$' or v_prev !~ '^[0-9a-f]{64}$' then
      raise exception 'BLOCK_INVALID';
    end if;

    if v_hash <> encode(sha256(convert_to(concat_ws('|',
         v_idx, v_prev, v->>'timestamp_ms', v->>'session_id', v->>'task_id',
         v->>'client_id', v->>'duration_seconds', v->>'late_minutes',
         v->>'currency', v->>'net_minor'), 'utf8')), 'hex') then
      raise exception 'BLOCK_HASH_INVALID';
    end if;

    select hash into v_existing from sync_blocks where user_id = v_uid and idx = v_idx;
    if found then
      if v_existing <> v_hash then
        v_conflicts := v_conflicts || to_jsonb(v_idx);   -- blok berbeda dengan yang sudah di server
      end if;
      continue;
    end if;

    if v_idx = 0 then
      v_expected := repeat('0', 64);
    else
      select hash into v_expected from sync_blocks where user_id = v_uid and idx = v_idx - 1;
      if not found then raise exception 'CHAIN_BREAK'; end if;
    end if;
    if v_prev <> v_expected then raise exception 'CHAIN_BREAK'; end if;

    insert into sync_blocks (user_id, idx, prev_hash, timestamp_ms, session_id, task_id,
                             client_id, duration_seconds, late_minutes, currency,
                             net_minor, hash)
    values (v_uid, v_idx, v_prev, (v->>'timestamp_ms')::bigint, v->>'session_id',
            v->>'task_id', v->>'client_id', (v->>'duration_seconds')::integer,
            (v->>'late_minutes')::integer, v->>'currency', (v->>'net_minor')::bigint, v_hash);
    v_inserted := v_inserted + 1;
  end loop;

  return jsonb_build_object('inserted', v_inserted, 'conflicts', v_conflicts);
end
$$;

create or replace function public.app_sync_pull_blocks(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'index', b.idx, 'prev_hash', b.prev_hash, 'timestamp_ms', b.timestamp_ms,
             'session_id', b.session_id, 'task_id', b.task_id, 'client_id', b.client_id,
             'duration_seconds', b.duration_seconds, 'late_minutes', b.late_minutes,
             'currency', b.currency, 'net_minor', b.net_minor, 'hash', b.hash,
             'received_at', b.received_at)
           order by b.idx)
    from sync_blocks b
    where b.user_id = v_uid
  ), '[]'::jsonb);
end
$$;

-- ---------------------------------------------------------------- hak eksekusi
revoke all on function public.app_sync_push_tasks(text, jsonb)          from public;
revoke all on function public.app_sync_pull_tasks(text, timestamptz)    from public;
revoke all on function public.app_sync_push_sessions(text, jsonb)       from public;
revoke all on function public.app_sync_pull_sessions(text, timestamptz) from public;
revoke all on function public.app_sync_push_blocks(text, jsonb)         from public;
revoke all on function public.app_sync_pull_blocks(text)                from public;

grant execute on function public.app_sync_push_tasks(text, jsonb)          to anon, authenticated;
grant execute on function public.app_sync_pull_tasks(text, timestamptz)    to anon, authenticated;
grant execute on function public.app_sync_push_sessions(text, jsonb)       to anon, authenticated;
grant execute on function public.app_sync_pull_sessions(text, timestamptz) to anon, authenticated;
grant execute on function public.app_sync_push_blocks(text, jsonb)         to anon, authenticated;
grant execute on function public.app_sync_pull_blocks(text)                to anon, authenticated;

-- ================================================================ profil dan klien (PBI-22, bagian 2)
-- Tabel profiles dan clients, serta app_save_profile / app_save_client / app_delete_client,
-- dibuat Dev B (PBI-07). Di sini hanya ditambah fungsi TARIK supaya perangkat baru
-- bisa memulihkan persona dan klien. Klien yang dihapus ikut dikirim (is_deleted = true)
-- agar penghapusan di satu HP sampai ke HP lain.

create or replace function public.app_sync_pull_profile(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  -- null bila pengguna belum pernah menyimpan persona
  return (
    select jsonb_build_object(
             'role', p.role, 'home_timezone', p.home_timezone,
             'main_currency', p.main_currency,
             'work_start_minutes', p.work_start_minutes,
             'work_end_minutes', p.work_end_minutes,
             'challenge_type', p.challenge_type,
             'challenge_difficulty', p.challenge_difficulty,
             'updated_at', p.updated_at)
    from profiles p
    where p.user_id = v_uid
  );
end
$$;

create or replace function public.app_sync_pull_clients(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', c.id, 'name', c.name, 'timezone_id', c.timezone_id,
             'hourly_rate', c.hourly_rate, 'currency', c.currency,
             'is_deleted', c.is_deleted, 'updated_at', c.updated_at)
           order by c.updated_at)
    from clients c
    where c.user_id = v_uid
  ), '[]'::jsonb);
end
$$;

revoke all on function public.app_sync_pull_profile(text) from public;
revoke all on function public.app_sync_pull_clients(text) from public;
grant execute on function public.app_sync_pull_profile(text) to anon, authenticated;
grant execute on function public.app_sync_pull_clients(text) to anon, authenticated;