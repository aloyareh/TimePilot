-- Jangkar blockchain: hash blok terbaru milik pengguna dicatat sebagai transaksi
-- di blockchain publik (Ethereum Sepolia) oleh Edge Function "anchor-chain".
-- Karena tiap blok memuat hash blok sebelumnya, menjangkarkan hash blok
-- terbaru otomatis "mengunci" seluruh riwayat sebelumnya.
-- Mengikuti pola schema_sync.sql: RPC SECURITY DEFINER + token sesi.

create table if not exists public.chain_anchors (
  id         bigint generated always as identity primary key,
  user_id    uuid    not null,
  upto_idx   integer not null check (upto_idx >= 0),
  block_hash text    not null check (block_hash ~ '^[0-9a-f]{64}$'),
  tx_hash    text    not null check (tx_hash ~ '^0x[0-9a-f]{64}$'),
  chain_id   bigint  not null,
  created_at timestamptz not null default now(),
  unique (user_id, upto_idx)
);

alter table public.chain_anchors enable row level security;
revoke all on public.chain_anchors from anon, authenticated;

-- Dipanggil Edge Function: blok mana yang harus dijangkarkan sekarang.
create or replace function public.app_anchor_prepare(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid  uuid := private.session_user_id(p_token);
  v_idx  integer;
  v_hash text;
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  select idx, hash into v_idx, v_hash
    from sync_blocks where user_id = v_uid order by idx desc limit 1;
  if not found then raise exception 'NO_BLOCKS'; end if;
  -- Batasi: satu transaksi per blok baru (mencegah spam saldo wallet).
  if exists (select 1 from chain_anchors where user_id = v_uid and upto_idx >= v_idx) then
    raise exception 'ALREADY_ANCHORED';
  end if;
  return jsonb_build_object('idx', v_idx, 'hash', v_hash);
end
$$;

-- Dipanggil Edge Function setelah transaksi terkirim.
create or replace function public.app_anchor_save(
  p_token text, p_idx integer, p_hash text, p_tx_hash text, p_chain_id bigint)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  -- Hash yang dicatat harus sama dengan blok yang memang ada di server.
  if not exists (select 1 from sync_blocks where user_id = v_uid and idx = p_idx and hash = p_hash) then
    raise exception 'BLOCK_NOT_FOUND';
  end if;
  insert into chain_anchors (user_id, upto_idx, block_hash, tx_hash, chain_id)
  values (v_uid, p_idx, p_hash, lower(p_tx_hash), p_chain_id)
  on conflict (user_id, upto_idx) do nothing;
end
$$;

create or replace function public.app_anchor_list(p_token text)
returns table (upto_idx integer, block_hash text, tx_hash text, chain_id bigint, created_at timestamptz)
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := private.session_user_id(p_token);
begin
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  return query
    select a.upto_idx, a.block_hash, a.tx_hash, a.chain_id, a.created_at
      from chain_anchors a where a.user_id = v_uid order by a.upto_idx desc;
end
$$;

revoke all on function public.app_anchor_prepare(text)                                  from public;
revoke all on function public.app_anchor_save(text, integer, text, text, bigint)        from public;
revoke all on function public.app_anchor_list(text)                                     from public;
grant execute on function public.app_anchor_prepare(text)                               to anon, authenticated;
grant execute on function public.app_anchor_save(text, integer, text, text, bigint)     to anon, authenticated;
grant execute on function public.app_anchor_list(text)                                  to anon, authenticated;
