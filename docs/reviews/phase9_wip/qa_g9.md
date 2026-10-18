# Phase 9 – W3 QA, Entwurf Gate-Protokoll G9

Stand: Branch `vs/p9-qa` auf `579af2b` („Phase 9 W2: W-Welt …“). Vertrag: `docs/PHASE9_DESIGN.md` §9 Budget, §10 Tests, §11 Bilder, §12 W3, W0-Notizen, W1-Anschlüsse. Befunde sind **nicht** in fremden Dateien behoben (Auftrag); `QUALITY_GATE_STATUS.md` ist unberührt (Lead).

Neue / geänderte Dateien (nur QA-Besitz):
- `tests/integration/phase9_bot.gd` – `Phase9Bot extends Phase8Bot`, 9 Strategien, Münzbuch
- `tests/integration/test_phase9_playthrough.gd` – 9 Tests, Env `P9QA_ONLY=…`, `P9QA_DAYS=n`, `P9QA_DEBUG=1`
- `tests/integration/test_save_fuzzer.gd` – + echter v8-Stand mitten in Phase 9, Konsistenzprüfungen Phase 9
- `tests/integration/test_phase9_qa.gd` – Fixture-Kandidat lädt + Roundtrip, `QuestLog.entries` ≤ 4 ms
- `docs/reviews/phase9_wip/qa_p9_cpu.gd` (CPU-Sonde), `qa_p9_pck.gd` + `qa_p9_pck_body.gd` (pck-Prüfung), `slot_p9_mid_h4.json` (Fixture-Kandidat), `cpu_micro_p9.txt`, `render_stats_p9_qa.txt`

## 0. Nachtrag: Bestätigung nach dem Merge des Restbedarf-Zweigs

Der Restbedarf-Zweig `5d5235f` (`claude/last-gravekeeper-dev-aos21h`) ist in `vs/p9-qa` gemergt, danach lief `--import`.

| Lauf | Ergebnis |
|---|---|
| Phase-9-Bots, 9 Strategien | alle grün, Zahlen wie vorher: Kapitel, Enden, Münzen, Pietät gleich. Die verdeckten Grab-Prompts gingen von 8 auf 2–3 je Lauf zurück. |
| pck (neu exportiert, Compatibility) | 38/38 PASS (`pck/pck_check_p9_merged.txt`) |
| CPU-Sonde | Anteil 0,13–0,17 ms pro Bild, Wächter jetzt eigene Figur 0,13 ms; `QuestLog.entries` 0,47 ms; Spielstand 300 kB, Laden 0,53 s (`cpu_micro_p9_merged.txt`) |

Durch den Restbedarf erledigt oder entschärft:
- **QA9-04 teilweise:** „Datum vergleichen“ kommt jetzt vor den Blumen. „Brief am Grab vorlesen“ und die Kerze verdecken weiter.
- **A9-3:** Johann sitzt jetzt mittig auf der Stirnseite des Karrens.
- **A9-4:** Hannes Weg ist frei, Erlen und Busch sind versetzt.
- **Nachtwächter:** jetzt eigene Figur.
- **Brenneisen-Panel:** zeigt alle vier Angebote.

**Offen bleiben:** QA9-01, QA9-02 (in jedem Lauf gesehen), QA9-03 (jetzt bei stay9/silent9/letters9 beobachtet), QA9-05, QA9-07, QA9-08, QA9-F1, QA9-F2, QA9-T1, A9-1, A9-2, A9-5…A9-8 sowie die Entscheidungen QA9-B1, QA9-B2, QA9-H1 und P9-1.

## 1. Playthrough-Bot (§10)

`Phase9Bot` spielt den Phase-9-Bogen auf der echten Welt aus den v7-Endständen. Echte Wege und Eingaben:
- **Hütte:** Pult (Kladde, Register, Brief ohne Namen, Antwort), Ofen.
- **Gräber:** GravePlot „Datum vergleichen“, „Brief am Grab vorlesen“.
- **Dialoge** über `DialogueRunner`:
  - Zeugen: Osric, Rosine, Theres, Liesel, Veit, Gesa.
  - Johann am Grab und auf der Bank (Zeichen, H5, H6).
  - Vertraute (H5).
  - Brenneisen (Fragen, Angebote, Bestechung, Koffer, K5).
  - Fenner (vierte Reihe).
  - Briefe zustellen / vorlesen / mit Osric aufgeben, Botengänge.
  - Übergabe großer Bitten bei Osric.
