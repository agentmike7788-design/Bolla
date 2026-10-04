# Klangliste – Gate G7, Änderungsrunde 1 + Runde 2 (Audio)

Alle Klänge sind **prozedural synthetisiert** (`tools/audio/build_audio.py`, numpy/scipy, fester Seed pro Datei) – keine Samples, keine Fremdaufnahmen. Dateien: `assets/audio/<ordner>/ph_<id>[_n].wav` (Einzelklänge, in Godot als QOA importiert) bzw. `.ogg` (Schleifen, Musik; Placeholder-Präfix) – seit Runde 2, Zuordnung `data/audio/cues_*.tres`, Ereignisse `data/audio/audio_events.tres`, Atmosphären `data/audio/ambience/*.tres`, Regeln `data/audio/audio_config.tres`.

Hörprobe Runde 2: **`audio_preview_v2.ogg`** (129 s, gleiche Abfolge + 20 s Friedhof-Wind draußen am Tag und 20 s in der Nacht, ohne Spots). Alte Hörprobe: `audio_preview.ogg` (88 s): Friedhof Tag mit Vögeln und Schritten im Gras → Graben, Leiche ablegen, Erde schütten, Stein setzen → Tor, Weg ins Dorf (Anger, Hühner, Schmied, Bach, Kirchenglocke, Pflasterschritte, Gerede-Blase) → Gaststube (Tür, Dielen, Becher, Münzen) → Nacht auf dem Friedhof (Grillen, Eule, Geist erscheint, Geist zufrieden) → Musik-Ausschnitt „Nacht“.

## Atmosphäre

| Cue | Varianten | Länge | Bus | Verwendung |
|---|---|---|---|---|
| `amb_graveyard_day` | 1 | 48.0 s | Ambience · Schleife | Friedhof Tag: Wind mit unregelmäßigen Böen (drei Bänder, kein Pfeifen), Laub nur in den Böen (+ Vögel, Krähe als Spots) |
| `amb_graveyard_dusk` | 1 | 48.0 s | Ambience · Schleife | Friedhof Dämmerung/Morgen: leiser Wind, erste Grillen |
| `amb_graveyard_night` | 1 | 48.0 s | Ambience · Schleife | Friedhof Nacht: Grillen, leiser Wind (+ Eule) |
| `amb_forest_edge` | 1 | 48.0 s | Ambience · Schleife | Wald-Rand (Holunderwinkel, Westrand): Blätterrauschen, Ästeknarren |
| `amb_village_day` | 1 | 48.0 s | Ambience · Schleife | Dorf Tag: fernes abstraktes Stimmengemurmel, Bach, Wind (+ Hühner, Schmied fern) |
| `amb_village_night` | 1 | 48.0 s | Ambience · Schleife | Dorf Nacht: Grillen, Bach, Wind (+ Eule) |
| `amb_hut` | 1 | 24.0 s | Ambience · Schleife | Hütte: Ofen knistert, Raumton |
| `amb_inn` | 1 | 24.0 s | Ambience · Schleife | Gaststube: Gemurmel, Ofen (+ Becher) |
| `amb_surgery` | 1 | 24.0 s | Ambience · Schleife | Wundarztstube: stiller Raum (+ Blättern, Glas) |
| `amb_office` | 1 | 24.0 s | Ambience · Schleife | Amtsstube: Uhr tickt |
| `amb_chapel` | 1 | 24.0 s | Ambience · Schleife | Kapelle: Hall, Luft, leises Summen (+ seltene Tropfen) |
| `amb_crypt` | 1 | 24.0 s | Ambience · Schleife | Gruft: tiefer Raumton, Tropfen im Hall |
| `amb_shed` | 1 | 24.0 s | Ambience · Schleife | Lagerschuppen: Wind an den Brettern (+ Knarren) |
| `amb_title` | 1 | 48.0 s | Ambience · Schleife | Titelbildschirm: Nachtwind, ferne Grillen |
| `loop_brook` | 1 | 12.0 s | Ambience · Schleife · positional | Hollerbach (3 positionale Quellen am Westrand des Dorfs) |
| `loop_forge` | 1 | 10.0 s | Ambience · Schleife · positional | Esse der Schmiede (positional, 7–19 Uhr) |
| `bird_a` | 2 | 1.6 s | Ambience | Spot: Vogel-Triller |
| `bird_b` | 2 | 1.9 s | Ambience | Spot: Vogel-Zweiton |
| `bird_c` | 2 | 2.1 s | Ambience | Spot: Vogel-Gezwitscher |
| `crow` | 2 | 2.6 s | Ambience | Spot: ferne Krähe |
| `owl` | 2 | 4.8 s | Ambience | Spot: Waldkauz-Ruf |
| `owl_short` | 1 | 2.5 s | Ambience | Spot: kurzer Eulenruf |
| `chicken` | 3 | 1.9 s | Ambience | Spot: Hühner (an den Katen, positional) |
| `hammer_far` | 2 | 2.6 s | Ambience | Spot: Schmied fern |
| `cup_clink` | 3 | 0.6 s | Ambience | Spot: Becher (Gaststube) |
| `drip_spot` | 3 | 2.1 s | Ambience | Spot: Tropfen (Gruft, Kapelle) |
| `wood_creak` | 2 | 1.4 s | Ambience | Spot: Holz knarrt |
| `page_turn_far` | 1 | 0.5 s | Ambience | Spot: Blättern (Amts-/Wundarztstube) |
| `fire_pop` | 2 | 0.1 s | Ambience | Spot: Ofen knackt |
| `wind_gust` | 2 | 5.5 s | Ambience | Spot: Windböe (ein Böen-Schwall, ohne Rauschkörner) |

## Musik

| Cue | Varianten | Länge | Bus | Verwendung |
|---|---|---|---|---|
| `mus_title` | 1 | 84.6 s | Music | Musik Titel: d-Moll (äolisch), 56 BPM, Laute/Harfe + Pad |
| `mus_day` | 1 | 87.5 s | Music | Musik Tag (Friedhof): D dorisch, 66 BPM |
| `mus_night` | 1 | 81.3 s | Music | Musik Nacht: a-Moll, 52 BPM, sparsam |
| `mus_village` | 1 | 87.5 s | Music | Musik Dorf: G mixolydisch, 72 BPM, wärmer |

## Geräusche (SFX)

