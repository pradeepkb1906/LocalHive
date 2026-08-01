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
-- STEP 2 — run this AFTER the upload finishes. Paste and run everything below.
-- ===========================================================================
-- Takes the write permission away again, so the key shipped in the app can
-- only read. Also removes the single 'probe' row left behind by the check
-- that confirmed writes were open — it could not be deleted from outside,
-- because there is deliberately no delete policy for that key.

delete from public.nearby_stores where id = 'probe';

drop policy if exists nearby_stores_temp_load   on public.nearby_stores;
drop policy if exists nearby_stores_temp_update on public.nearby_stores;

select count(*) as shops_loaded,
       count(*) filter (where city like 'San Francisco%') as in_san_francisco,
       count(*) filter (where phone is not null)          as with_phone
from public.nearby_stores;
