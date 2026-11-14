-- ============================================================================
-- 0011 — Finalizar la jornada de una lista
--
-- Añade `finalized_at` a `night` (fecha + planta) y la RPC `finalize_night`.
-- Finalizar una jornada NO borra nada: el consumo se conserva para el stock,
-- el plan y el histórico. Solo indica que la pestaña Lista ya no debe
-- precargar esa lista, para empezar la siguiente con la pantalla vacía.
--
-- Guardar de nuevo esa noche o planta reabre la jornada (`finalized_at = null`),
-- de modo que la lista recién guardada vuelve a mostrarse al entrar.
-- ============================================================================

alter table public.night
  add column if not exists finalized_at timestamptz;

-- ---------------------------------------------------------------------------
-- save_night: al guardar, la jornada vuelve a quedar abierta
-- ---------------------------------------------------------------------------

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
  v_missing text;
begin
  if public.current_profile_id() is null then
    raise exception 'Sesión no válida o cuenta desactivada';
  end if;
  if v_floor not in ('planta_baja', 'karaoke', 'terraza') then
    raise exception 'La planta no es válida';
  end if;

  select id into v_night_id
    from public.night
   where date = p_date and floor = v_floor
   for update;

  if v_night_id is null then
    insert into public.night (date, floor)
    values (p_date, v_floor)
    returning id into v_night_id;
  else
    -- Guardar una lista nueva reabre la jornada finalizada.
    update public.night
       set finalized_at = null
     where id = v_night_id;
  end if;

  -- El stock disponible debe cubrir la nueva lista una vez devuelto lo que
  -- consumía la lista anterior de esta misma noche y planta.
  select p.name into v_missing
    from public.product p
    left join (
      select product_id, sum(quantity)::int as quantity
        from public.consumption
       where night_id = v_night_id
       group by product_id
    ) prev_cons on prev_cons.product_id = p.id
    left join (
      select (e->>'product_id')::bigint as product_id,
             sum((e->>'quantity')::int) as quantity
        from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
       where (e->>'quantity')::int > 0
       group by 1
    ) next_cons on next_cons.product_id = p.id
   where (prev_cons.product_id is not null or next_cons.product_id is not null)
     and p.unit_in_stock + coalesce(prev_cons.quantity, 0)
         < coalesce(next_cons.quantity, 0)
   limit 1;

  if v_missing is not null then
    raise exception 'Stock insuficiente para %', v_missing;
  end if;

  -- Devuelve al stock lo que tenía la lista anterior.
  update public.product p
     set unit_in_stock = p.unit_in_stock + o.quantity,
         updated_at = now()
    from (
      select product_id, sum(quantity)::int as quantity
        from public.consumption
       where night_id = v_night_id
       group by product_id
    ) o
   where p.id = o.product_id;

  delete from public.consumption where night_id = v_night_id;

  insert into public.consumption (night_id, product_id, quantity)
  select
    v_night_id,
    (e->>'product_id')::bigint,
    (e->>'quantity')::int
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
  where (e->>'quantity')::int > 0;

  -- Descuenta del stock la lista nueva.
  update public.product p
     set unit_in_stock = p.unit_in_stock - n.quantity,
         updated_at = now()
    from (
      select (e->>'product_id')::bigint as product_id,
             sum((e->>'quantity')::int) as quantity
        from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
       where (e->>'quantity')::int > 0
       group by 1
    ) n
   where p.id = n.product_id;
end $$;

-- ---------------------------------------------------------------------------
-- finalize_night: marca la jornada como finalizada sin tocar el consumo
-- ---------------------------------------------------------------------------

create or replace function public.finalize_night(
  p_date date,
  p_floor text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_floor text := coalesce(nullif(trim(p_floor), ''), 'planta_baja');
begin
  if public.current_profile_id() is null then
    raise exception 'Sesión no válida o cuenta desactivada';
  end if;
  if v_floor not in ('planta_baja', 'karaoke', 'terraza') then
    raise exception 'La planta no es válida';
  end if;

  update public.night
     set finalized_at = now()
   where date = p_date
     and floor = v_floor
     and finalized_at is null;
end $$;

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------

revoke all on function public.save_night(date, text, jsonb)
  from public, anon;
grant execute on function public.save_night(date, text, jsonb)
  to authenticated;

revoke all on function public.finalize_night(date, text)
  from public, anon;
grant execute on function public.finalize_night(date, text)
  to authenticated;

-- Comprobación: jornadas finalizadas y su lista guardada (informativo).
select n.date,
       n.floor,
       n.finalized_at,
       count(c.id) as lineas,
       coalesce(sum(c.quantity), 0) as botellines
from public.night n
left join public.consumption c on c.night_id = n.id
where n.finalized_at is not null
group by n.id, n.date, n.floor, n.finalized_at
order by n.date desc, n.floor;
