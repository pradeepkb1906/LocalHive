-- LocalHive read-only disaster-recovery mirror.
--
-- Firestore is the system of record. This table is a standby copy of the
-- public store catalog so that if Firestore cannot be read — an outage, or
-- the free tier's daily read quota running out — customers can still see
-- which stores exist, their hours and their phone numbers.
--
-- Paste this whole file into Supabase dashboard -> SQL Editor -> Run.

create table if not exists public.providers (
  id             text primary key,
  name           text not null,
  category       text not null,
  subtitle       text default '',
  rating         numeric default 0,
  reviews        integer default 0,
  hourly_rate    numeric default 0,
  city           text default '',
  verified       boolean default false,
  emoji          text default '',
  lat            numeric default 0,
  lng            numeric default 0,
  available_from text default '',
  available_to   text default '',
  live           boolean default false,
  synced_at      timestamptz default now()
);

create index if not exists providers_live_category_idx
  on public.providers (live, category);

-- Row level security: the world may READ published listings and nothing
-- else. Writes come only from the sync script, which authenticates with the
-- service_role key and bypasses RLS. The anon key shipped in the app can
-- never write here.
alter table public.providers enable row level security;

drop policy if exists "published listings are world readable"
  on public.providers;
create policy "published listings are world readable"
  on public.providers
  for select
  using (live = true);