- **KnockDoor:** Anna; nachts der Brief.
- **Große Bitten:** Torafel, Teile wie HillBot (Werkbank, Pflege, Zier, Roden, Abendbesuch, Geister).
- **Merkbuch:** Erkenntnis `i_light_before` (3 von 5).

Stand-ins (gezählt in `standins`):
- Brief „Öffnen und lesen“ = `Letters.decide(uid, read)`, also dasselbe wie die Brief-Karte.
- Brenneisen-Panel = `Stranger.sell`, also dasselbe wie die Panel-Knöpfe.
- Grab-Aufruf, wenn eine Pflege-Aktion den Phase-9-Prompt verdeckt (siehe QA9-04).

Bot-Politik für §2.8:
- Kein tägliches neues Grabgitter.
- Keine täglichen Honigkuchen.
- Keine Spende bei jedem Fenner-Gespräch.

Diese Phase-8-Gewohnheiten des Bots kosteten sonst −54 Münzen in 12 Tagen. §2.8 rechnet ohne sie.

| Strategie | Start | Tage | Ende Hauptkette (Tag) | Kapitel `who_knows_when` | Münzen Start → Ende (Δ) | morgens min. | Pietät | Briefe entsch. | große Bitten | Brenneisen |
|---|---|---|---|---|---|---|---|---|---|---|
| kindly9 | v7 kindly | 12 | A, Osric (67, fort 68) | **Tag 69 = B7** | 68 → 132 (**+64**) | 67 | 100 → 100 | 6 | 2 | Fenner |
| stay9 | v7 kindly | 12 | B (68), D3 in Reihe 4 | Tag 74 = B12 | 68 → 131 (+63) | 67 | 100 → 100 | 7 | 2 | Fenner |
| public9 | v7 kindly | 12 | C (66), Lenz/Quast/Liesel je −4 ✓ | Tag 74 = B12 | 68 → 131 (+63) | 67 | 100 → 100 | 7 | 2 | Fenner |
| silent9 | v7 kindly | 12 | still (Frist, 69) | Tag 74 = B12 | 68 → 131 (+63) | 67 | 100 → 100 | 7 | 2 | Fenner |
| letters9 | v7 kindly | 12 | A (67) | Tag 70 = B8 | 68 → 123 (+55) | 67 | 100 → 100 (Verlust 0 ≤ 6 ✓) | 6 | 2 | Fenner |
| trader9 | v7 anatomist | 12 | A (68) | **nicht erreicht** (QA9-T1) | 103 → 112 (+9) | 83 | −45 → −68 (≤ kindly − 15 ✓) | 6 | 1 | Kladde, 4 Präparate verkauft; K3 nicht erreicht |
| lazy9 | v7 kindly | 12 | still (Frist, ohne Kette; QA9-07) | – ✓ | 68 → 161 (+93) | 68 | 100 | 0 | 0 | – |
| founder9 | v7 founder | bis Kapitel | A (66) | Tag 67 = B7 ✓ | 57 → 127 (+70) | 57 | 100 | 5 | 2 | – |
| save_load9 | wie kindly9 | 12 | = kindly9 | = kindly9 | = | = | = | = | = | **zeilengleich** (jeden Morgen geladen, + Brenneisen am Tor, + große Bitte 1/3, + Abgang) |

Geprüft wird:
- Keine Engine-Fehler, keine Warnungen.
- Keine Bot-Probleme, also keine Sackgasse.
- Werte im Bereich.
- Münzbuch: Start + Einnahmen − Ausgaben = Ende, mit Beutel und Lohndose. Der Zweck `post` ist enthalten.
- Morgens nie unter 5 Münzen.
- Die Erwartungen aus §10 je Strategie.

**kindly9, Münzbuch:**
- Einnahmen 140: Bestattung 55, Aussegnung 14, Aufträge 25, Trinkgeld 18, Geistergaben 12, Pflegegeld 8, große Bitten 8.
- Ausgaben 76: Lehrling 30, Dorf 25, Almosen 11, Ilse 4, Osric 4, Post 2.
- Vergleich mit §2.8: Die Ausgaben passen (≈ 80). Die Einnahmen liegen über der Schätzung, besonders Bestattungen und Aussegnungen (§2.8: 39 + 10).

## 2. HillBot-Messung §2.3.6 (bestätigt, nichts verstellt)

