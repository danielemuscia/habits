-- Più completamenti al giorno
-- ---------------------------------------------------------------------------
-- Permette di registrare un'abitudine più volte nello stesso giorno anche
-- quando l'obiettivo è su un periodo più ampio (es. "5 volte a settimana",
-- registrando 2 sessioni oggi).
--
-- Il backend somma già `count` sull'intero periodo: questo flag controlla solo
-- il tipo di controllo mostrato nella vista Today (contatore +/- al posto della
-- spunta on/off). Default false = comportamento attuale (spunta una volta al
-- giorno per le abitudini non giornaliere).
--
-- Esegui nel SQL Editor di Supabase (o via `supabase db push`).

alter table public.habits
  add column if not exists allows_multiple_per_day boolean not null default false;
