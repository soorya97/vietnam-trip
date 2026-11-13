-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run.
-- Then replace the two example emails at the bottom with the real ones and run that line too.

create table if not exists public.allowed_users (email text primary key);
alter table public.allowed_users enable row level security;   -- no policies: clients can't read it

create table if not exists public.items (
  id      text primary key,
  kind    text not null,
  data    jsonb not null default '{}',
  deleted boolean not null default false,
  u       bigint not null default 0
);
alter table public.items enable row level security;

create or replace function public.is_allowed() returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.allowed_users where lower(email) = lower(auth.jwt() ->> 'email'));
$$;

drop policy if exists "members only" on public.items;
create policy "members only" on public.items for all to authenticated
  using (public.is_allowed()) with check (public.is_allowed());

alter publication supabase_realtime add table public.items;

insert into storage.buckets (id, name, public) values ('docs', 'docs', false) on conflict do nothing;
drop policy if exists "members only docs" on storage.objects;
create policy "members only docs" on storage.objects for all to authenticated
  using (bucket_id = 'docs' and public.is_allowed())
  with check (bucket_id = 'docs' and public.is_allowed());

-- Your two logins (must match the users you create under Authentication -> Users):
insert into public.allowed_users (email) values ('you@example.com'), ('partner@example.com') on conflict do nothing;
