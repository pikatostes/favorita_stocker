-- ============================================================================
-- 0005 — La lista de consumo pertenece a una planta
--
-- Cada noche puede tener hasta tres listas independientes: planta baja,
-- karaoke y terraza. El consumo sigue colgando de `night`, de modo que
-- `consumption` no necesita cambios: una fila por (noche, producto) dentro de
-- la lista de esa planta.
-- ============================================================================

alter table public.night
  add column if not exists floor text not null default 'planta_baja';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'night_floor_check'
      and conrelid = 'public.night'::regclass
  ) then
    alter table public.night
      add constraint night_floor_check
      check (floor in ('planta_baja', 'karaoke', 'terraza'));
  end if;
end $$;

-- Antes había una única lista por fecha. Se elimina cualquier restricción
-- unique que afecte solo a `date` y se sustituye por (date, floor).
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.night'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) = 'UNIQUE (date)'
  loop
    execute format(
      'alter table public.night drop constraint %I', c.conname);
  end loop;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'night_date_floor_key'
      and conrelid = 'public.night'::regclass
  ) then
    alter table public.night
      add constraint night_date_floor_key unique (date, floor);
  end if;
end $$;

-- La firma antigua no conoce la planta: se sustituye por la nueva.
drop function if exists public.save_night(date, jsonb);

create or replace function public.save_night(
  p_date date,
  p_floor text,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_night_id bigint;
  v_floor text := coalesce(nullif(trim(p_floor), ''), 'planta_baja');
begin
  if public.current_profile_id() is null then
    raise exception 'Sesión no válida o cuenta desactivada';
  end if;
  if v_floor not in ('planta_baja', 'karaoke', 'terraza') then
    raise exception 'La planta no es válida';
  end if;

  select id into v_night_id
    from public.night
   where date = p_date and floor = v_floor;

  if v_night_id is null then
    insert into public.night (date, floor)
    values (p_date, v_floor)
    returning id into v_night_id;
  end if;

  delete from public.consumption where night_id = v_night_id;

  insert into public.consumption (night_id, product_id, quantity)
  select
    v_night_id,
    (e->>'product_id')::bigint,
    (e->>'quantity')::int
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
  where (e->>'quantity')::int > 0;
end $$;

revoke all on function public.save_night(date, text, jsonb)
  from public, anon;
grant execute on function public.save_night(date, text, jsonb)
  to authenticated;
