# 🎵 Melody Flow

A clean, minimal, ad-free offline music player for Android — built with Flutter to compete head-on with Oto Music. **Paid app ($1), 100% ad-free forever, fully accessible after one-time purchase.**

---

## 🎯 Positioning vs. Oto Music

| Dimension              | Oto Music (free + Oto+ paywall) | **Melody Flow (paid $1)**        |
| ---------------------- | ------------------------------- | -------------------------------- |
| Ads                    | Yes (free tier)                 | **Never**                        |
| Paywalled features     | Material You, 10-band EQ, themes | **Everything unlocked from day 1** |
| Price                  | Free + $5–10 Oto+               | **$1 once, forever**             |
| Engine                 | Native Android (Java/Kotlin)    | Flutter (cross-platform ready)   |
| Clean UI philosophy    | ✅                              | ✅ + distraction-free defaults    |

**Core pitch:** "One dollar. No ads, no subscriptions, every feature unlocked." That's the whole story on the store listing.

---

## 🏗️ Architecture

Clean-ish three-layer architecture with Riverpod for state:

```
lib/
├── core/
│   ├── theme/          app_colors.dart, app_theme.dart
│   ├── constants/
│   ├── utils/
│   └── router/
├── data/
│   ├── models/         song, playlist, play_stats, app_settings (+ Hive adapters)
│   ├── services/       audio_handler, library_service, storage_service
│   └── repositories/
├── presentation/
│   ├── providers/      app_providers.dart (Riverpod)
│   ├── screens/        home, library, now_playing, playlists,
│   │                   settings, search, equalizer, onboarding
│   └── widgets/        song_tile, mini_player
└── main.dart           entry point + audio_service boot
```

**Why these choices:**

- **just_audio + audio_service** — the de-facto stack for Flutter music apps. Gives gapless, notification, lock screen, Bluetooth headset, Android Auto, and Chromecast basically for free.
- **on_audio_query** — native MediaStore bridge. Fetches songs, albums, artists, genres, artwork without us rebuilding indexing.
- **Riverpod** — compile-safe, testable state. Scales from 1 screen to 50.
- **Hive** — faster than SQLite for key-value (playlists, stats, settings), no SQL boilerplate.
- **palette_generator** — dynamic Now Playing background from album art.
- **flutter_lyric** — synced + plain `.lrc` rendering.

---

## ✅ Features — v1.0 (what we built)

**Playback engine**
- [x] Gapless playback
- [x] Crossfade (0–12 s, configurable)
- [x] Fade in / fade out on pause/resume
- [x] Shuffle, Repeat (none / one / all)
- [x] Play next / Add to queue
- [x] Playback speed (0.5×–2×)
- [x] Reorderable queue with swipe-to-remove
- [x] Sleep timer (presets + custom, finish-current-track mode)
- [x] Background playback with media-style notification
- [x] Lock screen + Bluetooth headset controls
- [x] "Skip back to start if >3 s in" smart previous behavior
- [x] Android Auto descriptor in place
- [x] 10-band equalizer + loudness enhancer

**Library**
- [x] Full MediaStore scan (Songs / Albums / Artists / Genres / Folders)
- [x] Permission flow (READ_MEDIA_AUDIO on Android 13+, storage fallback)
- [x] Multiple sorts (title, artist, album, date added, duration)
- [x] Min-track-length filter (hides ringtones)
- [x] Excluded-folders setting
- [x] Artist / genre custom separators

**Playlists & stats**
- [x] Custom playlists (create, rename, delete, reorder)
- [x] Smart playlists: **Favorites**, **Most Played**, **Recently Played**, **Recently Added**
- [x] Per-song play count + last-played timestamp
- [x] Favorite toggle

**UI / UX**
- [x] Light / Dark / AMOLED / System themes
- [x] 8 accent color presets + Material You toggle
- [x] Dynamic Now Playing background from album art
- [x] Persistent mini player with progress bar
- [x] Full-screen Now Playing with artwork, seek bar, lyrics toggle
- [x] Draggable queue sheet
- [x] Instant search across songs / artists / albums
- [x] Onboarding screen with value prop
- [x] Curated Home (quick picks, recently played, most played, recently added)

**Lyrics**
- [x] `flutter_lyric` synced LRC rendering
- [x] Position-tracked highlight
- [ ] Tag reader for embedded USLT lyrics *(see enhancements)*
- [ ] `.lrc` file auto-lookup next to audio *(see enhancements)*

---

## 🚀 2-Day Build Plan

### Day 1 — Boot & Core

