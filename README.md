# Habits 🌱

App iOS minimale (stile Apple) per monitorare le abitudini, con backend in cloud su **Supabase**.

- **Oggi** — vista giornaliera con le abitudini da spuntare (toggle o conteggio +/−).
- **Abitudini** — crea/modifica abitudini con frequenza target (N volte per giorno / settimana / mese / anno), icona e colore.
- **Analytics** — trend, streak corrente, record e tasso di completamento per ogni abitudine.
- **Account** — login/registrazione via email; ogni utente vede solo i propri dati (Row Level Security).

## Stack

| Livello   | Tecnologia                          |
|-----------|-------------------------------------|
| Frontend  | SwiftUI (iOS 17+), Swift Charts     |
| Backend   | Supabase (Postgres + Auth + REST)   |
| SDK       | [supabase-swift](https://github.com/supabase/supabase-swift) 2.x |

Architettura: **MVVM**. I `Service` parlano con Supabase, i `ViewModel` (`@MainActor`, `ObservableObject`) espongono lo stato alle `View`.

```
Habits/
├─ HabitsApp.swift          # entry point
├─ Config/                  # configurazione Supabase + xcconfig
├─ Models/                  # Habit, HabitEntry, HabitPeriod, HabitProgress
├─ Services/                # SupabaseManager, AuthService, HabitService
├─ ViewModels/              # Auth, Habits, Analytics
├─ Views/                   # Root, Auth, Today, Habits, Analytics, Components
├─ Theme/                   # colori, icone
└─ Resources/               # Info.plist, Assets.xcassets
supabase/migrations/        # schema SQL
project.yml                 # definizione progetto (XcodeGen)
```

## Setup

### 1. Crea il progetto Supabase

1. Vai su [supabase.com](https://supabase.com) e crea un nuovo progetto.
2. Apri **SQL Editor** e incolla/esegui in ordine i file in [`supabase/migrations/`](supabase/migrations/): `0001_init.sql` (tabelle `habits`/`habit_entries` + policy RLS), `0002_rest_days.sql` (giorni di riposo) e `0003_multiple_per_day.sql` (più completamenti al giorno).
3. (Opzionale ma comodo in sviluppo) **Authentication → Providers → Email**: disattiva *Confirm email* così la registrazione logga subito l'utente senza passare dalla mail.
4. Da **Project Settings → API** copia **Project URL** e **anon public key**.

### 2. Configura i secret

```bash
cp Habits/Config/Secrets.example.xcconfig Habits/Config/Secrets.xcconfig
```

Apri `Secrets.xcconfig` e inserisci i tuoi valori (l'URL **senza** `https://`):

```
SUPABASE_URL = your-project-ref.supabase.co
SUPABASE_ANON_KEY = your-anon-public-key
```

> `Secrets.xcconfig` è in `.gitignore`: non verrà committato.

### 3. Genera il progetto Xcode

Il progetto è definito in `project.yml` (XcodeGen) per restare leggero e riproducibile.

```bash
brew install xcodegen   # se non lo hai
xcodegen generate       # crea Habits.xcodeproj
open Habits.xcodeproj
```

Xcode risolverà automaticamente la dipendenza Swift Package `supabase-swift`.

> Niente XcodeGen? Puoi creare manualmente un progetto App iOS, trascinare la cartella `Habits/`, aggiungere il package `https://github.com/supabase/supabase-swift`, impostare `Base.xcconfig` come configuration file e `Resources/Info.plist` come Info.plist del target.

### 4. Esegui

Seleziona un simulatore iOS 17+ e premi **Run**. Registra un account e inizia ad aggiungere abitudini.

## Modello dati

**habits**
- `target_count` + `period` (`daily`/`weekly`/`monthly`/`yearly`) = obiettivo, es. *3 volte a settimana*.
- `allows_multiple_per_day` = se vera, l'abitudine si registra con un contatore +/− (più volte al giorno) anche con obiettivo settimanale/mensile; altrimenti è una spunta una volta al giorno.
- `icon` (SF Symbol), `color` (hex), `archived`, `sort_order`.

**habit_entries**
- Un record per `(habit_id, entry_date)` con `count` = quante volte fatta quel giorno.
- L'avanzamento di periodo è la somma dei `count` nella finestra del periodo corrente.

Entrambe le tabelle hanno RLS: ogni riga è filtrata per `user_id = auth.uid()`.

## Roadmap (post-MVP)

- Notifiche/reminder locali
- Sync realtime (Supabase Realtime)
- Widget e Live Activities
- Reorder drag&drop e archiviazione abitudini
- Accesso con Apple
