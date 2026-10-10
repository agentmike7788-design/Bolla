# Klangliste Phase 8 „Wer heraufkommt" – W-Ton (Gate G8, Runde 1)

Vertrag: `docs/PHASE8_DESIGN.md` §8.3 (Ton), §3.2 (Besitz W-Ton), §10 (`test_audio_phase8.gd`). Alle Klänge sind **prozedural synthetisiert** (`tools/audio/sfx_phase8.py`, Katalog in `tools/audio/build_audio.py`, fester Seed pro Datei). Es gibt keine Samples, keine Fremdaufnahmen und keine bekannten Melodien. Dateien: `assets/audio/<ordner>/ph_<id>[_n].wav` (Einzelklänge, Import als QOA) bzw. `.ogg` (Schleifen, Musik, Vorbis). Die Pegel sind über `target_lufs` eingestellt (G7 Runde 2): `volume_db` wird aus der gemessenen Lautheit der Dateien berechnet.

**Hörprobe:** `audio_preview_p8.ogg` (104 s, `python tools/audio/make_preview_p8.py`). Ablauf:
- 0–21 s Besuch am Grab: Schritte auf dem Kiesweg, Knien, ein Atemzug, Heidekraut, Aufstehen, Münzen vom Stein.
- 21–39 s Jakob harkt und gießt: Kreidetafel, Rechen im Takt, Hanne mit der Kiepe am Tor, Regenfass, Gießkanne, Pfeifen.
- 40–59 s Kathreintanz in der Gaststube.
- 59–77 s Lichtgang: gestrichene Töne, Zug auf dem Kies, Grabkerze, Handglocke 17:40.
- 77–97 s Nacht mit dem Grabräuber: gedämpfter Spaten, der Totengräber kommt näher, Flucht über den Kies, über die Mauer, Horn des Nachtwächters fern.
- 97–104 s Kapitel „Wer heraufkommt".

## Tests
`test_audio_phase8.gd` (23 Tests) plus die bestehenden Tests `test_audio.gd` und `test_audio_quality.gd` (29) sind grün. Die volle Suite: **2809 bestanden, 0 fehlgeschlagen** (Stand W1 2786 + 23).

## Neue Cues (28 Cues, 62 Dateien)

