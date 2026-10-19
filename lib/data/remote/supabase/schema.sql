-- Time Pilot, PBI-02: skema autentikasi kustom (tanpa Supabase Auth, tanpa Firebase).
-- Jalankan di Supabase > SQL Editor. Aman dijalankan ulang.
--
-- Pola akses:
--   * Tabel users dan sessions ditutup total dari anon/authenticated (RLS aktif, tanpa policy, hak dicabut).
--   * Aplikasi hanya memanggil fungsi app_* (SECURITY DEFINER) lewat supabase.rpc(...).
--   * Hash password dibuat dan diverifikasi di server (bcrypt via pgcrypto).
--   * Token sesi acak dibuat di server; yang disimpan hanya hash SHA-256-nya.
--   * Fungsi lain yang butuh login (PBI selanjutnya) memanggil private.session_user_id(p_token).
--
-- Kode error (muncul di PostgrestException.message):
--   USERNAME_INVALID, PASSWORD_INVALID, USERNAME_TAKEN, INVALID_CREDENTIALS, SESSION_INVALID

-- pgcrypto di Supabase berada di schema "extensions", bukan "public".
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;   -- tidak diekspos oleh API, tempat fungsi internal

-- ---------------------------------------------------------------- tabel
create table if not exists public.users (
  id            uuid primary key default gen_random_uuid(),
  username      text not null unique,
  password_hash text not null,
  full_name     text,
  created_at    timestamptz not null default now(),
  constraint users_username_format check (username ~ '^[a-z0-9_.]{3,30}$')
);

create table if not exists public.sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  token_hash  text not null unique,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null
);
create index if not exists sessions_user_id_idx    on public.sessions(user_id);
create index if not exists sessions_expires_at_idx on public.sessions(expires_at);

alter table public.users    enable row level security;
alter table public.sessions enable row level security;
-- Supabase memberi hak default ke anon/authenticated; cabut eksplisit.
revoke all on public.users, public.sessions from anon, authenticated;

-- ---------------------------------------------------------------- fungsi internal
create or replace function private.issue_session(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_token   text        := encode(gen_random_bytes(32), 'hex');
  v_expires timestamptz := now() + interval '30 days';   -- masa berlaku sesi, ubah sesuai kebutuhan
begin
  insert into sessions (user_id, token_hash, expires_at)
  values (p_user_id, encode(sha256(convert_to(v_token, 'utf8')), 'hex'), v_expires);

  return jsonb_build_object('token', v_token, 'expires_at', v_expires);
end
$$;

create or replace function private.session_user_id(p_token text)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select s.user_id
  from sessions s
  where s.token_hash = encode(sha256(convert_to(p_token, 'utf8')), 'hex')
    and s.expires_at > now()
$$;

revoke all on function private.issue_session(uuid)    from public, anon, authenticated;
revoke all on function private.session_user_id(text)  from public, anon, authenticated;

-- ---------------------------------------------------------------- fungsi untuk aplikasi
create or replace function public.app_register(
  p_username  text,
  p_password  text,
  p_full_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_username text := lower(trim(coalesce(p_username, '')));
  v_user     users;
begin
  if v_username !~ '^[a-z0-9_.]{3,30}$' then
    raise exception 'USERNAME_INVALID';
  end if;

  -- bcrypt hanya membaca 72 karakter pertama, jadi batasi panjangnya.
  if length(coalesce(p_password, '')) < 8 or length(coalesce(p_password, '')) > 72 then
    raise exception 'PASSWORD_INVALID';
  end if;

  begin
    insert into users (username, password_hash, full_name)
    values (
      v_username,
      crypt(p_password, gen_salt('bf', 10)),
      nullif(trim(coalesce(p_full_name, '')), '')
    )
    returning * into v_user;
  exception when unique_violation then
    raise exception 'USERNAME_TAKEN';
  end;

  return jsonb_build_object(
           'user', jsonb_build_object(
             'id', v_user.id, 'username', v_user.username, 'full_name', v_user.full_name))
         || private.issue_session(v_user.id);
end
$$;

create or replace function public.app_login(p_username text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_user users;
begin
  select * into v_user
  from users
  where username = lower(trim(coalesce(p_username, '')));

  -- Pesan sama untuk "user tidak ada" dan "password salah" agar username tidak bisa ditebak.
  if not found
     or v_user.password_hash <> crypt(coalesce(p_password, ''), v_user.password_hash) then
    raise exception 'INVALID_CREDENTIALS';
  end if;

  delete from sessions where user_id = v_user.id and expires_at <= now();

  return jsonb_build_object(
           'user', jsonb_build_object(
             'id', v_user.id, 'username', v_user.username, 'full_name', v_user.full_name))
         || private.issue_session(v_user.id);
end
$$;

-- Dipanggil saat aplikasi dibuka untuk memeriksa token yang tersimpan masih berlaku.
create or replace function public.app_me(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id   uuid := private.session_user_id(p_token);
  v_user users;
begin
  if v_id is null then
    raise exception 'SESSION_INVALID';
  end if;

  select * into v_user from users where id = v_id;

  return jsonb_build_object(
           'id', v_user.id, 'username', v_user.username, 'full_name', v_user.full_name);
end
$$;

create or replace function public.app_logout(p_token text)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  delete from sessions
  where token_hash = encode(sha256(convert_to(p_token, 'utf8')), 'hex');
$$;

-- ---------------------------------------------------------------- hak eksekusi
revoke all on function public.app_register(text, text, text) from public;
revoke all on function public.app_login(text, text)          from public;
revoke all on function public.app_me(text)                   from public;
revoke all on function public.app_logout(text)               from public;

grant execute on function public.app_register(text, text, text) to anon, authenticated;
grant execute on function public.app_login(text, text)          to anon, authenticated;
grant execute on function public.app_me(text)                   to anon, authenticated;
grant execute on function public.app_logout(text)               to anon, authenticated;