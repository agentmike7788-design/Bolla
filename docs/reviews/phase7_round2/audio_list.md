# Klangliste – Gate G7, Änderungsrunde 1 (Audio)

Alle Klänge sind **prozedural synthetisiert** (`tools/audio/build_audio.py`, numpy/scipy, fester Seed pro Datei) – keine Samples, keine Fremdaufnahmen. Dateien: `assets/audio/<ordner>/ph_<id>[_n].ogg` (Placeholder-Präfix), Zuordnung `data/audio/cues_*.tres`, Ereignisse `data/audio/audio_events.tres`, Atmosphären `data/audio/ambience/*.tres`, Regeln `data/audio/audio_config.tres`.

Hörprobe: `audio_preview.ogg` (88 s): Friedhof Tag mit Vögeln und Schritten im Gras → Graben, Leiche ablegen, Erde schütten, Stein setzen → Tor, Weg ins Dorf (Anger, Hühner, Schmied, Bach, Kirchenglocke, Pflasterschritte, Gerede-Blase) → Gaststube (Tür, Dielen, Becher, Münzen) → Nacht auf dem Friedhof (Grillen, Eule, Geist erscheint, Geist zufrieden) → Musik-Ausschnitt „Nacht“.

## Atmosphäre

| Cue | Varianten | Länge | Bus | Verwendung |
|---|---|---|---|---|
| `amb_graveyard_day` | 1 | 24.0 s | Ambience · Schleife | Friedhof Tag: Wind mit Böen, Laub (+ Vögel, Krähe als Spots) |
| `amb_graveyard_dusk` | 1 | 24.0 s | Ambience · Schleife | Friedhof Dämmerung/Morgen: leiser Wind, erste Grillen |
| `amb_graveyard_night` | 1 | 24.0 s | Ambience · Schleife | Friedhof Nacht: Grillen, leiser Wind (+ Eule) |
| `amb_forest_edge` | 1 | 24.0 s | Ambience · Schleife | Wald-Rand (Holunderwinkel, Westrand): Blätterrauschen, Ästeknarren |
| `amb_village_day` | 1 | 24.0 s | Ambience · Schleife | Dorf Tag: fernes abstraktes Stimmengemurmel, Bach, Wind (+ Hühner, Schmied fern) |
| `amb_village_night` | 1 | 24.0 s | Ambience · Schleife | Dorf Nacht: Grillen, Bach, Wind (+ Eule) |
| `amb_hut` | 1 | 24.0 s | Ambience · Schleife | Hütte: Ofen knistert, Raumton |
| `amb_inn` | 1 | 24.0 s | Ambience · Schleife | Gaststube: Gemurmel, Ofen (+ Becher) |
| `amb_surgery` | 1 | 24.0 s | Ambience · Schleife | Wundarztstube: stiller Raum (+ Blättern, Glas) |
| `amb_office` | 1 | 24.0 s | Ambience · Schleife | Amtsstube: Uhr tickt |
| `amb_chapel` | 1 | 24.0 s | Ambience · Schleife | Kapelle: Hall, Luft, leises Summen (+ seltene Tropfen) |
| `amb_crypt` | 1 | 24.0 s | Ambience · Schleife | Gruft: tiefer Raumton, Tropfen im Hall |
| `amb_shed` | 1 | 24.0 s | Ambience · Schleife | Lagerschuppen: Wind an den Brettern (+ Knarren) |
| `amb_title` | 1 | 24.0 s | Ambience · Schleife | Titelbildschirm: Nachtwind, ferne Grillen |
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
| `wind_gust` | 2 | 4.0 s | Ambience | Spot: Windböe |

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
| `step_grass` | 4 | 0.2 s | SFX | Schritte auf Gras (Friedhof, Anger; Dorfbewohner leiser, positional) |
| `step_earth` | 4 | 0.2 s | SFX | Schritte auf Erde (Kutschweg, Erdwege im Dorf) |
| `step_stone` | 4 | 0.2 s | SFX | Schritte auf Stein/Kies (Kiesweg, Am Bruch, Pflaster, Kapelle, Gruft) |
| `step_wood` | 4 | 0.3 s | SFX | Schritte auf Holz (Hütte, Gaststube, Amts-/Wundarztstube, Schuppen, Brücke), manchmal Dielenknarren |
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

**Gesamt:** 88 Cues, 154 Dateien, 6.09 MiB (Ziel ≲ 8 MB).