| Cue | Varianten | Länge | Bus | Verwendung |
|---|---|---|---|---|
| `step_grass` | 6 | 0.2 s | SFX | Schritte auf Gras (Friedhof, Anger; Dorfbewohner leiser, positional) |
| `step_earth` | 6 | 0.2 s | SFX | Schritte auf Erde (Kutschweg, Erdwege im Dorf) |
| `step_stone` | 6 | 0.2 s | SFX | Schritte auf Stein/Kies (Kiesweg, Am Bruch, Pflaster, Kapelle, Gruft) |
| `step_wood` | 6 | 0.3 s | SFX | Schritte auf Holz (Hütte, Gaststube, Amts-/Wundarztstube, Schuppen, Brücke), manchmal Dielenknarren |
| `dig` | 3 | 0.8 s | SFX | Graben: Spatenbiss in die Erde, Erdklumpen fällt (wiederholt während „Grab ausheben“) |
| `dirt_pour` | 2 | 1.3 s | SFX | Erde schütten (Bestatten, Gebeine beisetzen, Grab zuschütten) |
| `stone_set` | 1 | 1.1 s | SFX | Grabstein setzen (Schleifen + dumpfer Stand) |
| `chop` | 3 | 0.6 s | SFX | Axthieb in Holz (Erle fällen, roden) |
| `saw` | 2 | 1.0 s | SFX | Sägen, zwei Züge (Herstellen an der Werkbank) |
| `hammer` | 3 | 0.4 s | SFX | Hämmern/Holzschlag (Bauen, Grabzeichen setzen, Stationen) |
| `anvil` | 2 | 1.4 s | SFX · positional | Amboss (Schmiede Hollerbrück positional, Werkzeugstufe) |
| `chisel` | 3 | 0.5 s | SFX | Meißel am Stein (Inschrift, Zierde, Steinmetzbank) |
| `pick_stone` | 3 | 0.6 s | SFX | Spitzhacke auf Fels (Erz, Bruchstein, Werkstein) |
| `loom` | 2 | 0.9 s | SFX | Webstuhl: Schiffchen + Lade |
| `bellows` | 1 | 1.4 s | SFX | Blasebalg/Esse faucht auf (Esse-Auftrag startet) |
| `rustle` | 3 | 0.6 s | SFX | Rascheln (Laub harken, Unkraut, Beeren, Flachs, Sammeln) |
| `cloth` | 3 | 0.7 s | SFX | Tuch/Leinen (Untersuchen, Aufbahren, Totenhemd, Leiche aufheben) |
| `wash` | 2 | 1.3 s | SFX | Waschen mit Becken und Tuch |
| `scrub` | 2 | 0.9 s | SFX | Bürsten (Knochenpräparat) |
| `snip` | 2 | 0.2 s | SFX | Schere (Zopf, Kräuter, Zurückschneiden) |
| `quill` | 2 | 0.8 s | SFX | Feder kratzt (Speichern, Hinweis gefunden, Auftrag angenommen) |
| `smoke_hiss` | 1 | 1.4 s | SFX | Wacholder räuchern |
| `door_open` | 2 | 1.3 s | SFX | Tür/Tor öffnen (Beginn jedes Raum-/Regionswechsels) |
| `door_close` | 2 | 0.9 s | SFX | Tür fällt zu (Ankunft innen/außen) |
| `chest_open` | 2 | 0.9 s | SFX | Truhe auf (Truhen-Panel, Aufschließen) |
| `chest_close` | 2 | 0.6 s | SFX | Truhe zu |
| `crate` | 2 | 0.5 s | SFX | Kiste abstellen (Schuppen holen/einlagern, Räumen) |
| `coins` | 3 | 0.9 s | SFX | Münzen (Bezahlung, Ausgaben, Laden, Nachthändlerin) |
| `pickup` | 2 | 0.3 s | SFX | Aufheben (Sammeln, Abholen) |
| `putdown` | 2 | 0.3 s | SFX | Ablegen |
| `corpse_down` | 2 | 0.9 s | SFX | Leiche ablegen – dumpf, Leinen, kein Körpergeräusch |
| `glass_seal` | 2 | 1.2 s | SFX | Glas versiegeln: sanftes Klirren, Korken, Wachs (Präparat einlegen/versiegeln) |
| `anatomy_tool` | 2 | 1.0 s | SFX | MorgueTable.sound_hook „anatomy_tool“: kaum hörbar, Tuch + leises Metallticken, gedämpft |
| `cart_roll` | 1 | 3.0 s | SFX · Schleife · positional | Osrics Handkarren rollt (Schleife, positional an Osric, Holzräder auf Kies) |
| `church_bell` | 1 | 7.0 s | SFX · positional | Kirchenglocke 06/12/18 Uhr, 3 Schläge (im Dorf positional am Turm, vom Friedhof fern) |
| `small_bell` | 1 | 3.5 s | SFX | Kleine Glocke (Aussegnung, Andacht, Weihe, Story-Leiche) |
| `ghost_appear` | 1 | 3.6 s | SFX | Geist spricht (ruhig): Glas-Pad |
| `ghost_content` | 1 | 3.6 s | SFX | Geist zufrieden: warme steigende Sexte |
| `ghost_restless` | 1 | 3.4 s | SFX | Geist unruhig: zwei schwebende Glastöne (unheimlich, nicht gruselig) |
| `ghost_night` | 1 | 5.0 s | SFX | Geisterstunde beginnt (21:30): tiefer Pad-Atem |
| `chapter` | 1 | 6.0 s | SFX | Kapitel-Fanfare (leise Laute-Arpeggio über Pad) |
| `travel` | 1 | 1.6 s | SFX | Weg zwischen Regionen (weicher Luftzug während der Blende) |
| `remark` | 2 | 0.3 s | SFX | Gerede-Blase (dezent, zwei gedämpfte Holztöne) |
| `build_place` | 2 | 0.7 s | SFX | Bau-Modus: Zier gesetzt |
| `build_remove` | 1 | 0.6 s | SFX | Bau-Modus: Zier entfernt |
| `sleep` | 1 | 1.4 s | SFX | Hinlegen/Tagesabschluss (Decke, Stroh) |

## Oberfläche (UI)

| Cue | Varianten | Länge | Bus | Verwendung |
|---|---|---|---|---|
| `ui_click` | 2 | 0.1 s | UI | Knopf gedrückt (alle Buttons) |
| `ui_hover` | 1 | 0.1 s | UI | Maus über Knopf (sehr leise) |
| `ui_open` | 1 | 0.3 s | UI | Panel/Dialog öffnen |
| `ui_close` | 1 | 0.3 s | UI | Panel/Dialog schließen |
| `ui_error` | 1 | 0.3 s | UI | Fehler/gesperrt (Warn-Hinweise) |
| `ui_page` | 3 | 0.5 s | UI | Merkbuch/Grabregister blättern |
| `ui_notify` | 1 | 1.0 s | UI | Benachrichtigung (Info, Auftrag angeboten, Werkstück fertig) |
| `ui_reward` | 1 | 1.3 s | UI | Belohnung (Abschnitt frei, Erkenntnis, Sammlung) |

**Gesamt:** 88 Cues, 162 Dateien, 17.7 MiB Quelldateien (WAV unkomprimiert im Repo; im Export als QOA ≈ 1/5, Web-Paket +2,2 MB gegenüber Runde 1).


## Analyse Runde 2 (objektiv – `python tools/audio/analyze_audio.py --md …`)

