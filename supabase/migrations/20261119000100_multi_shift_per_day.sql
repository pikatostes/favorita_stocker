-- Permite que una persona tenga más de un turno en la misma noche cuando no
-- se solapan (por ejemplo, 17:00–20:00 y 21:00–03:00).
--
-- La validación de solapes se hace en la app al asignar personas desde
-- Horario. La base de datos deja de imponer un único turno por persona y día,
-- pero mantiene un índice para las consultas por persona/fecha.
alter table public.shift
  drop constraint if exists shift_user_id_date_key;

create index if not exists idx_shift_user_date
  on public.shift (user_id, date);