**Morning (3 h)**
1. `flutter create . --org com.melodyflow --project-name melody_flow` inside this folder to generate iOS/Android native bits you don't have yet (run **without deleting** the `android/app/src/main/AndroidManifest.xml` we wrote — answer "n" if prompted).
2. Replace the generated `pubspec.yaml` with ours. Run `flutter pub get`.
3. Drop a 1024×1024 app icon into `assets/icons/app_icon.png`. Run `dart run flutter_launcher_icons` + `dart run flutter_native_splash:create`.
4. `flutter run` on a real device (audio services don't work on emulators reliably).

**Afternoon (4 h)**
5. Grant permission, confirm library loads.
6. Play a song end-to-end. Fix any path/URI issues.
7. Verify background notification, headset pause/play, sleep timer.
8. Test equalizer in Now Playing → EQ.

### Day 2 — Polish & Publish

**Morning (4 h)**
1. Create proper icon set (light + dark adaptive, monochrome for themed icons).
2. Create Play Store screenshots (see checklist below).
3. Fix obvious UI edges: RTL layouts, tiny-screen overflow, dark-mode contrast.
4. Generate signed release keystore:
   ```bash
   keytool -genkey -v -keystore ~/melody-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
5. Wire `android/key.properties` + signing config in `android/app/build.gradle`.

**Afternoon (4 h)**
6. `flutter build appbundle --release`
7. Test the release AAB on a physical device via `bundletool`.
8. Upload to Play Console → Internal testing track → promote to Production.
9. Fill out store listing (see below).
10. Submit for review.

---

## 🛒 Play Store Listing Blueprint

**Title:** `Melody Flow — Ad-Free Music Player`
**Short description (80 chars):**
`Clean, minimal, ad-free offline music player. One dollar. Everything unlocked.`

**Full description (paste this):**
```
Melody Flow is the music player that respects you.

✓ Zero ads, ever — not now, not after update 20
✓ Zero subscriptions — one $1 purchase unlocks everything, forever
✓ Works 100% offline — your library, your rules
✓ Built for people who love music, not menus

FEATURES
• Gapless playback with optional crossfade
• 10-band equalizer + loudness enhancer
• Synced lyrics support (.lrc)
• Sleep timer with "finish current track" mode
• Smart playlists: Favorites, Most Played, Recently Added
• Light / Dark / AMOLED themes + Material You on Android 12+
• Dynamic Now Playing colors from album art
• Android Auto support
• Background playback with headset & lock screen controls
• Reorderable play queue
• Multiple sorts & folder view
• No internet permission required for playback

Your music. Your player. No noise.
```

**Screenshots needed (1080×1920, 6 frames minimum):**
1. Home screen with curated rows
2. Now Playing with artwork + dynamic color
3. Library → Albums grid
4. Equalizer with bands raised
5. Playlists screen showing smart + custom
6. Settings → Appearance (showing themes + accents)

**Graphic assets:** 512×512 app icon + 1024×500 feature graphic.

**Content rating:** Everyone
**Category:** Music & Audio
**Pricing:** $1.00 USD (Play Console auto-converts to ₹84, €0.99, etc.)

---

## ⚡ Enhancements to Beat Oto Music (v1.1 → v1.3 roadmap)

These are what I'd build next to earn 5-star reviews and not-just-another-Oto-clone reputation:

### v1.1 — Polish release (week after launch)
- **Tag editor** — edit title/artist/album/genre/year using the `audiotags` package. Oto paywalls this; we give it free.
- **Lyrics auto-download** — hit `https://api.lyrics.ovh/v1/{artist}/{title}` (free, no key). Save to `.lrc` next to audio. Musixmatch as fallback if user adds key.
- **Embedded lyrics reader** — parse ID3 `USLT` frame and `.lrc` sidecar via `id3tag` or `audiotags`.
- **Folder-specific blacklist UI** — matches Oto's "Excluded folders" screen.
- **Share song / playlist** — `share_plus` to share a track or an exported `.m3u`.
- **Multi-select mode** — long-press any tile to bulk add to playlist / delete / share.
- **Playlist import/export** — `.m3u`, `.m3u8`, JSON.
- **Backup & restore** — single ZIP to Google Drive via `in_app_purchase`-gated tier or free (decide business-side).

### v1.2 — Differentiators
- **Home-screen widgets** — use `home_widget` package. Oto's widgets are the most-praised feature in reviews; we should match with a 2×2, 4×2, and 4×4.
- **Waveform seek bar** — `flutter_audio_waveforms` renders the actual waveform on the seek slider. Instant wow-factor.
- **Quick-action FAB gesture** — pull up mini-player to expand, swipe left/right to skip (we wired the hooks; activate with `GestureDetector`).
- **Smart crossfade** — detect silent ends and auto-mix only when appropriate (DJ-mode).
- **Skipped-song learning** — songs skipped within 10 s twice auto-drop from smart playlists.
- **Podcast mode** — per-episode resume position, 1.25× default speed.
- **Chromecast** — finish wiring `flutter_cast_framework` with a proper picker UI in Now Playing → cast button.
- **Android 14 themed app icon** — monochrome drawable.

### v1.3 — Power users
- **Plug-in equalizer presets** — ship with "Flat, Bass Boost, Treble Boost, Vocal, Classical, Rock, Pop, Jazz, Electronic, Podcast" presets.
- **A-B loop** — tap to mark start, tap to mark end, loop that section. Killer feature for musicians learning songs.
- **Pitch shift independent of speed** — already in the handler (`setPitch`), expose UI.
- **MP3-gain style replay-gain scanner** — scan library once, store per-track gain in Hive.
- **Scrobbling** — Last.fm / ListenBrainz endpoints.
- **Android Auto browsable catalog** — implement `loadChildren()` to expose Playlists, Albums, Artists tabs in the car.
- **CarPlay** — trivially enabled since audio_service supports it; needs entitlement on iOS if you ship there.
- **Offline lyrics timing editor** — user can nudge timestamps ±100 ms per line.
- **Sleep timer "fade out over last 30 s"** — gentle exit, not an abrupt cut.

### Moonshot ideas (v2)
- **Auto-mix / endless mode** — pick a seed song, build a 50-track queue from library based on BPM, key (via `flutter_audio_toolkit`), and listen history.
- **Mood detection** — cluster library into moods using playback time-of-day stats.
- **iPod-style click-wheel skin** — nostalgia Now Playing theme.
- **Voice command** — "play something energetic" via on-device whisper-tiny.

---

## 🧾 Commands Cheat Sheet

```bash
# First-time setup (inside this folder)
flutter create . --org com.melodyflow --project-name melody_flow
flutter pub get

# (Optional) if you delete the hand-written .g.dart files, regenerate:
dart run build_runner build --delete-conflicting-outputs

# Icons + splash
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# Run on device
flutter run --release

# Ship it
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab goes to Play Console
```

---

## 📦 Files Built So Far

```
pubspec.yaml
android/app/build.gradle
android/app/proguard-rules.pro
android/app/src/main/AndroidManifest.xml
android/app/src/main/res/xml/automotive_app_desc.xml

lib/main.dart
lib/core/theme/app_colors.dart
lib/core/theme/app_theme.dart

lib/data/models/song.dart            (+ song.g.dart)
lib/data/models/playlist.dart        (+ playlist.g.dart)
lib/data/models/play_stats.dart      (+ play_stats.g.dart)
lib/data/models/app_settings.dart    (+ app_settings.g.dart)

lib/data/services/audio_handler.dart
lib/data/services/library_service.dart
lib/data/services/storage_service.dart

lib/presentation/providers/app_providers.dart

lib/presentation/widgets/song_tile.dart
lib/presentation/widgets/mini_player.dart

lib/presentation/screens/onboarding/onboarding_screen.dart
lib/presentation/screens/home/home_shell.dart
lib/presentation/screens/home/home_screen.dart
lib/presentation/screens/library/library_screen.dart
lib/presentation/screens/playlists/playlists_screen.dart
lib/presentation/screens/playlists/playlist_detail_screen.dart
lib/presentation/screens/now_playing/now_playing_screen.dart
lib/presentation/screens/now_playing/lyrics_panel.dart
lib/presentation/screens/now_playing/queue_sheet.dart
lib/presentation/screens/equalizer/equalizer_screen.dart
lib/presentation/screens/settings/settings_screen.dart
lib/presentation/screens/search/search_screen.dart
```

---

## 🔥 Known TODOs (placeholders in code)

- Tag editor sheet in `SongTile` and Now Playing → "more" sheet — currently navigates but doesn't edit (hook up `audiotags` package).
- Chromecast picker — icon is wired, SnackBar placeholder shown (finish `flutter_cast_framework`).
- Playlist export `.m3u` — menu present, not implemented.
- Excluded folders picker UI — setting exists, UI placeholder.
- Artist/genre separator input dialog — setting exists, UI placeholder.
- Home-screen widgets — package imported, widgets not yet built.
- LyricsPanel — currently shows a demo `.lrc`; wire real-file lookup + lyrics.ovh download.

All of these are clearly marked with `// TODO` or `// placeholder` in the source. A sharp afternoon of work knocks them out.

---

## 💸 Revenue realism

Oto has ~6M downloads but a lot of negative reviews mention the paywall. At $1 with no ads and no paywalls, the pitch writes itself — but $1 music players are a **crowded** category on Play Store. Plan for:

- **Organic growth via ASO** — hammer keywords: "offline music player", "ad free music", "MP3 player", "equalizer music player", "local music".
- **Reddit launches** — r/androidapps, r/androidgaming (cars/long sessions), r/DataHoarder, r/musicplayers.
- **Product Hunt launch** — a Flutter OSS-feeling paid app does well there.
- **Refund policy clarity** — Play Store gives 2-hour refunds anyway, but say it loud: "Not happy? Refund in one tap."

Aim for 1,000 installs in month 1 as a success signal. 10,000 = profitable side income. 100,000 = you've won.

Now go ship it. 🚀