Niemand kann hier hören, darum objektive Messwerte je Datei. **Lautheit** nach ITU-R BS.1770 (K-Gewichtung, pyloudnorm): Schleifen und Musik integriert, Einzelklänge als lautestes 400-ms-Fenster („Momentary max“). **Im Spiel** = Datei + `volume_db` des Cues (vor den Reglern des Spielers; Grundregler Master 0,8 · Musik 0,55 · Atmosphäre 0,8 · SFX 0,9 · UI 0,7). `volume_db` wird seit Runde 2 von `build_audio.py` aus der gemessenen Lautheit berechnet (`target_lufs` je Cue in `data/audio/cues_*.tres`).

**Ziel-Lautheiten (im Spiel, LUFS):** Atmosphäre −35 (Friedhof/Wald draußen −36), Welt-Schleifen −30, Spots −39, Musik −28 (+ Musikregler 0,55 ≈ −33), Geräusche −27, Schritte −42 (Gras −43), UI −38 (Klick −40, Hover −48), Kirchenglocke −24, Gerede-Blase −33, Präparierbesteck −31. Toleranz ±3 dB (Analyse) bzw. ±4,5 dB (Test `test_audio_quality.gd`, misst mit Godots eigener Wiedergabe).

**Prüfungen:** Clipping (Spitze > −0,3 dBFS), DC-Versatz > 0,002, Knackser (erstes/letztes Sample > 0,01 bei Einzelklängen; alle haben jetzt 5 ms Ein- und 10 ms Ausblende), Naht der Schleifen (Sprung am Wendepunkt > 6 × übliche Sample-Stufe; Pegelsprung > 1,5 dB und > 1,25 × übliche 250-ms-Stufe), grell (Energieanteil 2–5 kHz > 50 %, Vögel und Becher sind von Natur aus hell und ausgenommen; `build_audio` senkt 2–5 kHz um 3–9 dB, bis der Anteil ≤ 45 % ist), Pfeifen/Resonanz in Schleifen (schmale Spitze > 18 dB über dem geglätteten Spektrum, Grillen 3,8–5,3 kHz ausgenommen), langer Ausklang (> 1,5 s unter −40 dB der Spitze am Ende).

**Wind neu (Runde 2):** Spektrogramme `spectro_wind_day_before.png` / `_after.png`, `spectro_wind_night_before.png` / `_after.png` (je 60 s, die Schleife wiederholt). Vorher: 24-s-Schleife, Böen als regelmäßige Sinus-Hüllkurve (≈ alle 5 s), zusätzliches resonantes „Pfeif“-Band 0,8–2 kHz, Laub-Körner bis 8 kHz im selben Takt → senkrechte Streifen bis 8 kHz im Spektrogramm. Nachher: 48-s-Schleife, eine unregelmäßige Böenkurve (viele Komponenten mit 1/f-Abfall, weiche Sättigung, nie unter 45 %), drei Bänder ohne Resonanz (Grollen < 130 Hz, Körper 110–800 Hz mit sanften Flanken, ein heller Anteil folgt der Böe verzögert), Laub 1,2–5 kHz nur in den Böen; Energie über 3 kHz: Friedhof Tag 2,8 % → 0,5 %, Wald-Rand 28 % → 3,7 %; Pegel 3–4 dB leiser im Mix (−32/−33 → −36 LUFS), Vögel 1,6 × seltener (Morgen, Tag, Wald-Rand, Dorf Morgen), Grillen weniger und leiser.