| Cue | Var. | Bus / Art | Auslöser (Daten) | Quelle · Reichweite | Ziel LUFS | Klang |
|---|---|---|---|---|---|---|
| `rake_leaves` | 3 | SFX | Jakob-Clip `rake` Takt 0,55 · Spieler „Laub harken" (alle 1,33 s) | Npc · 18 m | −33 | Rechen: Zinken setzen auf, kratzen, Laub raschelt mit |
| `weed_pull` | 3 | SFX | Jakob-Clip `weed` Takt 0,5 (≥ 2,3 s) · Spieler „Unkraut jäten", „Grabblumen setzen" | Npc · 16 m | −34 | Griff ins Kraut, Wurzel hält, reißt, Krumen fallen |
| `water_pour` | 3 | SFX | Jakob-Clip `water` Takt 0,05 · Spieler „Blumen gießen" | Npc · 16 m | −33 | Brause der Gießkanne auf Blättern und Erde, letzte Tropfen; 3 Varianten innerhalb von ±1,5 dB |
| `barrel_fill` | 2 | SFX | Spieler „Gießkanne füllen" (Regenfass) | 2D · 16 m | −32 | Eintauchen, Glucksen (steigt beim Vollaufen), Tropfen |
| `match_strike` | 2 | SFX | Jakob-Clip `candle` Takt 0,3 · Spieler „Grabkerze anzünden" | Npc · 12 m | −36 | Reiben, kleines Auflodern, leises Brennen, kein Zischen |
| `candle_glass` | 2 | SFX | `grave_care_changed@1=candle@2=true` | am Grab · 12 m | −36 | Blechscharnier, Glastür schließt, Laterne auf dem Stein |
| `broom_sweep` | 3 | SFX | Jakob-Clip `sweep` Takt 0,4 | Npc · 16 m | −37 | Reisigbesen auf dem Kiesweg vor der Hütte |
| `mortsafe_set` | 2 | SFX | Spieler „Grabgitter aufsetzen/abnehmen" | 2D · 24 m | −29 | Eisen auf Erde: dumpfer Schlag, zweiter kleiner Kontakt, Grus |
| `cloth_kneel` | 3 | SFX | Clip `kneel` Beginn/Ende, `lay_flowers` Beginn | Npc · 12 m | −49 | langer Rock/Mantel faltet sich, Knie weich auf Erde (6 dB unter den leisesten Schritten) |
| `flowers_lay` | 2 | SFX | Clip `lay_flowers` Takt 0,66 (Frame 30) · Spieler „Wachskranz legen" | Npc · 12 m | −49 | trockene Stängel, Heidekraut/Strohblumen, leises Ablegen |
| `mourn_breath` | 2 | SFX | Clip `kneel` (≥ 14 s, 50 %) / `mourn_stand` (≥ 16 s, 40 %) | Npc · 8 m | −52 | **angedeutet:** ein langsamer, stimmloser Atemzug (nur Luft, keine Tonhöhe, keine Stimme, kein Schluchzen) |
| `coins_stone` | 3 | SFX | `grave_care_changed@1=tip` (abgelegt / genommen); `payment_received@1=Trinkgeld` schweigt dafür | am Grab · 14 m | −33 | zwei, drei Münzen klicken auf Stein, kaum Nachklang |
| `chatter_murmur` | 3 | SFX | `chatter_line` (Begegnung) | am Sprecher · 12 m | −41 | zwei Stimmen als Formant-Luft in Silben, keine Wörter |
| `whistle_tune` | 3 | SFX | Jakob in `sweep`/`idle`/`walk`/`carry_can_walk`, `Apprentice.morale() ≥ 4`, Probe alle 6 s mit 35 %, höchstens alle 30 s | Npc · 22 m | −35 | drei eigene kurze Pfeif-Motive (D-Dur-Pentatonik, Gleiten, Vibrato) |
| `tin_cup` | 2 | SFX | `coins_spent@1=alms` (statt `coins`) | an Veit · 14 m | −31 | Münze in den Blechbecher, zwei, drei Hüpfer |
| `wage_tin` | 2 | SFX | `coins_spent@1=apprentice` (statt `coins`) | Lohndose · 14 m | −31 | drei Münzen in die Dose, Deckel schnappt |
| `kiepe_bells` | 1 | SFX · Schleife | Hanne (`peddler`) **geht** (ground_speed > 0) | folgt ihr · **12 m** | −34 | Glöckchen im Schritt (2/s), Weidenkorb knarrt; stoppt beim Stehen |
| `kiepe_set` | 2 | SFX | Clip `offer` Beginn/Ende (nur `peddler`) | Npc · 16 m | −31 | Kiepe absetzen/aufnehmen: Korbknarren, Aufsetzen, Glöckchen geschüttelt |
| `spade_night` | 3 | SFX | Clip `dig_night` Takt 0,2 (nur `robber`) | Npc · **25 m** | −32 | das Graben des Totengräbers, aber hastiger und gedämpft (Tiefpass 1,9 kHz), 5 dB leiser |
| `run_gravel` | 4 | SFX | Schritte des fliehenden Räubers (Flucht nach `robber_event@0=fled`) | Npc · 20 m | −40 | harte Ferse, Kiesspritzer |
| `climb_wall` | 2 | SFX | Flucht: einmal am Wegpunkt `robber_fence_in`/`_out` (≤ 1,6 m) | Npc · 22 m | −31 | Griff an den Stein, Stiefel kratzen, Stoff, Sprung auf der anderen Seite |
| `knock_door` | 2 | SFX | Clip `knock` Takt 0,1 (Nachtbesuch, Dorf) | Npc · 30 m | −29 | drei Schläge auf Eichentür, die Tür antwortet |
| `watchman_call` | 1 | SFX | `robber_event@0=caught` (Nachtwächter fängt ihn) | 2D, fern | −34 | Horn des Nachtwächters, zwei lange Töne aus dem Dorf (keine Stimme) |
| `chapter_who` | 1 | SFX | `chapter_completed@0=who_comes_up` | 2D | −27 | Kapitel „Wer heraufkommt": eine Linie, die Schritt für Schritt steigt, Pad öffnet sich von D nach G, darunter ein gestrichener Ton |
| `chalk_write` | 3 | UI | Panel `apprentice_board` öffnet | 2D | −38 | Kreide auf Schiefer: Ansetzen, drei, vier trockene Striche (kein Quietschen) |
| `amb_inn_fest` | 1 | Ambience · Schleife | Profil `inn_fest` (Kathreintanz läuft, Spieler in der Gaststube) | Raum | −34 | volle Stube ohne Wörter, Stampfen auf der Eins (Dreiertakt, 120 bpm, 30 s = 20 Takte), ab und zu Klatschen, Ofen |
| `mus_dance` | 1 | Music | Kontext `fest` | 2D | −29 | Kathreintanz: eigene Fiedel-Melodie im Dreiertakt (D-dorisch, 120 bpm, A–A′–B–A′–Coda), Bordun, Laute, die Stube klatscht auf zwei und drei |
| `mus_lights` | 1 | Music | Kontext `lights` (Lichtgang läuft, draußen Friedhof/Dorf) | 2D | −30 | Lichtgang: langsame gestrichene Akkorde in d-Moll, einzelne lange Töne darüber, ruhig, **kein Choral** |
| *Glocke* | – | bestehend | `fest_bells`: Lichtgang 17:40 (Minute 1060), 3 Schläge `small_bell` (Handglocke) | am Pfarrer, sonst 2D −12 dB | – | bestehender Klang |