Die Messung kommt aus `test_hill_requests_bot.gd` in der vollen Suite auf 579af2b.

| Spieler | Leerlauf Tag 2–12 | Ziel | Tage > 240 min | große Bitten | Tag-14-Münzen |
|---|---|---|---|---|---|
| Pflicht (duty_large) | **1887 min** (−33 % gegen 2820) | ≤ 1700 (Band 1450–1800) ✗ | 3 von 11 (Grenze 3) ✓ | 8 angenommen, 7 erfüllt, 1 versäumt (≤ 1) ✓ | 129 (≤ 130) ✓ |
| Andächtig (reverent_large) | 1413 min | 1350–1750 ✓ | 1 | 6 angenommen, 3 erfüllt, **1 halb + 2 versäumt = 3** (Grenze ≤ 2) ✗ | 99 (≤ 110) ✓ |

Neu gegenüber dem bekannten Wert: Der andächtige Spieler überschreitet die Grenze „≤ 2 halb/versäumt“ (hrl_crosses versäumt, hrl_proper_grave halb, hrl_widow_wood versäumt). Die Entscheidung liegt beim Benutzer.

## 3. Save-Fuzzer v8

Neu in `test_fuzz_v8_real_mid_phase9_save`: ein echter v8-Stand.
- Ausgangspunkt `slot_p8_day63_kindly`, dann echte Systeme und die echte Uhr.
- Gespeichert an Tag 66 um 14:30.
- Inhalt: Kette bei H4, Reihe 4 offen, zwei Lieferungen mit offenen Taschenbriefen, große Bitte 2/3, Post für die Toten wartet, Brenneisen am Tor, Johann auf der Bank.

Durchläufe:
- JSON- und Native-Schicht.
- 70 Pfad-Mutationen der Phase-9-Knoten: `quests`, `who_knows`, `letters`, `stranger`, `large_board`, `parts`, `large_progress`, `large_targets`, `large_refill`, `large_ended`, `ghost_night`, `kin_interval`, `letter_id`.
- 14 gezielte Fälle:
  - Schritt unbekannt, Wahl ohne Schritt
  - Brief-Uid ohne Record, `letter_id` unbekannt
  - Teile-Liste kürzer als die Bitte
  - Brenneisen-Ende unbekannt, `light_day` in der Zukunft
  - alle großen Bitten angenommen
  - ein Taschenbrief in drei Records
  - D3 bei `sieber_gone`
  - Ende mit aktuellem Schritt
  - `large_progress`/`large_targets` kaputt oder vom falschen Typ
  - `kin_interval` vom falschen Typ

Neue Prüfungen nach jedem Laden (`_check_phase9`):
- höchstens ein bekanntes Ende je Kette
- eine beendete Kette hat keinen Schritt mehr
- eine abgeschlossene Kette hat ein Ende
- jeder Schritt ist bekannt
- kein D3 bei `sieber_gone`
- ein Taschenbrief nur einmal, je Leiche höchstens einer
- höchstens `large_max_active` große Bitten angenommen
- Teile-Liste so lang wie die Bitte
- Ende und Kofferhalter des Herrn bekannt

Ergebnis: 108 geladen, 21 abgewiesen, kein halb übernommener Zustand. Ausnahmen sind die beiden Befunde:
- **QA9-F2:** ein Nicht-bool in `hill_requests.parts.<id>[n]` führt zu einem Script-Fehler in `HillRequests._load_large`. Der Stand ist danach nicht stabil.
- **QA9-F1:** D3 bei `sieber_gone` bleibt nach dem Laden stehen.

Beide sind im Test als „FINDING“ ausgegeben bzw. übersprungen, bis der Besitzer sie behebt.

**Fixture-Kandidat:** `docs/reviews/phase9_wip/slot_p9_mid_h4.json` (316 kB, v8).
- Er wird erzeugt mit `P9QA_FIXTURE_OUT=<abs dir>` und `--filter=test_save_fuzzer`.
- `test_phase9_qa.gd` prüft: Er lädt, der Zustand bleibt erhalten, Speichern → Laden ist identisch.
- **Vorschlag an den Lead:** als `tests/fixtures/saves_v8/slot_p9_mid_h4.json` übernehmen. Dann liest der Fuzzer ihn direkt, statt ihn jedes Mal neu zu erzeugen.

## 4. Performance relativ zu Phase 8 (§9)

