create table public.game_saves (
  user_id uuid not null references auth.users(id) on delete cascade,
  slot smallint not null check (slot between 0 and 2),
  profile_schema integer not null,
  revision bigint not null default 1 check (revision > 0),
  save_json jsonb not null,
  content_hash text not null,
  client_updated_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, slot)
);

alter table public.game_saves enable row level security;

revoke all on table public.game_saves from anon, authenticated;
grant select, insert, update on table public.game_saves to authenticated;

create policy "Players can read their own saves"
on public.game_saves
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Players can create their own saves"
on public.game_saves
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Players can update their own saves"
on public.game_saves
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

comment on table public.game_saves is
  'Tiny Demons cloud-save replicas. Local saves remain authoritative while offline.';
