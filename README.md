# Open Scrobbler

Scrobbler nativo per macOS (SwiftUI) che rileva la musica in riproduzione e la
invia a **Last.fm**. App menu bar + finestra, con cronologia e coda offline.

## Come funziona il rilevamento

Da macOS 15.4 Apple ha bloccato l'API privata `MediaRemote` ai soli processi
Apple. Open Scrobbler usa
[mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter), che
aggira la restrizione eseguendo il framework tramite `/usr/bin/perl`
(bundle id `com.apple.perl5`, ancora autorizzato) **senza disabilitare SIP**.
Questo permette di rilevare qualsiasi player (Apple Music, Spotify, browser…).

Conseguenza: l'app dipende da un framework privato, quindi **non è
sandboxabile né distribuibile su Mac App Store**. La distribuzione avviene
tramite `.app` firmata e notarizzata (Developer ID).

## Requisiti

- macOS 14+
- Xcode 26+ (per eseguire la GUI e produrre il bundle `.app`)
- Un account API Last.fm

## 1. Chiavi API Last.fm

Crea un'app su <https://www.last.fm/api/account/create>. Otterrai una
**API key** e uno **shared secret**. Forniscili in uno dei due modi:

- variabili d'ambiente `LASTFM_API_KEY` e `LASTFM_API_SECRET` (impostate nello
  scheme di Xcode: *Edit Scheme → Run → Arguments → Environment Variables*), oppure
- modificando i valori di default in `Sources/OpenScrobbler/Scrobbling/LastfmConfig.swift`.

## 2. Eseguire

Build da riga di comando (verifica di compilazione):

```sh
swift build
```

Per eseguire la GUI apri il pacchetto in Xcode e premi Run:

```sh
open Package.swift
```

> L'esecuzione corretta di `MenuBarExtra`/finestra e di SwiftData richiede un
> bundle `.app`: usa Xcode (lo schema `OpenScrobbler`). Il binario prodotto da
> `swift build` serve solo a verificare la compilazione.

## 3. Accesso a Last.fm

In *Impostazioni* nella finestra principale:
1. **Apri Last.fm e autorizza** — apre il browser sulla pagina di
   autorizzazione dell'app.
2. Dopo aver autorizzato, **Ho autorizzato** — completa il login e salva la
   session key nel **Keychain**.

## Regole di scrobble

- `track.updateNowPlaying` a ogni cambio brano.
- `track.scrobble` quando il brano supera il **50% della durata o 4 minuti**
  (il minore), solo per brani > 30s. Un timer locale guida la soglia.
- Se l'invio fallisce (offline), lo scrobble resta in coda e viene ritentato
  (fino a 5 tentativi) al riavvio o allo scrobble successivo.

## Struttura

```
Sources/OpenScrobbler/
  OpenScrobblerApp.swift          entry point (MenuBarExtra + Window)
  AppState.swift                  coordinatore (auth, wiring)
  NowPlaying/
    TrackPlayback.swift           snapshot del brano corrente
    NowPlayingMonitor.swift       wrapper dell'adapter
  Scrobbling/
    LastfmConfig.swift            chiavi API
    LastfmClient.swift            API Last.fm + firma api_sig
    KeychainStore.swift           session key nel Keychain
    ScrobbleEngine.swift          regole now-playing/scrobble + coda
  Persistence/
    ScrobbleEntry.swift           modello SwiftData
    ScrobbleStore.swift           accesso/coda SwiftData
  UI/
    MainWindowView.swift, HistoryView.swift, SettingsView.swift, MenuBarView.swift
```

## Fuori scope (v1)

Editing metadati/blocco, statistiche e grafici, altri servizi
(ListenBrainz, Libre.fm, CSV/JSONL), Discord Rich Presence, notarizzazione/DMG.