Gemessen mit echtem Renderer (Vulkan lavapipe, 1280 × 720) über `graveyard_shots_phase9.gd`. Rohwerte in `render_stats_p9_qa.txt`.

| Szene | Phase 9 | Vergleich Phase 8 | Budget |
|---|---|---|---|
| Friedhof Tag am Tor: große Bitte + Brenneisen (`perf_p9_01`, Zoom 22) | 366 k Dreiecke, **270 DC**, 15 Omni, 0 Schatten | `perf_p8_01` (Jakob + 2 Besucher): 349 k, 308 DC, 5 Omni | DC ≤ 650 ✓, keine neuen Schatten ✓ |
| Reihe 4 belegt (`p9_24b`) | 266 k, 193 DC, 3 Omni | – | ✓ |
| Dorf Tag mit Brenneisen + Johann (`perf_p9_02`) | 108 k, 143 DC, 9 Omni | `perf_p8_05` Dorf nachts: 120 k, 119 DC | ✓ |
| Dorf, Veit am Brunnen + Sieber-Fenster (`p9_06`) | 204 k, 208 DC, 11 Omni | – | ✓ |
| Krug mit Brenneisen am Ecktisch (`p9_19`) | 65 k, 105 DC, 8 Omni, 1 Schatten | `perf_p8_04` Kathreintanz: 71 k, 22 DC | ✓ (DC höher, absolut klein) |
| Nacht, Nachtwächter vor der Sieber-Tür (`p9_11`) | 88 k, 106 DC, 4 Omni | `perf_p8_02` Friedhof nachts: 371 k, 391 DC | ✓ |
| Web (Compatibility), Abgang `p9_09_web` (W2) | 308 k, 394 DC | `p8_22_web` 856 DC | ✓ |

**Skriptanteil**, direkt gemessen (`qa_p9_cpu.gd`, headless, Cloud-CPU; Rohwerte in `cpu_micro_p9.txt`):
- Die Tick-Handler der Phase 9 (Quests, WhoKnows, Letters, Stranger) kosten zusammen **0,16–0,23 ms pro Spielminute**. Das sind ≈ 0,007 ms pro Bild. Der größte Teil davon ist Quests mit 0,11–0,16 ms.
- HillRequests mit großer Bitte kostet ≤ 0,16 ms pro Minute.
- Die Phase-9-Figuren kosten im `_process`:
  - Brenneisen: 0,15–0,16 ms pro Bild
  - Johann auf der Bank zusammen mit Brenneisen: 0,15 ms
  - Nachtwächter: 0,10 ms
- **Anteil gesamt: Friedhof 0,17 · Dorf mit Johann 0,16 · Krug 0,17 · Nacht 0,10 ms pro Bild.** Budget ist +0,1 ms, also ✗ knapp (siehe P9-1). Die Systeme selbst liegen weit darunter. Der Anteil kommt fast ganz von `Npc._process` je Figur, wie schon P8-1.

Weitere Werte:
- `QuestLog.entries`: 0,80 ms bei 4 Einträgen. Hochgerechnet auf 30 Einträge bleibt das klar unter 4 ms.
- Spielstand mitten in Phase 9: **300 kB** (Budget < 420 kB) ✓.
- Laden: 0,52 s inkl. Weltwechsel (Budget < 1 s) ✓.

## 5. Prüfung im exportierten pck (Browser-Pfad)

Ablauf:
- Export: `--export-debug "Web" build/webqa/index.html`, ergibt ein pck von 46 MB.
- Lauf: `tools/godot_run.sh --main-pack build/webqa/index.pck --rendering-method gl_compatibility --rendering-driver opengl3 -s /abs/docs/reviews/phase9_wip/qa_p9_pck.gd`.
- Das Skript ist zweistufig: Der Rumpf wird erst geladen, wenn die Autoloads da sind. `docs/` und `tests/` sind nicht im pck.
- `export/convert_text_resources_to_binary=false` ist unverändert und gilt auch im pck.