| Datei | Bus | s | Peak dBFS | DC | LUFS Datei | Lautheit im Spiel | Ziel | 2–5 kHz | Spitze dB@Hz | Rauschboden | Ausklang s | Naht | Befund |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ph_step_grass_1.wav | SFX | 0.16 | -1.0 | -0.0000 | -24.5 | -43.6 | -46…-40 | 25 % | 8@6525 | -36 | 0.05 | 0.000 / 0.000 | ok |
| ph_step_grass_2.wav | SFX | 0.16 | -1.0 | -0.0000 | -23.3 | -42.4 | -46…-40 | 18 % | 9@1050 | -41 | 0.05 | 0.000 / 0.000 | ok |
| ph_step_grass_3.wav | SFX | 0.16 | -1.0 | -0.0000 | -24.2 | -43.3 | -46…-40 | 27 % | 9@969 | -40 | 0.04 | 0.000 / 0.000 | ok |
| ph_step_grass_4.wav | SFX | 0.16 | -1.0 | -0.0000 | -25.1 | -44.2 | -46…-40 | 12 % | 10@369 | -42 | 0.04 | 0.000 / 0.000 | ok |
| ph_step_grass_5.wav | SFX | 0.16 | -1.0 | -0.0000 | -24.9 | -44.0 | -46…-40 | 19 % | 11@3081 | -43 | 0.05 | 0.000 / 0.000 | ok |
| ph_step_grass_6.wav | SFX | 0.16 | -1.7 | -0.0000 | -22.2 | -41.3 | -46…-40 | 23 % | 8@3250 | -39 | 0.03 | 0.000 / 0.000 | ok |
| ph_step_earth_1.wav | SFX | 0.20 | -1.0 | -0.0000 | -22.3 | -41.0 | -45…-39 | 5 % | 8@377 | -34 | 0.04 | 0.000 / 0.000 | ok |
| ph_step_earth_2.wav | SFX | 0.20 | -2.0 | -0.0000 | -21.6 | -40.3 | -45…-39 | 24 % | 9@603 | -32 | 0.02 | 0.000 / 0.000 | ok |
| ph_step_earth_3.wav | SFX | 0.20 | -1.0 | -0.0000 | -23.1 | -41.8 | -45…-39 | 7 % | 8@958 | -34 | 0.03 | 0.000 / 0.000 | ok |
| ph_step_earth_4.wav | SFX | 0.20 | -0.4 | -0.0000 | -26.3 | -45.0 | -45…-39 | 0 % | 12@2471 | -36 | 0.06 | 0.000 / 0.000 | ok |
| ph_step_earth_5.wav | SFX | 0.20 | -1.0 | -0.0000 | -23.8 | -42.5 | -45…-39 | 28 % | 10@495 | -26 | 0.05 | 0.000 / 0.000 | ok |
| ph_step_earth_6.wav | SFX | 0.20 | -1.0 | -0.0000 | -24.5 | -43.2 | -45…-39 | 4 % | 11@1211 | -37 | 0.06 | 0.000 / 0.000 | ok |
| ph_step_stone_1.wav | SFX | 0.20 | -1.0 | -0.0000 | -23.5 | -41.1 | -45…-39 | 30 % | 22@937 | -52 | 0.13 | 0.000 / 0.000 | ok |
| ph_step_stone_2.wav | SFX | 0.20 | -1.0 | -0.0000 | -25.7 | -43.3 | -45…-39 | 11 % | 22@985 | -54 | 0.13 | 0.000 / 0.000 | ok |
| ph_step_stone_3.wav | SFX | 0.20 | -1.0 | -0.0000 | -24.9 | -42.5 | -45…-39 | 10 % | 24@969 | -52 | 0.12 | 0.000 / 0.000 | ok |
| ph_step_stone_4.wav | SFX | 0.20 | -1.0 | -0.0000 | -24.4 | -42.0 | -45…-39 | 26 % | 20@872 | -44 | 0.13 | 0.000 / 0.000 | ok |
| ph_step_stone_5.wav | SFX | 0.20 | -1.0 | -0.0000 | -23.0 | -40.6 | -45…-39 | 30 % | 22@980 | -54 | 0.13 | 0.000 / 0.000 | ok |
| ph_step_stone_6.wav | SFX | 0.20 | -1.0 | -0.0000 | -25.5 | -43.1 | -45…-39 | 13 % | 22@958 | -57 | 0.14 | 0.000 / 0.000 | ok |
| ph_step_wood_1.wav | SFX | 0.30 | -1.0 | -0.0000 | -18.8 | -41.8 | -45…-39 | 0 % | 45@161 | -40 | 0.07 | 0.000 / 0.000 | ok |
| ph_step_wood_2.wav | SFX | 0.30 | -1.0 | -0.0000 | -18.1 | -41.1 | -45…-39 | 0 % | 30@215 | -38 | 0.07 | 0.000 / 0.000 | ok |
| ph_step_wood_3.wav | SFX | 0.30 | -1.0 | -0.0000 | -20.0 | -43.0 | -45…-39 | 0 % | 42@151 | -41 | 0.09 | 0.000 / 0.000 | ok |
| ph_step_wood_4.wav | SFX | 0.30 | -1.0 | -0.0000 | -19.0 | -42.0 | -45…-39 | 0 % | 29@151 | -39 | 0.07 | 0.000 / 0.000 | ok |
| ph_step_wood_5.wav | SFX | 0.30 | -1.0 | -0.0000 | -18.9 | -41.9 | -45…-39 | 0 % | 28@221 | -39 | 0.08 | 0.000 / 0.000 | ok |
| ph_step_wood_6.wav | SFX | 0.30 | -1.0 | -0.0000 | -19.3 | -42.3 | -45…-39 | 0 % | 44@151 | -39 | 0.07 | 0.000 / 0.000 | ok |
| ph_dig_1.wav | SFX | 0.80 | -1.0 | -0.0000 | -22.2 | -27.8 | -30…-24 | 25 % | 8@3408 | -74 | 0.12 | 0.000 / 0.000 | ok |
| ph_dig_2.wav | SFX | 0.80 | -1.0 | -0.0000 | -21.1 | -26.7 | -30…-24 | 39 % | 8@3957 | -78 | 0.17 | 0.000 / 0.000 | ok |
| ph_dig_3.wav | SFX | 0.80 | -1.0 | -0.0000 | -21.1 | -26.7 | -30…-24 | 32 % | 8@205 | -72 | 0.21 | 0.000 / 0.000 | ok |
| ph_dirt_pour_1.wav | SFX | 1.30 | -1.0 | -0.0000 | -12.0 | -26.9 | -30…-24 | 38 % | 4@877 | -23 | 0.04 | 0.000 / 0.000 | ok |
| ph_dirt_pour_2.wav | SFX | 1.30 | -1.0 | -0.0000 | -12.2 | -27.1 | -30…-24 | 39 % | 5@6584 | -24 | 0.04 | 0.000 / 0.000 | ok |
| ph_stone_set.wav | SFX | 1.10 | -1.0 | -0.0000 | -14.8 | -27.0 | -30…-24 | 7 % | 11@619 | -42 | 0.12 | 0.000 / 0.000 | ok |
| ph_chop_1.wav | SFX | 0.55 | -1.0 | -0.0000 | -19.1 | -27.6 | -30…-24 | 0 % | 62@242 | -51 | 0.19 | 0.000 / 0.000 | ok |
| ph_chop_2.wav | SFX | 0.55 | -1.0 | -0.0000 | -18.3 | -26.8 | -30…-24 | 0 % | 62@237 | -50 | 0.15 | 0.000 / 0.000 | ok |
| ph_chop_3.wav | SFX | 0.55 | -1.0 | -0.0000 | -18.1 | -26.6 | -30…-24 | 0 % | 61@264 | -50 | 0.18 | 0.000 / 0.000 | ok |
| ph_saw_1.wav | SFX | 1.00 | -1.0 | -0.0000 | -14.2 | -27.1 | -30…-24 | 32 % | 5@7698 | -35 | 0.10 | 0.000 / 0.000 | ok |
| ph_saw_2.wav | SFX | 1.00 | -1.0 | -0.0000 | -13.9 | -26.8 | -30…-24 | 33 % | 6@4102 | -35 | 0.10 | 0.000 / 0.000 | ok |
| ph_hammer_1.wav | SFX | 0.40 | -1.0 | -0.0000 | -19.3 | -26.8 | -30…-24 | 1 % | 56@431 | -56 | 0.18 | 0.000 / 0.000 | ok |
| ph_hammer_2.wav | SFX | 0.40 | -1.0 | -0.0000 | -19.4 | -26.9 | -30…-24 | 1 % | 57@404 | -56 | 0.18 | 0.000 / 0.000 | ok |
| ph_hammer_3.wav | SFX | 0.40 | -1.0 | -0.0000 | -19.7 | -27.2 | -30…-24 | 1 % | 56@436 | -57 | 0.19 | 0.000 / 0.000 | ok |
| ph_anvil_1.wav | SFX | 1.40 | -1.0 | -0.0000 | -11.5 | -26.9 | -30…-24 | 13 % | 71@964 | -34 | 0.11 | 0.000 / 0.000 | ok |
| ph_anvil_2.wav | SFX | 1.40 | -1.0 | -0.0000 | -11.6 | -27.0 | -30…-24 | 13 % | 67@953 | -34 | 0.11 | 0.000 / 0.000 | ok |
| ph_chisel_1.wav | SFX | 0.50 | -1.0 | -0.0000 | -21.0 | -27.2 | -30…-24 | 45 % | 34@2929 | -67 | 0.33 | 0.000 / 0.000 | ok |
| ph_chisel_2.wav | SFX | 0.50 | -1.0 | -0.0000 | -20.1 | -26.3 | -30…-24 | 27 % | 32@2848 | -66 | 0.34 | 0.000 / 0.000 | ok |
| ph_chisel_3.wav | SFX | 0.50 | -1.0 | -0.0000 | -21.7 | -27.9 | -30…-24 | 27 % | 39@2923 | -70 | 0.33 | 0.000 / 0.000 | ok |
| ph_pick_stone_1.wav | SFX | 0.60 | -1.0 | -0.0000 | -19.4 | -28.2 | -30…-24 | 31 % | 28@1448 | -65 | 0.21 | 0.000 / 0.000 | ok |
| ph_pick_stone_2.wav | SFX | 0.60 | -1.0 | -0.0000 | -17.4 | -26.2 | -30…-24 | 33 % | 29@1513 | -63 | 0.30 | 0.000 / 0.000 | ok |
| ph_pick_stone_3.wav | SFX | 0.60 | -1.0 | -0.0000 | -18.0 | -26.8 | -30…-24 | 23 % | 30@1453 | -64 | 0.30 | 0.000 / 0.000 | ok |
| ph_loom_1.wav | SFX | 0.90 | -1.0 | -0.0000 | -20.0 | -26.6 | -30…-24 | 5 % | 14@592 | -63 | 0.23 | 0.000 / 0.000 | ok |
| ph_loom_2.wav | SFX | 0.90 | -1.0 | -0.0000 | -21.0 | -27.6 | -30…-24 | 5 % | 14@608 | -64 | 0.23 | 0.000 / 0.000 | ok |
| ph_bellows.wav | SFX | 1.40 | -1.0 | -0.0000 | -12.4 | -27.0 | -30…-24 | 7 % | 5@1556 | -40 | 0.10 | 0.000 / 0.000 | ok |
| ph_rustle_1.wav | SFX | 0.60 | -1.0 | -0.0000 | -13.5 | -26.5 | -30…-24 | 38 % | 6@3149 | -22 | 0.03 | 0.000 / 0.000 | ok |
| ph_rustle_2.wav | SFX | 0.60 | -1.0 | -0.0000 | -14.6 | -27.6 | -30…-24 | 39 % | 5@7757 | -23 | 0.02 | 0.000 / 0.000 | ok |
| ph_rustle_3.wav | SFX | 0.60 | -1.0 | -0.0000 | -14.1 | -27.1 | -30…-24 | 41 % | 5@3074 | -22 | 0.03 | 0.000 / 0.000 | ok |
| ph_cloth_1.wav | SFX | 0.70 | -1.0 | -0.0000 | -11.5 | -26.7 | -30…-24 | 41 % | 6@5297 | -27 | 0.04 | 0.000 / 0.000 | ok |
| ph_cloth_2.wav | SFX | 0.70 | -1.0 | -0.0000 | -11.8 | -27.0 | -30…-24 | 39 % | 6@3828 | -26 | 0.04 | 0.000 / 0.000 | ok |
| ph_cloth_3.wav | SFX | 0.70 | -1.0 | -0.0000 | -12.3 | -27.5 | -30…-24 | 38 % | 6@748 | -26 | 0.04 | 0.000 / 0.000 | ok |
| ph_wash_1.wav | SFX | 1.30 | -1.0 | -0.0000 | -11.2 | -26.3 | -30…-24 | 23 % | 5@1701 | -29 | 0.07 | 0.000 / 0.000 | ok |
| ph_wash_2.wav | SFX | 1.30 | -1.0 | -0.0000 | -12.8 | -27.9 | -30…-24 | 21 % | 4@4888 | -40 | 0.10 | 0.000 / 0.000 | ok |
| ph_scrub_1.wav | SFX | 0.90 | -1.0 | -0.0000 | -12.5 | -26.7 | -30…-24 | 40 % | 5@1254 | -30 | 0.02 | 0.000 / 0.000 | ok |
| ph_scrub_2.wav | SFX | 0.90 | -1.0 | -0.0000 | -13.2 | -27.4 | -30…-24 | 39 % | 5@2923 | -30 | 0.02 | 0.000 / 0.000 | ok |
| ph_snip_1.wav | SFX | 0.25 | -1.0 | -0.0000 | -21.4 | -26.4 | -30…-24 | 39 % | 12@3596 | -49 | 0.14 | 0.000 / 0.000 | ok |
| ph_snip_2.wav | SFX | 0.25 | -1.0 | -0.0000 | -22.7 | -27.7 | -30…-24 | 43 % | 17@3601 | -65 | 0.18 | 0.000 / 0.000 | ok |
| ph_quill_1.wav | SFX | 0.80 | -1.0 | -0.0000 | -13.0 | -27.5 | -30…-24 | 30 % | 7@5432 | -92 | 0.01 | 0.000 / 0.000 | ok |
| ph_quill_2.wav | SFX | 0.80 | -1.0 | -0.0000 | -12.1 | -26.6 | -30…-24 | 32 % | 6@4813 | -96 | 0.01 | 0.000 / 0.000 | ok |
| ph_smoke_hiss.wav | SFX | 1.40 | -1.0 | -0.0000 | -11.5 | -27.0 | -30…-24 | 36 % | 5@1750 | -36 | 0.06 | 0.000 / 0.000 | ok |
| ph_door_open_1.wav | SFX | 1.30 | -1.0 | -0.0000 | -19.1 | -26.8 | -30…-24 | 18 % | 14@2132 | -90 | 0.32 | 0.000 / 0.000 | ok |
| ph_door_open_2.wav | SFX | 1.30 | -1.0 | -0.0000 | -19.6 | -27.3 | -30…-24 | 14 % | 12@1997 | -89 | 0.31 | 0.000 / 0.000 | ok |
| ph_door_close_1.wav | SFX | 0.90 | -1.0 | -0.0000 | -17.8 | -27.4 | -30…-24 | 1 % | 18@318 | -56 | 0.22 | 0.000 / 0.000 | ok |
| ph_door_close_2.wav | SFX | 0.90 | -1.0 | -0.0000 | -17.0 | -26.6 | -30…-24 | 1 % | 15@328 | -57 | 0.23 | 0.000 / 0.000 | ok |
| ph_chest_open_1.wav | SFX | 0.90 | -1.0 | -0.0000 | -20.3 | -26.6 | -30…-24 | 33 % | 14@2169 | -86 | 0.26 | 0.000 / 0.000 | ok |
| ph_chest_open_2.wav | SFX | 0.90 | -1.0 | -0.0000 | -21.1 | -27.4 | -30…-24 | 44 % | 12@2067 | -88 | 0.28 | 0.000 / 0.000 | ok |
| ph_chest_close_1.wav | SFX | 0.60 | -1.0 | -0.0000 | -19.1 | -26.4 | -30…-24 | 1 % | 25@188 | -90 | 0.31 | 0.000 / 0.000 | ok |
| ph_chest_close_2.wav | SFX | 0.60 | -1.0 | -0.0000 | -20.3 | -27.6 | -30…-24 | 1 % | 24@188 | -180 | 0.31 | 0.000 / 0.000 | ok |
| ph_crate_1.wav | SFX | 0.50 | -1.0 | -0.0000 | -19.4 | -27.7 | -30…-24 | 0 % | 41@231 | -63 | 0.25 | 0.000 / 0.000 | ok |
| ph_crate_2.wav | SFX | 0.50 | -1.0 | -0.0000 | -18.1 | -26.4 | -30…-24 | 0 % | 42@231 | -61 | 0.24 | 0.000 / 0.000 | ok |
| ph_coins_1.wav | SFX | 0.90 | -1.0 | -0.0000 | -12.2 | -26.8 | -30…-24 | 30 % | 25@4581 | -54 | 0.21 | 0.000 / 0.000 | ok |
| ph_coins_2.wav | SFX | 0.90 | -1.0 | -0.0000 | -13.5 | -28.1 | -30…-24 | 32 % | 25@3634 | -92 | 0.26 | 0.000 / 0.000 | ok |
| ph_coins_3.wav | SFX | 0.90 | -1.0 | -0.0000 | -11.9 | -26.5 | -30…-24 | 37 % | 26@3311 | -93 | 0.22 | 0.000 / 0.000 | ok |
| ph_pickup_1.wav | SFX | 0.30 | -1.0 | -0.0000 | -16.2 | -27.7 | -30…-24 | 39 % | 9@2336 | -28 | 0.06 | 0.000 / 0.000 | ok |
| ph_pickup_2.wav | SFX | 0.30 | -1.0 | -0.0000 | -14.8 | -26.3 | -30…-24 | 38 % | 11@4969 | -27 | 0.06 | 0.000 / 0.000 | ok |
| ph_putdown_1.wav | SFX | 0.35 | -1.0 | -0.0000 | -21.7 | -26.8 | -30…-24 | 0 % | 23@318 | -57 | 0.22 | 0.000 / 0.000 | ok |
| ph_putdown_2.wav | SFX | 0.35 | -1.0 | -0.0000 | -22.0 | -27.1 | -30…-24 | 0 % | 21@318 | -70 | 0.21 | 0.000 / 0.000 | ok |
| ph_corpse_down_1.wav | SFX | 0.90 | -1.0 | -0.0000 | -16.8 | -26.6 | -30…-24 | 15 % | 6@727 | -65 | 0.20 | 0.000 / 0.000 | ok |
| ph_corpse_down_2.wav | SFX | 0.90 | -1.0 | -0.0000 | -17.6 | -27.4 | -30…-24 | 17 % | 8@194 | -68 | 0.21 | 0.000 / 0.000 | ok |
| ph_glass_seal_1.wav | SFX | 1.20 | -1.0 | -0.0000 | -10.3 | -26.2 | -30…-24 | 41 % | 42@5443 | -33 | 0.09 | 0.000 / 0.000 | ok |
| ph_glass_seal_2.wav | SFX | 1.20 | -1.0 | -0.0000 | -12.2 | -28.1 | -30…-24 | 22 % | 41@2417 | -33 | 0.10 | 0.000 / 0.000 | ok |
| ph_anatomy_tool_1.wav | SFX | 1.00 | -1.0 | -0.0000 | -11.4 | -30.6 | -34…-28 | 32 % | 7@2606 | -97 | 0.34 | 0.000 / 0.000 | ok |
| ph_anatomy_tool_2.wav | SFX | 1.00 | -1.0 | -0.0000 | -12.2 | -31.4 | -34…-28 | 32 % | 6@2595 | -91 | 0.34 | 0.000 / 0.000 | ok |
| ph_cart_roll.ogg | SFX | 3.00 | -6.1 | -0.0000 | -20.7 | -27.0 | -30…-24 | 45 % | 3@4700 | -25 | 0.00 | 0.2 / 3.0 dB | ok |
| ph_church_bell.wav | SFX | 7.00 | -1.0 | -0.0000 | -10.8 | -24.0 | -27…-21 | 0 % | 44@587 | -30 | 0.26 | 0.000 / 0.000 | ok |
| ph_small_bell.wav | SFX | 3.50 | -1.0 | -0.0000 | -7.9 | -27.0 | -30…-24 | 3 % | 44@877 | -23 | 0.13 | 0.000 / 0.000 | ok |
| ph_ghost_appear.wav | SFX | 3.60 | -1.0 | -0.0000 | -10.5 | -27.0 | -30…-24 | 3 % | 75@2223 | -41 | 0.19 | 0.000 / 0.000 | ok |
| ph_ghost_content.wav | SFX | 3.60 | -1.0 | -0.0000 | -10.5 | -27.0 | -30…-24 | 0 % | 74@1976 | -41 | 0.22 | 0.000 / 0.000 | ok |
| ph_ghost_restless.wav | SFX | 3.40 | -1.0 | -0.0000 | -8.1 | -27.0 | -30…-24 | 0 % | 45@614 | -35 | 0.15 | 0.000 / 0.000 | ok |
| ph_ghost_night.wav | SFX | 5.00 | -1.0 | -0.0000 | -10.5 | -27.0 | -30…-24 | 0 % | 71@1760 | -45 | 0.29 | 0.000 / 0.000 | ok |
| ph_chapter.wav | SFX | 6.00 | -1.0 | -0.0000 | -10.9 | -27.0 | -30…-24 | 1 % | 40@738 | -50 | 0.51 | 0.000 / 0.000 | ok |
| ph_travel.wav | SFX | 1.60 | -1.0 | -0.0000 | -12.1 | -27.0 | -30…-24 | 6 % | 5@6643 | -44 | 0.11 | 0.000 / 0.000 | ok |
| ph_remark_1.wav | SFX | 0.35 | -1.0 | -0.0000 | -15.2 | -32.9 | -36…-30 | 1 % | 33@2573 | -35 | 0.08 | 0.000 / 0.000 | ok |
| ph_remark_2.wav | SFX | 0.35 | -1.0 | -0.0000 | -15.4 | -33.1 | -36…-30 | 1 % | 34@2573 | -36 | 0.08 | 0.000 / 0.000 | ok |
| ph_build_place_1.wav | SFX | 0.70 | -1.0 | -0.0000 | -16.9 | -27.0 | -30…-24 | 13 % | 43@231 | -180 | 0.32 | 0.000 / 0.000 | ok |
| ph_build_place_2.wav | SFX | 0.70 | -1.0 | -0.0000 | -16.9 | -27.0 | -30…-24 | 9 % | 42@231 | -85 | 0.32 | 0.000 / 0.000 | ok |
| ph_build_remove.wav | SFX | 0.60 | -1.0 | -0.0000 | -15.2 | -27.0 | -30…-24 | 44 % | 7@1023 | -90 | 0.22 | 0.000 / 0.000 | ok |
| ph_sleep.wav | SFX | 1.40 | -1.0 | -0.0000 | -11.1 | -27.0 | -30…-24 | 42 % | 5@1394 | -180 | 0.43 | 0.000 / 0.000 | ok |
| ph_ui_click_1.wav | UI | 0.09 | -1.0 | -0.0000 | -19.8 | -39.9 | -43…-37 | 0 % | 35@1244 | -11 | 0.01 | 0.000 / 0.000 | ok |
| ph_ui_click_2.wav | UI | 0.09 | -1.0 | -0.0000 | -19.9 | -40.0 | -43…-37 | 0 % | 35@1256 | -12 | 0.02 | 0.000 / 0.000 | ok |
| ph_ui_hover.wav | UI | 0.06 | -1.0 | -0.0000 | -18.9 | -48.0 | -51…-45 | 0 % | 25@1900 | -12 | 0.01 | 0.000 / 0.000 | ok |
| ph_ui_open.wav | UI | 0.35 | -1.0 | -0.0000 | -15.4 | -38.0 | -41…-35 | 42 % | 13@382 | -31 | 0.06 | 0.000 / 0.000 | ok |
| ph_ui_close.wav | UI | 0.30 | -1.0 | -0.0000 | -16.1 | -38.0 | -41…-35 | 32 % | 15@301 | -28 | 0.07 | 0.000 / 0.000 | ok |
| ph_ui_error.wav | UI | 0.35 | -1.0 | -0.0000 | -18.4 | -38.0 | -41…-35 | 0 % | 16@194 | -36 | 0.07 | 0.000 / 0.000 | ok |
| ph_ui_page_1.wav | UI | 0.45 | -1.0 | -0.0000 | -13.3 | -37.8 | -41…-35 | 43 % | 8@5093 | -31 | 0.06 | 0.000 / 0.000 | ok |
| ph_ui_page_2.wav | UI | 0.45 | -1.0 | -0.0000 | -13.1 | -37.6 | -41…-35 | 42 % | 8@7763 | -31 | 0.06 | 0.000 / 0.000 | ok |
| ph_ui_page_3.wav | UI | 0.45 | -1.0 | -0.0000 | -14.3 | -38.8 | -41…-35 | 44 % | 8@490 | -32 | 0.06 | 0.000 / 0.000 | ok |
| ph_ui_notify.wav | UI | 1.00 | -1.0 | -0.0000 | -10.1 | -38.0 | -41…-35 | 6 % | 38@1174 | -28 | 0.08 | 0.000 / 0.000 | ok |
| ph_ui_reward.wav | UI | 1.30 | -1.0 | -0.0000 | -10.4 | -38.0 | -41…-35 | 2 % | 39@883 | -30 | 0.09 | 0.000 / 0.000 | ok |
| ph_amb_graveyard_day.ogg | Ambience | 48.00 | -6.6 | +0.0000 | -22.5 | -36.0 | -39…-33 | 1 % | 1@8508 | -26 | 0.00 | 0.0 / 0.3 dB | ok |
| ph_amb_graveyard_dusk.ogg | Ambience | 48.00 | -7.1 | -0.0000 | -24.8 | -36.0 | -39…-33 | 1 % | 12@5105 | -27 | 0.00 | 0.2 / 0.5 dB | ok |
| ph_amb_graveyard_night.ogg | Ambience | 48.00 | -7.3 | +0.0000 | -23.6 | -36.0 | -39…-33 | 1 % | 14@4180 | -26 | 0.00 | 0.3 / 0.7 dB | ok |
| ph_amb_forest_edge.ogg | Ambience | 48.00 | -6.3 | +0.0000 | -22.7 | -36.0 | -39…-33 | 6 % | 1@7047 | -27 | 0.00 | 0.1 / 0.4 dB | ok |
| ph_amb_village_day.ogg | Ambience | 48.00 | -5.8 | +0.0000 | -22.5 | -35.0 | -38…-32 | 3 % | 3@629 | -25 | 0.00 | 0.0 / 0.2 dB | ok |
| ph_amb_village_night.ogg | Ambience | 48.00 | -7.2 | +0.0000 | -22.7 | -35.0 | -38…-32 | 2 % | 10@4453 | -24 | 0.00 | 0.1 / 0.2 dB | ok |
| ph_amb_hut.ogg | Ambience | 24.00 | -7.6 | +0.0000 | -29.1 | -35.0 | -38…-32 | 3 % | 2@441 | -30 | 0.00 | 0.1 / 0.0 dB | ok |
| ph_amb_inn.ogg | Ambience | 24.00 | -6.4 | -0.0000 | -25.0 | -35.0 | -38…-32 | 2 % | 3@3734 | -28 | 0.00 | 0.0 / 0.2 dB | ok |
| ph_amb_surgery.ogg | Ambience | 24.00 | -10.6 | +0.0000 | -25.1 | -35.0 | -38…-32 | 0 % | 3@2117 | -25 | 0.00 | 0.3 / 0.0 dB | ok |
| ph_amb_office.ogg | Ambience | 24.00 | -9.3 | +0.0000 | -23.6 | -35.0 | -38…-32 | 1 % | 8@2594 | -24 | 0.00 | 0.3 / 0.1 dB | ok |
| ph_amb_chapel.ogg | Ambience | 24.00 | -10.5 | -0.0000 | -24.3 | -35.0 | -38…-32 | 0 % | 4@1191 | -25 | 0.00 | 0.8 / 0.4 dB | ok |
| ph_amb_crypt.ogg | Ambience | 24.00 | -9.2 | +0.0000 | -26.8 | -35.0 | -38…-32 | 0 % | 4@2281 | -27 | 0.00 | 0.9 / 0.3 dB | ok |
| ph_amb_shed.ogg | Ambience | 24.00 | -10.6 | -0.0000 | -26.0 | -35.0 | -38…-32 | 0 % | 3@1797 | -26 | 0.00 | 0.6 / 0.3 dB | ok |
| ph_amb_title.ogg | Ambience | 48.00 | -9.4 | -0.0000 | -26.0 | -35.0 | -38…-32 | 0 % | 13@4355 | -29 | 0.00 | 0.1 / 0.3 dB | ok |
| ph_loop_brook.ogg | Ambience | 12.00 | -5.4 | -0.0000 | -18.6 | -30.0 | -33…-27 | 26 % | 2@1688 | -21 | 0.00 | 0.1 / 0.4 dB | ok |
| ph_loop_forge.ogg | Ambience | 10.00 | -6.6 | +0.0000 | -31.8 | -30.0 | -33…-27 | 38 % | 2@3363 | -41 | 0.00 | 0.0 / 1.6 dB | ok |
| ph_bird_a_1.wav | Ambience | 1.53 | -1.0 | -0.0000 | -9.7 | -38.9 | -42…-36 | 100 % | 15@746 | -49 | 0.16 | 0.000 / 0.000 | ok |
| ph_bird_a_2.wav | Ambience | 1.61 | -1.0 | -0.0000 | -9.9 | -39.1 | -42…-36 | 100 % | 9@3516 | -51 | 0.15 | 0.000 / 0.000 | ok |
| ph_bird_b_1.wav | Ambience | 1.93 | -1.0 | -0.0000 | -8.5 | -39.6 | -42…-36 | 99 % | 17@5910 | -47 | 0.24 | 0.000 / 0.000 | ok |
| ph_bird_b_2.wav | Ambience | 1.93 | -1.0 | -0.0000 | -7.3 | -38.4 | -42…-36 | 99 % | 15@5969 | -50 | 0.27 | 0.000 / 0.000 | ok |
| ph_bird_c_1.wav | Ambience | 2.07 | -1.0 | -0.0000 | -7.2 | -39.2 | -42…-36 | 100 % | 6@2152 | -52 | 0.26 | 0.000 / 0.000 | ok |
| ph_bird_c_2.wav | Ambience | 1.83 | -1.0 | -0.0000 | -6.7 | -38.7 | -42…-36 | 100 % | 8@5934 | -52 | 0.21 | 0.000 / 0.000 | ok |
| ph_crow_1.wav | Ambience | 2.59 | -1.0 | -0.0000 | -12.9 | -38.7 | -42…-36 | 6 % | 14@500 | -55 | 0.35 | 0.000 / 0.000 | ok |
| ph_crow_2.wav | Ambience | 2.56 | -1.0 | -0.0000 | -13.4 | -39.2 | -42…-36 | 5 % | 19@504 | -60 | 0.39 | 0.000 / 0.000 | ok |
| ph_owl_1.wav | Ambience | 4.77 | -1.0 | -0.0000 | -9.2 | -38.4 | -42…-36 | 0 % | 37@410 | -40 | 0.46 | 0.000 / 0.000 | ok |
| ph_owl_2.wav | Ambience | 4.77 | -1.0 | -0.0000 | -10.6 | -39.8 | -42…-36 | 0 % | 36@410 | -46 | 0.41 | 0.000 / 0.000 | ok |
| ph_owl_short.wav | Ambience | 2.51 | -1.0 | -0.0000 | -8.5 | -39.0 | -42…-36 | 0 % | 51@422 | -38 | 0.22 | 0.000 / 0.000 | ok |
| ph_chicken_1.wav | Ambience | 1.47 | -1.0 | -0.0000 | -16.4 | -39.2 | -42…-36 | 4 % | 11@453 | -56 | 0.25 | 0.000 / 0.000 | ok |
| ph_chicken_2.wav | Ambience | 1.92 | -1.0 | -0.0000 | -16.1 | -38.9 | -42…-36 | 4 % | 6@2508 | -49 | 0.26 | 0.000 / 0.000 | ok |
| ph_chicken_3.wav | Ambience | 1.75 | -1.0 | -0.0000 | -16.0 | -38.8 | -42…-36 | 5 % | 7@508 | -52 | 0.27 | 0.000 / 0.000 | ok |
| ph_hammer_far_1.wav | Ambience | 2.60 | -1.0 | -0.0000 | -12.0 | -40.0 | -42…-36 | 7 % | 28@5168 | -52 | 0.38 | 0.000 / 0.000 | ok |
| ph_hammer_far_2.wav | Ambience | 2.60 | -1.0 | -0.0000 | -10.1 | -38.1 | -42…-36 | 10 % | 35@961 | -47 | 0.31 | 0.000 / 0.000 | ok |
| ph_cup_clink_1.wav | Ambience | 0.60 | -1.0 | -0.0000 | -15.2 | -39.7 | -42…-36 | 33 % | 24@4414 | -35 | 0.05 | 0.000 / 0.000 | ok |
| ph_cup_clink_2.wav | Ambience | 0.60 | -1.3 | -0.0000 | -12.9 | -37.4 | -42…-36 | 11 % | 27@1949 | -27 | 0.03 | 0.000 / 0.000 | ok |
| ph_cup_clink_3.wav | Ambience | 0.60 | -0.6 | -0.0000 | -15.9 | -40.4 | -42…-36 | 96 % | 23@7855 | -31 | 0.06 | 0.000 / 0.000 | ok |
| ph_drip_spot_1.wav | Ambience | 2.13 | -1.0 | -0.0000 | -14.2 | -39.3 | -42…-36 | 0 % | 6@2141 | -39 | 0.17 | 0.000 / 0.000 | ok |
| ph_drip_spot_2.wav | Ambience | 2.13 | -1.0 | -0.0000 | -13.3 | -38.4 | -42…-36 | 1 % | 6@855 | -39 | 0.16 | 0.000 / 0.000 | ok |
| ph_drip_spot_3.wav | Ambience | 2.13 | -1.0 | -0.0000 | -14.3 | -39.4 | -42…-36 | 0 % | 6@1145 | -39 | 0.16 | 0.000 / 0.000 | ok |
| ph_wood_creak_1.wav | Ambience | 1.30 | -1.0 | -0.0000 | -22.8 | -38.0 | -42…-36 | 20 % | 8@2055 | -61 | 0.32 | 0.000 / 0.000 | ok |
| ph_wood_creak_2.wav | Ambience | 1.41 | -1.0 | -0.0000 | -25.1 | -40.3 | -42…-36 | 21 % | 6@465 | -71 | 0.41 | 0.000 / 0.000 | ok |
| ph_page_turn_far.wav | Ambience | 0.45 | -1.0 | -0.0000 | -13.2 | -39.0 | -42…-36 | 44 % | 11@1676 | -31 | 0.06 | 0.000 / 0.000 | ok |
| ph_fire_pop_1.wav | Ambience | 0.15 | -1.0 | -0.0000 | -23.9 | -38.2 | -42…-36 | 16 % | 12@4500 | -30 | 0.04 | 0.000 / 0.000 | ok |
| ph_fire_pop_2.wav | Ambience | 0.15 | -1.0 | -0.0000 | -25.7 | -40.0 | -42…-36 | 40 % | 11@2247 | -36 | 0.09 | 0.000 / 0.000 | ok |
| ph_wind_gust_1.wav | Ambience | 5.50 | -1.0 | -0.0000 | -12.5 | -38.8 | -42…-36 | 3 % | 3@1918 | -45 | 0.37 | 0.000 / 0.000 | ok |
| ph_wind_gust_2.wav | Ambience | 5.50 | -1.0 | -0.0000 | -12.9 | -39.2 | -42…-36 | 3 % | 3@8461 | -45 | 0.36 | 0.000 / 0.000 | ok |
| ph_mus_title.ogg | Music | 84.64 | -5.8 | +0.0000 | -20.9 | -28.0 | -31…-25 | 1 % | 31@523 | -42 | 6.52 | 0.001 / 0.000 | ok |
| ph_mus_day.ogg | Music | 87.50 | -7.0 | -0.0000 | -22.7 | -28.0 | -31…-25 | 0 % | 30@523 | -32 | 4.27 | 0.000 / 0.000 | ok |
| ph_mus_night.ogg | Music | 81.35 | -5.2 | +0.0000 | -20.5 | -28.0 | -31…-25 | 0 % | 33@1766 | -38 | 5.14 | 0.001 / 0.000 | ok |
| ph_mus_village.ogg | Music | 87.50 | -6.8 | +0.0000 | -22.6 | -28.0 | -31…-25 | 1 % | 31@699 | -35 | 6.34 | 0.000 / 0.000 | ok |
