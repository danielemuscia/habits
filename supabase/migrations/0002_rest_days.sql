-- Giorno di riposo
-- ---------------------------------------------------------------------------
-- Aggiunge uno stato "saltato di proposito" al log giornaliero.
-- Una entry con skipped = true è uno stato NEUTRO: non conta come fatto
-- (count resta 0) né come mancato. Negli analytics non rompe la streak e
-- viene esclusa dal denominatore del completamento.
--
-- Esegui nel SQL Editor di Supabase (o via `supabase db push`).

alter table public.habit_entries
  add column if not exists skipped boolean not null default false;