| Prüfung | Ergebnis |
|---|---|
| Daten im pck: 3 Ketten (16 Schritte, 15 Wahlen), Liste 6 Einträge, 16 Briefe, Bedingungen (PackedStringArray) erhalten, 4 Angebote, 12 große Bitten mit 35 Teilen | ✓ |
| Zeitpläne stranger / kin_sieber_v / watchman: alle Einträge mit Weg; Nachtweg np_sieber 3 Besuche | ✓ |
| Dialoge stranger, kin_sieber_v, sieber_door, kin_sieber, v_washer mit Phase-9-Aktionen | ✓ |
| v7-Stand lädt, Phase 9 offen (Tag 63), Kette bis H4, Reihe 4 offen | ✓ |
| Merkbuch „Vorhaben“ / „Die Liste“ / „Briefe“ öffnen | ✓ (Bilder) |
| Brenneisen am Tor (65, 14:25) auf `stranger_gate` (0,00 m), **Torglocke** läutet (0 → 1), Panel öffnet | ✓ |
| **Johann** auf der Bank (66, 14:30) auf `v_sieber_bench`, Clip `sit_bench` | ✓ |
| **Tag/Nacht**: Sonne 1,55 mittags / 0,45 um 23:30 | ✓ |
| Lieferung von Tag 63 mit Taschenbrief L1 (`lp_l1_carter`), Brief-Karte öffnet | ✓ (anfangs Sondenfehler: Warten auf Tag 64 bei belegter Bahre) – **36/36 PASS** |
| `test_export_packed_arrays` (volle Suite) | ✓ |

## 6. Befundliste (Datei · Schwere · Vorschlag)

