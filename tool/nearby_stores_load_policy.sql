-- ===========================================================================
-- STEP 1 — run this first, then run:  python3 tool/load_nearby_stores.py
-- ===========================================================================
-- Grants the publishable (browser) key permission to write the directory of
-- real California grocery shops. This is deliberately temporary: the key is
-- shipped inside the app, so leaving it able to write would let anyone edit
-- the directory. Step 2 below takes the permission away again.

create table if not exists public.nearby_stores (
  id     text primary key,
  name   text not null,
  kind   text default 'Grocery',
  street text,
  city   text,
  phone  text,
  hours  text,
  lat    double precision not null,
  lng    double precision not null
);

-- The app looks these up by map box, so index the coordinates.
create index if not exists nearby_stores_latlng on public.nearby_stores (lat, lng);

alter table public.nearby_stores enable row level security;

-- Everyone may read: this is public map data, not customer data.
drop policy if exists nearby_stores_read on public.nearby_stores;
create policy nearby_stores_read on public.nearby_stores
  for select to anon, authenticated using (true);

drop policy if exists nearby_stores_temp_load on public.nearby_stores;
create policy nearby_stores_temp_load on public.nearby_stores
  for insert to anon with check (true);

drop policy if exists nearby_stores_temp_update on public.nearby_stores;
create policy nearby_stores_temp_update on public.nearby_stores
  for update to anon using (true) with check (true);

select 'ready to load — now run tool/load_nearby_stores.py' as status;


-- ===========================================================================
-- STEP 2 — run this AFTER the upload finishes, to make the key read-only again
-- ===========================================================================
-- drop policy if exists nearby_stores_temp_load   on public.nearby_stores;
-- drop policy if exists nearby_stores_temp_update on public.nearby_stores;
-- select count(*) as shops_loaded from public.nearby_stores;
