-- Farcetto Jump: Top 100 mondial (Supabase)
-- Exécuter dans l'éditeur SQL du projet Supabase.
-- Activer aussi Authentication > Providers > Anonymous Sign-ins.
create table if not exists public.leaderboard_entries (
  player_id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null,
  best_score integer not null default 0 check (best_score >= 0 and best_score <= 1000000),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint nickname_length check (char_length(nickname) between 1 and 16),
  constraint nickname_clean check (nickname !~ '[<>[:cntrl:]]')
);
create unique index if not exists leaderboard_unique_nickname on public.leaderboard_entries (lower(nickname));
create index if not exists leaderboard_best_idx on public.leaderboard_entries (best_score desc, updated_at asc);
alter table public.leaderboard_entries enable row level security;
revoke all on table public.leaderboard_entries from anon, authenticated;
-- Expose only the nickname and best score, never authentication IDs.
create or replace view public.leaderboard_public as
select nickname, best_score from public.leaderboard_entries;
revoke all on public.leaderboard_public from public;
grant select on public.leaderboard_public to anon, authenticated;
create or replace function public.submit_score(p_nickname text,p_score integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := auth.uid();
  v_name text := trim(p_nickname);
begin
  if v_id is null then raise exception 'Authentification requise'; end if;
  if v_name is null or length(v_name) < 1 or length(v_name) > 16 or v_name ~ '[<>[:cntrl:]]' then
    raise exception 'Pseudo invalide';
  end if;
  if p_score is null or p_score < 0 or p_score > 1000000 then raise exception 'Score invalide'; end if;
  insert into public.leaderboard_entries(player_id,nickname,best_score)
  values(v_id,v_name,p_score)
  on conflict (player_id) do update
  set nickname=excluded.nickname,
      best_score=greatest(public.leaderboard_entries.best_score,excluded.best_score),
      updated_at=now();
end;
$$;
revoke all on function public.submit_score(text,integer) from public;
grant execute on function public.submit_score(text,integer) to authenticated;
-- Note: les scores envoyés par un client web ne sont pas vérifiables côté serveur.
-- Pour une protection forte contre la triche, une validation de partie serveur serait nécessaire.