| ID | Schwere | Befund | Datei | Vorschlag |
|---|---|---|---|---|
| QA9-01 | **hoch** | An der Esse gewinnt `ForgeLetter` (Priorität 6) gegen die Esse (5). Liegt irgendein verbrennbarer Brief im Beutel, verbrennt [E] den *ersten* Brief, statt Holzkohle zu holen oder zu schmieden. Die Entscheidung ist unwiderruflich und wird nicht abgefragt. (Laut Code; der Bot ruft die Esse direkt auf.) | `src/world/graveyard/forge_letter.gd` | Nur anbieten, wenn auf der Brief-Karte „Verbrennen – Esse“ gewählt wurde; sonst Priorität unter der Esse und eigene Taste oder Auswahl. |
| QA9-02 | **hoch** | Trägt der Spieler eine Leiche zu ihrem offenen Grab und liegt ihr Taschenbrief im Beutel, wird [E] zu „Brief mit ins Grab legen“ statt „Bestatten“ (`_bury_letter_uid` vor `_base_can_interact`). Das passiert bei jeder Lieferung mit Brief: L1–L3 in allen kindly-Läufen. Wer den Brief zustellen will, muss ihn erst in die Truhe legen; der Bot tut das (`notes9`). | `src/entities/grave/grave_plot.gd` | „Bestatten“ bleibt [E]; „Brief mitgeben“ als zweite Wahl (eigene Taste oder Karte). Der Fix-Agent für Grab-Prompts sollte das sehen. |
| QA9-03 | mittel | Am Hüttenofen verbrennt [E] den *ersten* verbrennbaren Brief, nicht den auf der Karte gewählten. Mit Brief im Beutel ist „Am Ofen wärmen“ nicht mehr erreichbar. Gesehen bei kindly9: L3 kam zufällig als erster dran. | `src/entities/stove/stove.gd` | Nur den auf der Karte zum Verbrennen bestimmten Brief nehmen, sonst wärmen. |
| QA9-04 | mittel | Am Grab verdecken Pflege-Aktionen („Grabblumen setzen“ mit Setzlingen im Beutel, „Grabkerze anzünden“) die Phase-9-Prompts „Datum vergleichen“ und „Brief am Grab vorlesen“. Je kindly-Lauf 8 von 8 Vergleichen betroffen. | `src/entities/grave/grave_plot.gd` (`get_interaction_prompt`: `_care_action(…, true)` vor `phase9_action`) | Phase 9 vor der freiwilligen Pflege; oder Pflege nur, wenn der Wunsch des Grabes offen ist. |
| QA9-F2 | mittel | Fuzzer: Ein beschädigter Stand mit einem Nicht-bool in `hill_requests.parts.<id>[n]` bricht mit „Invalid operands 'int' and 'bool'“ ab (`flags[i] == true`). Der Stand ist halb geladen und nach Speichern → Laden nicht stabil. | `src/systems/hill_requests/hill_requests.gd:1602` | `flags[i] is bool and flags[i]`. |
| QA9-T1 | mittel | trader9 erreicht das Kapitel nicht. Der Tag des Anatomen (Präparate, Esse, Schuppen) lässt keine zweite große Bitte zu (Holz fehlt, `hrl_crosses` versäumt, `hrl_old_names` halb). Gesas Botengang verfällt, weil Osrics Abendgespräch nach der Bemerkung „Bahre war belegt“ beim Bot in den Abschied läuft. K3 (Veit/Lambert) wird nicht erreicht, deshalb keine Bestechung. Gate-Ziel §1.5 „auch der verwertende Weg“ ist im Bot nicht belegt. | Bot / Inhalt | Lead: Ist der Weg zu eng (zu kurze Frist großer Bitten, Holz)? Prüfen, ob Osrics Menü nach `remark_skipped` erreichbar bleibt (`data/dialogue/carter.tres`). |
| QA9-B1 | Entscheidung | Münzen: Aktive Wege enden bei **+55 … +64** in 12 Tagen. §2.8 erwartet ≈ +33, die Prüfregel ≤ +50. Grund: Einnahmen aus Bestattungen, Aussegnungen und Trinkgeld über der Schätzung; die Ausgaben passen. lazy9 +93, founder9 +70 in 7 Tagen. Laut §2.8 senkt P2 dann zuerst die Münzen der Dorf-Bitten, das wirkt hier aber kaum (2 × 3–5). | Daten | Benutzer: so lassen oder Grundeinnahmen dämpfen (wie E8-2). Der Test prüft vorerst ≤ +70 (gemessen + Rand) und meldet die Regel. |
| QA9-B2 | Info | Das Kapitel kommt früher als geplant: kindly9 und founder9 bei **B7** (§1.4 plant B10, §10 B9–B11). stay9/public9/silent9 bei B12. | – | Benutzer: OK oder große Bitten / Briefe zäher machen. Test-Band kindly9 B7–B11. |
| QA9-H1 | Entscheidung | HillBot Pflicht 1887 min statt ≤ 1700 (bekannt). **Neu:** Andächtig hat 3 große Bitten halb oder versäumt, Grenze ≤ 2. | – | Benutzer (Alternative aus W1: 2 Plätze / Abklingzeit 6). |
| P9-1 | klein (Budget) | Phase-9-Skriptanteil 0,10–0,17 ms pro Bild, Budget +0,1. Er kommt aus `Npc._process` von Brenneisen (≈ 0,15 ms), Johann und dem Wächter, nicht aus den Systemen (≈ 0,007 ms). | `src/entities/npc/npc.gd` | Wie P8-1: Plan B (`max_full`, Stufe-1-Rate) erst, wenn der Benutzer Ruckler sieht. |
| QA9-05 | klein (Text) | Osric: „[Bitte] Das hier ist für die große Bitte.“ erscheint nie. `hill_ready:carter` ist auch bei großen Bitten wahr, weil `ready_for` die großen Teile mitzählt. Stattdessen gibt der Spieler sie mit „… für die Leute unten“ ab. | `data/dialogue/carter.tres` / `hill_requests.gd` `ready_for` | Bedingung der kleinen Zeile auf kleine Bitten beschränken. |
| QA9-07 | klein (Frage) | Die Hauptkette endet an Licht + 17 auch dann „still“, wenn der Spieler die Kladde nie gelesen hat (lazy9). Das Merkbuch zeigt dann das Ende einer nie begonnenen Kette, D3 kommt trotzdem. | `quests.gd` (`_deadlines`) / Daten | Benutzer/P1: Frist erst ab H1, oder gewollt. |
| QA9-08 | klein | Ein Botenbrief (Gesa) ließ sich noch mit Postgeld aufgeben, nachdem sein Auftrag versäumt war (kindly-Lauf 2: versäumt Tag 72 06:00, aufgegeben 18:41). | `letters.gd` `post_block_reason` | Botenbrief bei versäumtem Auftrag nicht mehr aufgeben, oder Text „kommt zu spät“. |
| QA9-F1 | klein | Fuzzer: Ein Stand mit `sieber_gone` **und** D3-Record lädt unverändert (nur beschädigte Stände). | `corpse_manager.gd` / `who_knows.gd` `post_load` | Beim Laden eine Seite gewinnen lassen. |
| QA9-09 | klein (Testcode) | `phase8_bot.gd::_copy_extract` ruft `_craft5(&"workbench", &"ink")`. `Entities/station_workbench` gibt es nicht, also Engine-Fehler, sobald ein Auszug gewünscht ist und Tinte fehlt. | `tests/integration/phase8_bot.gd` (Lead) | `_craft(world.get_node_by_layout_id("workbench"), &"ink")` wie im Phase9Bot. |
| A9-1 | mittel (Würde) | Veit (sitzend, `veit_gate`) und Brenneisen (`stranger_gate`) stehen ineinander: Veits Beine liegen in Brenneisens Beinen. | Wegpunkte `veit_gate` / `stranger_gate` (W-Welt) | Einen der beiden Punkte ≈ 0,8 m versetzen. Bilder `p9_17`, `perf_p9_01`. |
| A9-2 | mittel | Krug: Brenneisen am Ecktisch steht oder sitzt ohne Sitz an der Wandseite und überlappt eine zweite Figur (dunkle Mütze). | `v_in_inn_stranger` / Inn-Layout | Sitzmarker auf die Bank, eigener freier Platz. Bild `p9_19`. |
| A9-3 | klein | Johann auf Osrics Karren sitzt seitlich außen, die Beine hängen neben dem Rad statt auf der Ladefläche. | `cart_rider.gd` / Sitzversatz (P7-Hinweis „0,45 m“) | Sitz auf die Ladefläche hinten. Bild `p9_10`. |
| A9-4 | (bekannt) | Ende A mit Hanne (`p9_09`): Der Abgang ist unter Erlen und Büschen kaum zu sehen. | – | Der Fix-Agent Erle/Busch arbeitet daran. |
| A9-5 | klein | Gesicht nah: Johann hat fleckige Schatten auf den Wangen (Hutkrempe + Stoppeln) und wirkt schmutzig. | `tools/blender/…` Johann (P7) | Stoppeln heller oder feiner. Bild `faces_close`. |
| A9-6 | klein | Torafel: Das Schild „Große Bitte“ schwebt über dem Zettel und überdeckt die Nadel. | Tafel-Darstellung (W-Welt/P2) | Beschriftung auf den Bogen. Bild `p9_21`. |
| A9-7 | klein (UI) | Merkbuch: 11 Reiter in einer Zeile. Rechts neben der rechten Seite bleiben ≈ 110 px leer. | `src/ui/panels/journal_panel.gd` | Seiten auf die Panelbreite verteilen. Bild `ui_p9_journal_plans`. |
| A9-8 | zu prüfen | Im Compatibility-Renderer (pck) erscheint die Leiche auf der Bahre als schwarze Silhouette. | Material Leiche/Leichentuch | In Forward+ vergleichen. Bild `pck_p9_brenneisen_gate_web.jpg`. |
| UI | ✓ | Brief-Karte und Brenneisen-Panel sind rechts angedockt. Fokus liegt auf der ersten möglichen Wahl, gedimmte Wahlen zeigen ihren Grund. Das Merkbuch ist zentriert. Bei 1280 × 720 nichts abgeschnitten (`ui_p9_*`). | – | – |
| Animation | ✓ / klein | Brenneisen (`anim_stranger`): idle, walk, talk, tip_hat, wait_gate, write. Die Clips sind ruhig, keine Teleports im Bot-Ablauf, der Abgang wird über die echten Wege gesehen. `sit_inn` ohne Stuhl wirkt auf der Tafel wie ein Ausfallschritt; im Spiel siehe A9-2. | – | – |
| Ton | nicht gehört | Im Container gibt es kein Audio-Gerät. Vorhandensein und Lautheit sind in `test_audio_phase9` grün. Die Torglocke läutet im pck (Zähler). | – | Hörprobe durch Audio (17) / Benutzer. |

## 7. Bilder (dieser Lauf)

- **Leistungsbilder, echter Renderer**, im Scratch-Ordner `qa9/perf9`:
  - `perf_p9_01`, `perf_p9_02`
  - `p9_06`, `p9_11`, `p9_17`, `p9_19`, `p9_24b`
  - dieselben Motive wie in W2; die Zahlen stehen in `render_stats_p9_qa.txt`
- **pck im Compatibility-Renderer**, im Scratch-Ordner `qa9/pck`:
  - `pck_p9_brenneisen_gate_web`, `pck_p9_stranger_panel_web`
  - `pck_p9_journal_plans_web`, `pck_p9_journal_list_web`, `pck_p9_journal_letters_web`
  - `pck_p9_johann_bench_web`
  - `pck_p9_village_noon_web`, `pck_p9_village_night_web`
- **Geprüft aus W2:**
  - `docs/reviews/phase9_round1/*`
  - `docs/reviews/phase9_assets/faces_close.jpg`, `anim_stranger.jpg`
