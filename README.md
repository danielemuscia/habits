# Habits 🌱

App iOS minimale (stile Apple) per monitorare le abitudini. **Local-first**: i dati
vivono sul dispositivo con **SwiftData** e si sincronizzano in automatico sul tuo
**iCloud privato** via **CloudKit**. Nessun account da creare, nessun server.

- **Oggi** — vista giornaliera con le abitudini da spuntare (toggle o conteggio +/−).
- **Abitudini** — crea/modifica abitudini con frequenza target (N volte per giorno / settimana / mese / anno), icona e colore.
- **Analytics** — trend, streak corrente, record e tasso di completamento per ogni abitudine.

## Stack

| Livello   | Tecnologia                          |
|-----------|-------------------------------------|
| Frontend  | SwiftUI (iOS 17+), Swift Charts     |
| Storage   | SwiftData (locale)                  |
| Sync/Backup | CloudKit (DB privato iCloud dell'utente) |

Architettura: **MVVM**, local-first. I `ViewModel` (`@MainActor`, `ObservableObject`)
leggono/scrivono sullo store SwiftData (`ModelContext`) ed espongono lo stato alle `View`.
Nessuna dipendenza esterna: SwiftData e CloudKit sono framework di sistema.

```
Habits/
├─ HabitsApp.swift          # entry point + ModelContainer (CloudKit)
├─ Models/                  # Habit, HabitEntry (@Model), HabitPeriod, HabitProgress
├─ Services/                # Persistence (ModelContainer)
├─ ViewModels/              # Habits, Analytics
├─ Views/                   # Root, Today, Habits, Analytics, Components
├─ Theme/                   # colori, icone
└─ Resources/               # Info.plist, Assets.xcassets
project.yml                 # definizione progetto (XcodeGen)
```

## Setup

### 1. Abilita iCloud/CloudKit (una tantum, portale Apple)

La sync è opzionale per *usare* l'app (senza iCloud i dati restano in locale), ma per
backup e multi-device serve abilitarla:

- **Apple Developer** ([developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles): nell'App ID `com.danielemuscia.habits` abilita la capability **iCloud → CloudKit** e crea il container **`iCloud.com.danielemuscia.habits`**. In locale è già referenziato in `Habits/Habits.entitlements` (signing automatico col team `39ZSPD3CUW`).

### 2. Genera il progetto Xcode

Il progetto è definito in `project.yml` (XcodeGen) per restare leggero e riproducibile.

```bash
brew install xcodegen   # se non lo hai
xcodegen generate       # crea Habits.xcodeproj
open Habits.xcodeproj
```

Nessuna dipendenza Swift Package da risolvere.

### 3. Esegui

Seleziona un simulatore iOS 17+ e premi **Run**: l'app parte subito, senza login.
Per verificare la **sincronizzazione CloudKit** serve un **dispositivo reale loggato
su iCloud** (la sync sul simulatore è inaffidabile).

## Modello dati

Due `@Model` SwiftData (compatibili CloudKit: campi con default, nessun vincolo di
unicità — l'unicità per giorno è garantita in codice).

**Habit**
- `targetCount` + `period` (`daily`/`weekly`/`monthly`/`yearly`) = obiettivo, es. *3 volte a settimana*.
- `allowsMultiplePerDay` = se vera, l'abitudine si registra con un contatore +/− (più volte al giorno) anche con obiettivo settimanale/mensile; altrimenti è una spunta una volta al giorno.
- `icon` (SF Symbol), `color` (hex), `details`, `archived`, `sortOrder`.

**HabitEntry**
- Un record per `(habitId, entryDate)` con `count` = quante volte fatta quel giorno; `skipped` = giorno di riposo.
- L'avanzamento di periodo è la somma dei `count` nella finestra del periodo corrente.

Essendo nel database privato CloudKit, i dati sono per definizione visibili solo
all'utente proprietario dell'iCloud.

## Roadmap (post-MVP)

- Widget Home Screen (logging rapido)
- Notifiche/reminder locali
- Reorder drag&drop e archiviazione abitudini