Bestehende Klänge in Phase-8-Rollen: Besucher-Schritte = Npc-Schritte (Kiesweg = Fläche `stone`, ≤ 14 m, max. 3); `cloth` (Räuber schrickt auf, `robber_event@0=fled`; setzt sich, `sit_ground`); `remark` (Jakobs Sprechblase `chatter_line@0=apprentice`); `quill` (`wish_changed@1=accepted`, „Im Archiv helfen"), `ui_reward` (`wish_changed@1=done`, `friend_step_completed`, `favor_changed@2=returned`), `ui_notify` (`apprentice_level_changed`), `chisel` („nachmeißeln"), `dirt_pour` („Grab wieder schließen").

## Zuordnung als Daten
- **Animations-Takt** (`AudioConfig.npc_anim_cues`, `data/audio/audio_config.tres`): Clip → `cue` auf den `beats` (Anteil am Clip), `enter`/`leave`, `npcs`, `every`, `chance`, `height`. `AudioWorld` liest `AnimationPlayer.current_animation_position` der sichtbaren Npc ≤ 25 m (`npc_sound_range`). Wechsel weit weg werden nur vermerkt und klingen nicht beim ersten Sichtkontakt. Ein ruhender Clip (LOD 2) hat keinen Takt. Der Spieler nutzt weiter `AudioEvents.work_beat()` für Werkzeug-Clips mit `ToolAnimConfig.beat_cues`; seine Pflege-Handlungen klingen über `action_keywords` + `work_intervals` (Zyklus 1,33 s wie die Clips).
- **Ereignis an der Quelle** (`AudioConfig.positional_cues`): gleiche Schlüssel wie `signal_cues` (`signal@<arg>=<wert>`). `at` = `grave` | `npc` | `group`, optional `fallback_db` (2D, wenn die Quelle nicht da ist), `flee`.
- **Flucht** (`AudioConfig.flight`), **Pfeifen** (`whistle`), **Wanderer-Schleife** (`npc_walk_loops`), **Feste** (`fest_contexts`, `music_pauses`, `fest_bells`), Profil `data/audio/ambience/inn_fest.tres`, Musik `music_tracks.fest` / `.lights`.
- **Stichwörter** (`audio_events.tres`): `grabblumen`, `wachskranz`, `grabkerze`, `grabgitter`, `nachmeißeln`, `wieder schließen`, `gießkanne`, `gießen`, `archiv` stehen vor den G7-Wörtern (`setzen` → Hammer). `laub` → `rake_leaves`, `unkraut` → `weed_pull` (bisher `rustle`; der allgemeine Laubklang bleibt für Beeren, Flachs und das Räumen).

## Budget (§8.3, Web)
- **Stimmen-Pools unverändert** (12 × 2D, 10 × 3D, 4 × UI). Alle neuen Einzelklänge laufen über `Audio.play(id, pos)` aus dem 3D-Pool, mit Cooldown und `max_voices` je Cue.
- **Neue Emitter: höchstens 2 zugleich.** Das sind die Wanderer-Schleifen (`npc_loop_voices = 2`, nur Hanne hat eine), als `AudioStreamPlayer3D` einmal in `setup` angelegt. Keine festen Welt-Emitter sind dazugekommen. Beim Abspielen entsteht kein Knoten (Test).
- **Eine Musik zugleich:** Die Kontexte `fest` und `lights` ersetzen Dorf-, Tag- und Nachtmusik (`AudioManager.wanted_music`). `fest` hat 2–5 s Pause zwischen den Stücken, `lights` 4–14 s. Der Kathreintanz ersetzt das Gaststuben-Bett durch `inn_fest`.
- **Web unverändert:** ScriptProcessor, `output_latency.web = 150`, `default_playback_type.web = 0`. Einzelklänge sind WAV/QOA, Schleifen und Musik Vorbis. Neue Dateien: 7,8 MB WAV/OGG auf der Platte, davon 1,1 MB Vorbis.

## Abweichungen und Entscheidungen
1. **Lichtgang:** Der Auftrag nannte „leiser Choral-Pad“, der Vertrag §8.3 sagt „langsame, gestrichene Töne, ruhig, **kein Choral**“. Umgesetzt ist der Vertrag: Streicher, keine Stimmen.
2. **Seufzen:** „leises Seufzen angedeutet“ (Auftrag) gegen „kein Weinen, keine Stimme“ (Vertrag). Umgesetzt als `mourn_breath`: ein stimmloser Atemzug ohne Tonhöhe, −52 LUFS, selten (Zufall + Mindestabstand). Wenn das zu viel ist, reicht es, die beiden Einträge in `npc_anim_cues` zu entfernen.
3. **Klatschen** beim Kathreintanz ist Teil von `mus_dance` und `amb_inn_fest`. Ein eigener Klatsch-Klang am Clip `clap` würde gegen die Musik laufen.
4. **Nachtwächter-Ruf** ist ein Horn ohne Stimme. Es erklingt nur, wenn der Nachtwächter Lambert fängt (`robber_event@0=caught`).
5. **Begegnungs-Murmeln:** Die Blase zeigt den Text, der Ton bleibt abstrakt (`chatter_murmur`).

## Änderungen außerhalb der Besitz-Zeile (additiv, bitte durch den Lead bestätigen)
§3.2 nennt für W-Ton `audio_world.gd` und `audio_events.gd`. Für den Kontext `fest` und die Daten waren kleine Ergänzungen in Dateien nötig, die in Phase 8 niemand besitzt:
- `src/systems/audio/audio_config.gd`: Gruppe „Phase 8“ mit neuen `@export`s. Die Standardwerte sind leer, das G7-Verhalten bleibt gleich.
- `src/systems/audio/audio_manager.gd`: `wanted_music`/`wanted_profile` fragen zuerst `world.fest_context()`.
- `src/systems/audio/audio_music.gd`: Pausen je Kontext (`music_pauses`). Ohne Eintrag gilt das G7-Verhalten.
- Neu: `data/audio/ambience/inn_fest.tres`, `tools/audio/sfx_phase8.py`, `tools/audio/make_preview_p8.py`.
- `build_audio.py`: neue Option `--ids`. Eine Generator-Liste gibt jeder Variante ihre eigene Funktion (drei Pfeif-Motive).

## Anschlüsse für W-Welt / P-Pakete (Ton hängt daran, nichts zu ändern bei W-Ton)
- Npc-Ids bzw. Knotennamen: `apprentice`, `peddler`, `beggar`, `robber` (`npc_robber`), `priest`, `kin_*`. Der Ton erkennt `npc_id` oder den Knotennamen `npc_<id>`.
- Wegpunkte `robber_fence_in` / `robber_fence_out` (Mauer bei der Flucht). Die Gruppen `apprentice_box`, `festivals`, `apprentice` und `grave_plot` gibt es bereits.
- Optional (P5/Player-Besitzer): `ToolAnimConfig.beat_cues` + `bite_at` für den Totengräber-Clip `water` (→ `water_pour`). Dann gießt auch der Spieler genau im Takt statt im 1,33-s-Intervall.

## Lautheits-Tabelle (alle neuen Dateien, `tools/audio/analyze_audio.py`)
Einzelklänge: maximale Momentan-Lautheit (400 ms). Schleifen und Musik: integriert. „Lautheit im Spiel“ = Datei + `volume_db`, vor den Bus-Reglern des Spielers. Befund „ok“ heißt: kein Clipping, kein DC, kein Klick am Rand, keine Naht, nicht schrill, im Zielband ±3 dB.

| Datei | Bus | s | Peak dBFS | DC | LUFS Datei | Lautheit im Spiel | Ziel | 2–5 kHz | Spitze dB@Hz | Rauschboden | Ausklang s | Naht | Befund |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ph_rake_leaves_1.wav | SFX | 0.95 | -1.0 | -0.0000 | -13.6 | -33.5 | -36…-30 | 35 % | 6@7704 | -180 | 0.20 | 0.000 / 0.000 | ok |
| ph_rake_leaves_2.wav | SFX | 0.95 | -1.0 | -0.0000 | -12.5 | -32.4 | -36…-30 | 32 % | 5@2137 | -180 | 0.25 | 0.000 / 0.000 | ok |
| ph_rake_leaves_3.wav | SFX | 0.95 | -1.0 | -0.0000 | -13.2 | -33.1 | -36…-30 | 33 % | 5@576 | -90 | 0.21 | 0.000 / 0.000 | ok |
| ph_weed_pull_1.wav | SFX | 0.85 | -1.0 | -0.0000 | -15.9 | -33.1 | -37…-31 | 29 % | 9@829 | -36 | 0.06 | 0.000 / 0.000 | ok |
| ph_weed_pull_2.wav | SFX | 0.85 | -1.0 | -0.0000 | -17.1 | -34.3 | -37…-31 | 40 % | 9@603 | -40 | 0.11 | 0.000 / 0.000 | ok |
| ph_weed_pull_3.wav | SFX | 0.85 | -1.0 | -0.0000 | -17.7 | -34.9 | -37…-31 | 44 % | 7@5373 | -39 | 0.11 | 0.000 / 0.000 | ok |
| ph_water_pour_1.wav | SFX | 1.38 | -1.0 | -0.0000 | -12.7 | -32.9 | -36…-30 | 43 % | 4@657 | -40 | 0.05 | 0.000 / 0.000 | ok |
| ph_water_pour_2.wav | SFX | 1.45 | -1.0 | -0.0000 | -13.0 | -33.2 | -36…-30 | 42 % | 4@4920 | -40 | 0.04 | 0.000 / 0.000 | ok |
| ph_water_pour_3.wav | SFX | 1.31 | -1.0 | -0.0000 | -12.6 | -32.8 | -36…-30 | 44 % | 4@5125 | -39 | 0.08 | 0.000 / 0.000 | ok |
| ph_barrel_fill_1.wav | SFX | 1.90 | -1.0 | -0.0000 | -15.3 | -32.0 | -35…-29 | 3 % | 10@5093 | -85 | 0.17 | 0.000 / 0.000 | ok |
| ph_barrel_fill_2.wav | SFX | 1.90 | -1.0 | -0.0000 | -15.2 | -31.9 | -35…-29 | 3 % | 9@4021 | -85 | 0.17 | 0.000 / 0.000 | ok |
| ph_match_strike_1.wav | SFX | 1.15 | -1.0 | -0.0000 | -15.2 | -36.0 | -39…-33 | 33 % | 9@6169 | -40 | 0.16 | 0.000 / 0.000 | ok |
| ph_match_strike_2.wav | SFX | 1.15 | -1.0 | -0.0000 | -15.2 | -36.0 | -39…-33 | 36 % | 11@8290 | -41 | 0.11 | 0.000 / 0.000 | ok |
| ph_candle_glass_1.wav | SFX | 0.75 | -1.0 | -0.0000 | -17.6 | -36.1 | -39…-33 | 38 % | 25@2525 | -50 | 0.19 | 0.000 / 0.000 | ok |
| ph_candle_glass_2.wav | SFX | 0.75 | -1.0 | -0.0000 | -17.4 | -35.9 | -39…-33 | 39 % | 25@2379 | -49 | 0.18 | 0.000 / 0.000 | ok |
| ph_broom_sweep_1.wav | SFX | 0.80 | -1.0 | -0.0000 | -14.3 | -36.2 | -40…-34 | 27 % | 7@2358 | -93 | 0.16 | 0.000 / 0.000 | ok |
| ph_broom_sweep_2.wav | SFX | 0.80 | -1.0 | -0.0000 | -15.7 | -37.6 | -40…-34 | 27 % | 6@4990 | -93 | 0.16 | 0.000 / 0.000 | ok |
| ph_broom_sweep_3.wav | SFX | 0.80 | -1.0 | -0.0000 | -15.3 | -37.2 | -40…-34 | 27 % | 5@6557 | -92 | 0.16 | 0.000 / 0.000 | ok |
| ph_mortsafe_set_1.wav | SFX | 1.50 | -1.0 | -0.0000 | -13.1 | -28.3 | -32…-26 | 1 % | 28@404 | -59 | 0.29 | 0.000 / 0.000 | ok |
| ph_mortsafe_set_2.wav | SFX | 1.50 | -1.0 | -0.0000 | -14.6 | -29.8 | -32…-26 | 4 % | 27@1190 | -60 | 0.34 | 0.000 / 0.000 | ok |
| ph_cloth_kneel_1.wav | SFX | 0.90 | -1.0 | -0.0000 | -13.8 | -50.1 | -52…-46 | 35 % | 5@7655 | -104 | 0.20 | 0.000 / 0.000 | ok |
| ph_cloth_kneel_2.wav | SFX | 0.90 | -1.0 | -0.0000 | -12.4 | -48.7 | -52…-46 | 34 % | 6@8210 | -61 | 0.20 | 0.000 / 0.000 | ok |
| ph_cloth_kneel_3.wav | SFX | 0.90 | -1.0 | -0.0000 | -12.0 | -48.3 | -52…-46 | 35 % | 6@3558 | -48 | 0.19 | 0.000 / 0.000 | ok |
| ph_flowers_lay_1.wav | SFX | 0.85 | -1.0 | -0.0000 | -13.1 | -47.9 | -52…-46 | 29 % | 7@161 | -64 | 0.20 | 0.000 / 0.000 | ok |
| ph_flowers_lay_2.wav | SFX | 0.85 | -1.0 | -0.0000 | -15.7 | -50.5 | -52…-46 | 28 % | 7@2751 | -61 | 0.20 | 0.000 / 0.000 | ok |
| ph_mourn_breath_1.wav | SFX | 2.21 | -1.0 | -0.0000 | -13.4 | -51.5 | -55…-49 | 1 % | 5@2073 | -49 | 0.19 | 0.000 / 0.000 | ok |
| ph_mourn_breath_2.wav | SFX | 2.23 | -1.0 | -0.0000 | -14.4 | -52.5 | -55…-49 | 1 % | 4@8796 | -48 | 0.22 | 0.000 / 0.000 | ok |
| ph_coins_stone_1.wav | SFX | 0.85 | -1.0 | -0.0000 | -19.8 | -32.1 | -36…-30 | 44 % | 20@4091 | -180 | 0.35 | 0.000 / 0.000 | ok |
| ph_coins_stone_2.wav | SFX | 0.85 | -1.0 | -0.0000 | -21.4 | -33.7 | -36…-30 | 38 % | 20@4587 | -180 | 0.46 | 0.000 / 0.000 | ok |
| ph_coins_stone_3.wav | SFX | 0.85 | -1.0 | -0.0000 | -20.9 | -33.2 | -36…-30 | 45 % | 18@4167 | -180 | 0.49 | 0.000 / 0.000 | ok |
| ph_chatter_murmur_1.wav | SFX | 1.38 | -1.0 | -0.0000 | -16.4 | -39.9 | -44…-38 | 1 % | 6@3860 | -92 | 0.12 | 0.000 / 0.000 | ok |
| ph_chatter_murmur_2.wav | SFX | 1.30 | -1.0 | -0.0000 | -18.3 | -41.8 | -44…-38 | 1 % | 6@3273 | -93 | 0.10 | 0.000 / 0.000 | ok |
| ph_chatter_murmur_3.wav | SFX | 1.65 | -1.0 | -0.0000 | -18.0 | -41.5 | -44…-38 | 0 % | 5@5362 | -95 | 0.34 | 0.000 / 0.000 | ok |
| ph_whistle_tune_1.wav | SFX | 2.08 | -1.0 | -0.0000 | -8.5 | -34.8 | -38…-32 | 0 % | 30@872 | -30 | 0.09 | 0.000 / 0.000 | ok |
| ph_whistle_tune_2.wav | SFX | 1.84 | -1.0 | -0.0000 | -8.8 | -35.1 | -38…-32 | 0 % | 29@1012 | -26 | 0.09 | 0.000 / 0.000 | ok |
| ph_whistle_tune_3.wav | SFX | 2.08 | -1.0 | -0.0000 | -8.7 | -35.0 | -38…-32 | 0 % | 27@894 | -28 | 0.10 | 0.000 / 0.000 | ok |
| ph_tin_cup_1.wav | SFX | 0.90 | -1.0 | -0.0000 | -12.2 | -30.8 | -34…-28 | 28 % | 28@1776 | -46 | 0.14 | 0.000 / 0.000 | ok |
| ph_tin_cup_2.wav | SFX | 0.90 | -1.0 | -0.0000 | -12.7 | -31.3 | -34…-28 | 29 % | 28@1723 | -45 | 0.12 | 0.000 / 0.000 | ok |
| ph_wage_tin_1.wav | SFX | 1.30 | -1.0 | -0.0000 | -12.2 | -31.1 | -34…-28 | 31 % | 21@1319 | -46 | 0.21 | 0.000 / 0.000 | ok |
| ph_wage_tin_2.wav | SFX | 1.30 | -1.0 | -0.0000 | -12.0 | -30.9 | -34…-28 | 34 % | 25@1330 | -44 | 0.20 | 0.000 / 0.000 | ok |
| ph_kiepe_bells.ogg | SFX | 6.00 | -5.9 | -0.0000 | -21.2 | -34.0 | -37…-31 | 85 % | 28@3951 | -38 | 0.00 | 0.0 / 16.1 dB | ok |
| ph_kiepe_set_1.wav | SFX | 1.30 | -1.0 | -0.0000 | -13.2 | -30.2 | -34…-28 | 44 % | 26@8296 | -49 | 0.20 | 0.000 / 0.000 | ok |
| ph_kiepe_set_2.wav | SFX | 1.30 | -1.0 | -0.0000 | -15.0 | -32.0 | -34…-28 | 30 % | 28@3149 | -53 | 0.22 | 0.000 / 0.000 | ok |
| ph_spade_night_1.wav | SFX | 0.80 | -1.0 | -0.0000 | -21.4 | -32.7 | -35…-29 | 8 % | 8@6966 | -92 | 0.15 | 0.000 / 0.000 | ok |
| ph_spade_night_2.wav | SFX | 0.80 | -1.0 | -0.0000 | -20.7 | -32.0 | -35…-29 | 9 % | 7@248 | -72 | 0.16 | 0.000 / 0.000 | ok |
| ph_spade_night_3.wav | SFX | 0.80 | -1.0 | -0.0000 | -20.2 | -31.5 | -35…-29 | 9 % | 7@1798 | -71 | 0.10 | 0.000 / 0.000 | ok |
| ph_run_gravel_1.wav | SFX | 0.22 | -1.0 | -0.0000 | -23.1 | -41.1 | -43…-37 | 36 % | 10@813 | -38 | 0.07 | 0.000 / 0.000 | ok |
| ph_run_gravel_2.wav | SFX | 0.22 | -1.0 | -0.0000 | -21.8 | -39.8 | -43…-37 | 34 % | 10@4683 | -48 | 0.02 | 0.000 / 0.000 | ok |
| ph_run_gravel_3.wav | SFX | 0.22 | -1.0 | -0.0000 | -21.0 | -39.0 | -43…-37 | 31 % | 9@4554 | -46 | 0.06 | 0.000 / 0.000 | ok |
| ph_run_gravel_4.wav | SFX | 0.22 | -1.0 | -0.0000 | -22.5 | -40.5 | -43…-37 | 34 % | 11@6298 | -46 | 0.09 | 0.000 / 0.000 | ok |
| ph_climb_wall_1.wav | SFX | 1.90 | -1.0 | -0.0000 | -18.6 | -30.5 | -34…-28 | 38 % | 6@7574 | -61 | 0.32 | 0.000 / 0.000 | ok |
| ph_climb_wall_2.wav | SFX | 1.90 | -1.0 | -0.0000 | -19.6 | -31.5 | -34…-28 | 35 % | 5@242 | -56 | 0.24 | 0.000 / 0.000 | ok |
| ph_knock_door_1.wav | SFX | 1.20 | -1.0 | -0.0000 | -17.4 | -29.2 | -32…-26 | 0 % | 10@312 | -37 | 0.14 | 0.000 / 0.000 | ok |
| ph_knock_door_2.wav | SFX | 1.20 | -1.0 | -0.0000 | -16.9 | -28.7 | -32…-26 | 0 % | 8@388 | -40 | 0.11 | 0.000 / 0.000 | ok |
| ph_watchman_call.wav | SFX | 4.60 | -1.0 | -0.0000 | -7.0 | -34.0 | -37…-31 | 0 % | 54@194 | -34 | 0.25 | 0.000 / 0.000 | ok |
| ph_chapter_who.wav | SFX | 7.50 | -1.0 | -0.0000 | -11.4 | -27.0 | -30…-24 | 0 % | 36@991 | -38 | 0.32 | 0.000 / 0.000 | ok |
| ph_chalk_write_1.wav | UI | 0.90 | -1.0 | -0.0000 | -14.3 | -36.7 | -41…-35 | 31 % | 6@8484 | -92 | 0.39 | 0.000 / 0.000 | ok |
| ph_chalk_write_2.wav | UI | 0.90 | -1.0 | -0.0000 | -17.0 | -39.4 | -41…-35 | 31 % | 5@7101 | -43 | 0.13 | 0.000 / 0.000 | ok |
| ph_chalk_write_3.wav | UI | 0.90 | -1.0 | -0.0000 | -16.0 | -38.4 | -41…-35 | 27 % | 8@3138 | -91 | 0.38 | 0.000 / 0.000 | ok |
| ph_amb_inn_fest.ogg | Ambience | 30.00 | -6.0 | -0.0000 | -27.5 | -34.0 | -37…-31 | 2 % | 4@1004 | -31 | 0.00 | 0.0 / 2.2 dB | ok |
| ph_mus_dance.ogg | Music | 58.00 | -5.9 | +0.0000 | -19.5 | -29.0 | -32…-26 | 1 % | 33@879 | -22 | 2.87 | 0.000 / 0.000 | ok |
| ph_mus_lights.ogg | Music | 66.00 | -7.4 | -0.0000 | -19.8 | -30.0 | -33…-27 | 1 % | 30@586 | -24 | 2.31 | 0.000 / 0.000 | ok |
