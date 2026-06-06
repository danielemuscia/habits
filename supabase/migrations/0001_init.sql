-- Habits MVP — schema iniziale
-- Esegui questo file nel SQL Editor di Supabase (o via `supabase db push`).
--
-- Modello dati:
--   habits          -> definizione di un'abitudine (nome, frequenza target)
--   habit_entries   -> log giornaliero (quante volte fatta in una certa data)
--
-- Sicurezza: Row Level Security attiva su entrambe le tabelle.
-- Ogni utente vede/modifica solo le proprie righe (user_id = auth.uid()).

-- ---------------------------------------------------------------------------
-- Enum della periodicità
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'habit_period') then
    create type public.habit_period as enum ('daily', 'weekly', 'monthly', 'yearly');
  end if;
end$$;

-- ---------------------------------------------------------------------------
-- Tabella: habits
-- ---------------------------------------------------------------------------
create table if not exists public.habits (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  name          text not null,
  description   text,
  icon          text not null default 'star.fill',   -- SF Symbol name
  color         text not null default '#34C759',      -- hex
  target_count  integer not null default 1 check (target_count > 0),
  period        public.habit_period not null default 'daily',
  sort_order    integer not null default 0,
  archived      boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists habits_user_id_idx on public.habits (user_id);

-- ---------------------------------------------------------------------------
-- Tabella: habit_entries (log giornaliero)
-- ---------------------------------------------------------------------------
create table if not exists public.habit_entries (
  id          uuid primary key default gen_random_uuid(),
  habit_id    uuid not null references public.habits (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  entry_date  date not null default current_date,
  count       integer not null default 1 check (count >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (habit_id, entry_date)
);

create index if not exists habit_entries_user_id_idx on public.habit_entries (user_id);
create index if not exists habit_entries_habit_date_idx on public.habit_entries (habit_id, entry_date);

-- ---------------------------------------------------------------------------
-- Trigger: mantieni updated_at aggiornato
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists habits_set_updated_at on public.habits;
create trigger habits_set_updated_at
  before update on public.habits
  for each row execute function public.set_updated_at();

drop trigger if exists habit_entries_set_updated_at on public.habit_entries;
create trigger habit_entries_set_updated_at
  before update on public.habit_entries
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.habits enable row level security;
alter table public.habit_entries enable row level security;

-- habits policies
drop policy if exists "habits_select_own" on public.habits;
create policy "habits_select_own" on public.habits
  for select using (auth.uid() = user_id);

drop policy if exists "habits_insert_own" on public.habits;
create policy "habits_insert_own" on public.habits
  for insert with check (auth.uid() = user_id);

drop policy if exists "habits_update_own" on public.habits;
create policy "habits_update_own" on public.habits
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "habits_delete_own" on public.habits;
create policy "habits_delete_own" on public.habits
  for delete using (auth.uid() = user_id);

-- habit_entries policies
drop policy if exists "entries_select_own" on public.habit_entries;
create policy "entries_select_own" on public.habit_entries
  for select using (auth.uid() = user_id);

drop policy if exists "entries_insert_own" on public.habit_entries;
create policy "entries_insert_own" on public.habit_entries
  for insert with check (auth.uid() = user_id);

drop policy if exists "entries_update_own" on public.habit_entries;
create policy "entries_update_own" on public.habit_entries
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "entries_delete_own" on public.habit_entries;
create policy "entries_delete_own" on public.habit_entries
  for delete using (auth.uid() = user_id);
