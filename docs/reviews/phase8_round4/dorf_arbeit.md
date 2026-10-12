# G8 Runde 4 – Arbeitsbewegungen der Dorfbewohner

Benutzerentscheidung: „ja die sollen eigene arbeitsbewegungen bekommen" (Audit `docs/reviews/phase8_round3/animations_audit.md` §3: Lenz, Quast, Rosine und Fenner standen in ihrer Arbeitszeit nur mit `idle`, Osrics Pfeifenpause lief mit `talk`).

## 1. Bestandsaufnahme

Geprüft: alle Daten-Zeitpläne `data/npc/*_schedule.tres` (Phase 7/8, auch die Tages-Varianten mit `today_flag`), die Laufzeit-Zeitpläne aus Code (`ScheduleBuilder`: Lehrling, Besuche, Feste, Krankenbesuche, Leichenwäsche, Plaudereien) gegen die Clips der Modelle. Gezählt wurde jeder sichtbare Steh-Eintrag an einem Arbeitsort.

| Figur | Arbeitsort / Zeit | vorher | jetzt | Requisit |
|---|---|---|---|---|
| Rosine Wackernagel (Wirtin) | Schanktisch `v_in_inn_bar`, ab 06:50 (auch Kennenlern-Tag 16:10, Lichtgang 18:57) | `idle` | **`polish_mug`** – Krug in der Linken, das Tuch reibt ihn in Kreisen, sie hält ihn ins Licht, stellt ihn ab | `prop_mug`, `prop_rag` |
| Pfarrer Lenz | Kirchtür `v_church_door`, 08:00–09:00 („shop") | `idle` | **`read_breviary`** – das Brevier gehoben, er liest, die Rechte blättert um | (Brevier ist Teil des Körpers) |
| Pfarrer Lenz | Altar `v_in_church_altar`, 16:00–18:10 | `idle` | **`pray_altar`** – zum Altar gewandt: Hände am Brevier, die Arme heben sich zum Gebet, tiefe Verneigung | – |
| Schultheiß Fenner | Amtstisch `v_in_office_desk`, 07:55–12:20 und 13:05–16:05 | `idle` | **`desk_files`** – über den Tisch gebeugt, die Linke blättert Akten, dann kommt der Stempel herunter; die Rechte hält den Amtsstab | `prop_stamp` |
| Schultheiß Fenner | Aushangbrett `v_board`, 12:20–13:05, 16:05–18:05 (Kennenlern-Tag 17:12, Lichtgang 18:57) | `idle` | **`proclaim`** – liest eine Bekanntmachung vor, blickt über das Blatt zu den Leuten | `prop_notice` (mit Siegel) |
| Wundarzt Quast | Schreibpult `v_in_surgery_desk`, 07:55–14:00 | `idle` | **`desk_write`** – gebeugt, die Feder schreibt in kurzen Zeilen, taucht ein; die Tasche hängt lotrecht | `prop_quill` |
| Wundarzt Quast | Schreibpult, 14:00–18:06 | `idle` | **`mix_vial`** – hebt ein Fläschchen vors Auge, schwenkt es, stellt es ab | `prop_vial` |
| Liesel Dorn | Waschplatz `v_wash`, 06:38–09:00 | `work` (= Handspinnen!) | **`wash_brook`** – kniet an den Waschsteinen, schrubbt das Tuch, richtet sich auf und wringt es aus; Blick zum Bach | `prop_washcloth` |
| Liesel Dorn | Gruft-Tisch, Leichenwäsche (Gefallen, `Friendship`) | `work` (Spinnen) | **`wash_body`** – das nasse Tuch in langen Strichen am Körper entlang, die Linke stützt, auswringen | `prop_washcloth` |
| Liesel Dorn | vor ihrer Tür `v_dorn_door` | `work` (Spinnen) | unverändert – Spinnen passt dort | Spindel (Körper) |
| Ulrich Esch (Schmied) | Amboss `v_anvil` | `work` (Hämmern) | unverändert | Hammer (Körper) |
| Theres Mangold (Krämerin) | Ladenfenster `v_shop_window` | `work` (Wiegen, Zählen) | unverändert | – |
| Osric | Abendpfeife `evening_spot`, 18:30 | `talk` | **`smoke`** – steht behaglich, zieht an der Pfeife (Brust hebt sich), lässt Rauchwölkchen aus, schaut zufrieden umher | Rauch aus dem Marker `pipe_smoke` |
| Jakob (Lehrling) | Krug `v_in_inn_jakob`, 17:00–21:00 an Arbeitstagen („hilft Rosine") | `idle` (Laufzeit) / `talk` (Daten) | **`sweep`** (vorhandener Clip mit Besen), beim Fegen um −120° gedreht, damit der Besen nicht hinter dem Tisch verschwindet | Besen (vorhanden) |
| Jakob | Friedhof (Rechen, Gießen, Jäten, Kerzen, Fegen …) | eigene Clips | unverändert | – |
| Hanne (Hausiererin), Veit (Bettler), Wiebke, Besucher / Angehörige, Feste | Brunnen/Tor, Kirchstufe, Bank, Gräber | `offer`, `sit_beg`, `sit`, `kneel`/`mourn_stand`/`lay_flowers`, `dance`/`clap`/`lantern_*` | unverändert (keine Lücke) | – |
| Ilse Kranich | `trader_spot` nachts | `idle` | unverändert: sie wartet mit der Laterne, gehandelt wird im Gespräch (`offer`) – kein Werkplatz | – |
| Osric | Remise 11:18, Krug-Ecke 14:05 / 22:00 | `idle` | unverändert: Pause, kein Arbeitsort | – |

Nicht als Arbeit gezählt (bleiben `idle`/`talk`): Frühstück/Abend im Krug, Plaudereien (`ChatterRunner` – die Figur wendet sich dem Partner zu und spricht, das geht auch an einem Arbeitsort vor), Quasts Vorlesung (Sprechen = `talk`).

## 2. Umsetzung

- **Clips** (alle Schleifen, 3 s, 30 fps, Wurzel ruht, nahtlos, Füße am Boden): `tools/blender/asset_villager_work.py` (`WORK`, Posen, Requisiten), eingehängt in `asset_villagers._rigged` **nach** allen älteren Clips; Osric `smoke-loop` + Marker `pipe_smoke` in `asset_carter.py`. Starre Arme ohne Ellbogen: alles liest sich aus ganzen Arm-, Rumpf- und Kopfbewegungen; Fenners Stab und Quasts Tasche bleiben lotrecht (der Arm gleicht die Rumpfneigung aus).
- **Requisiten** = Kindmeshes am Armknochen mit glTF-Extras `show_with` (Muster `lantern_prop`): `hold()` setzt sie in der Referenzpose des Clips in die Faust und rechnet sie in die Ruhepose zurück. Je Figur ≤ 9000 Dreiecke inkl. Requisiten (Fenner 8988).
- **Hash-gleich:** Körper-Mesh und alle alten Clips (test_assets_phase8 `REEXPORT`, test_cart_delivery für Osric). Bewusst angepasste Listen-Tests: `test_assets_phase8` (neue Konstante `WORK_R4` für die Clip-Liste), `test_cart_delivery.test_carter_keeps_body_and_old_clips` und `test_assets_characters` (Osric + `smoke`). Der Glb-Export ist bytegleich bei Wiederholung (zweimal gebaut, md5 gleich).
- **Daten:** `ScheduleEntry.animation` der Arbeitseinträge in `data/npc/*_schedule.tres` (bei Osric nur der Abendeintrag `evening_smoke`: `talk` → `smoke`); `data/config/npc_work_config.tres` (`NpcWorkConfig`): welche Clips Arbeit sind, Pausen-Abstand 2,8 m, `idle`/`talk`, Arbeitsrichtung je Ort (`work_facing`: Altar 180°, Waschplatz −90° zum Bach, Jakob −120°), Laufzeit-Clips (`apprentice_inn` → `sweep`, `washer_table` → `wash_body`), Rauchwölkchen (Momente 0,5/0,58 des Zyklus, Größe, Farbe, Steigen).
- **Ansprechen:** `Npc` – kommt der Totengräber näher als 2,8 m (oder spricht er sie an), legt die Figur die Arbeit hin (`idle`, Requisiten weg) und dreht sich zu ihm; im Gespräch `talk` bis `dialogue_ended`; geht er weg, arbeitet sie weiter und schaut wieder zur Arbeit.
- **Quasts Pult:** der Stehplatz `v_in_surgery_desk` 0,27 m näher ans Pult (1,75 → 2,02; Layout + Szene), vorher reichte die Hand nicht bis zur Platte.

## 3. Bilder (echter Renderer, 1280 × 720, xvfb + lavapipe)

Je Bogen: obere Reihe eine nähere Kamera von der Seite der Spielkamera, untere Reihe die Spielkamera selbst (Raum-/Dorfprofil) 1 : 1 um die Figur; Spalten = sechs Momente des Clips, letzte Spalte: der Totengräber tritt heran – die Arbeit ruht, die Figur wendet sich ihm zu. Forward+ ohne Zusatz, Browser-Renderer (`gl_compatibility`/`opengl3`) mit `_web`. Echter Spielstand (Phase-7-Ende, `slot_p7_day53_neighbor`), die Uhr läuft bis zur Minute, jede Figur steht nach ihrem Zeitplan; Jakobs Abend im Krug und Liesels Leichenwäsche über dieselben Bausteine wie im Spiel.

`dorf_wirtin` · `dorf_pfarrer_tuer` · `dorf_pfarrer_altar` · `dorf_buergermeister` · `dorf_buergermeister_brett` · `dorf_wundarzt` · `dorf_wundarzt_mischen` · `dorf_waescherin` · `dorf_waescherin_tisch` · `dorf_osric` · `dorf_jakob` (je `.jpg` und `_web.jpg`).

Skript: `tools/godot_run.sh --resolution 1280x720 -s res://src/world/village/village_shots_work.gd -- --out=/abs/dir [--shots=wirtin,osric] [--suffix=_web]`.

## 4. Tests

- `tests/unit/test_npc_work.gd`: Werte in den Daten; jeder Arbeitseintrag hat einen eigenen Arbeits-Clip (nicht `idle`/`talk`) und das Modell hat ihn; jeder „shop"-Eintrag arbeitet; Laufzeit-Clips; Arbeitsorte schauen zu Tresen, Tisch, Pult, Altar, Amboss, Waschsteinen; Clips vorhanden, Schleife, 3 s, Wurzel ruht, nahtlos, Füße am Boden, Hände bewegen sich; Lesbarkeit (Krug über dem Tresen, Feder über dem Pult, Stempel herunter, Liesel kniet, Arme zum Gebet); Requisiten am Knochen, nur mit ihrem Clip, in der Faust, ≤ 150 Dreiecke; Budget ≤ 9000; Generatoren deterministisch.
- `tests/integration/test_npc_work.gd`: echte `Npc`-Szene mit echtem Zeitplan und Modell – Arbeits-Clip, Requisit, Arbeitsrichtung; herantreten → Pause, Zuwendung, Requisit weg; ansprechen → `talk`, Dialogende → `idle`, weggehen → Arbeit; Osrics Rauchwölkchen am Marker.

## 5. Befund aus den Bildern / offen

- Gut lesbar: Rosine mit Krug über dem Tresen, Quast schreibt am Pult und hebt das Fläschchen vors Auge, Fenner liest die Bekanntmachung vor, Liesel kniet und wringt am Bach, Osrics Rauchwölkchen, Lenz' erhobene Arme und die Verneigung vor dem Altar (von hinten: er schaut zum Altar).
- Fenner am Amtstisch blättert an der vorderen Tischkante; der Stempel ist aus der Spielkamera klein. Starre Arme reichen nicht weiter, ohne dass der Stab kippt.
- Jakobs Besen ist aus der Spielkamera nur am Stiel zu sehen (der Tisch vor ihm verdeckt den Boden).
- Am Gruft-Tisch zeigt das Bild Liesel ohne Leiche (die Wäsche wurde für das Bild ohne Leiche gestellt); im Spiel liegt die Leiche dort.
- Im Bildskript läuft die Uhr nicht; Lenz' Plauderei mit Veit an der Kirchtür (08:00–11:30) wird dort vorher zu Ende gespielt – im Spiel spricht er erst mit Veit und liest dann.
- Ilse (Nachthändlerin) und Osrics Pausen in Remise und Krug bleiben bewusst `idle` (kein Arbeitsort).
