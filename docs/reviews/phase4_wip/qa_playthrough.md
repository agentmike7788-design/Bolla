# Phase 4 – QA-Playthrough, Befunde, Art-/Ton-Prüfung, Performance (W3)

Stand: Branch `vs/p4-qa` (auf `b10fb2c`). Vertrag: `docs/PHASE4_DESIGN.md` (§14 Benutzerentscheidungen, W0-Notizen).

## 1. Befunde (adversariales Review des Phase-4-Diffs `febd2c7..b10fb2c`)

Jeder Befund hat einen Regressionstest (zuerst rot, dann grün), `tests/integration/test_phase4_qa.gd`.

| ID | Schwere | Befund | Behoben | Test |
|---|---|---|---|---|
| QA4-01 | mittel | Funde (Mindestfrische 0,3/0,6) und die Haar-Mindestfrische wurden mit der Frische der **letzten vollen Stunde** aufgelöst: Im Echtzeit-Spiel tickt die Uhr minutenweise (kein `time_skipped`), der CorpseManager verfällt nur bei `hour_changed`. Ein Schritt, der um xx:55 endet, rechnete mit xx:00 – bis zu 59 Min zu frisch; die Verlust-Vorhersage im Panel („noch 0 Min“) widersprach dem Ergebnis. | ✅ `CorpseManager.refresh_decay(id)` (nur für formeltreue Records – eine von Hand gesetzte Frische in Tests/Bildern bleibt); CorpseCare ruft es vor `exam_step`/`exam_all`/Verwerten-Prüfung, der Tisch beim Öffnen des Panels, das Tragen vor „Es riecht streng.“ | `test_exam_step_uses_current_freshness_in_real_time`, `test_hair_uses_current_freshness_in_real_time` |
| QA4-02 | mittel (Art) | Verfallseffekte bei der Standard-Kamera **unsichtbar**: `visibility_range 22 m` wird von der Kamera gemessen, die Standard-Distanz ist 22 m – Leichen hinter dem Fokus zeigten nie Fliegen/Schwaden/Rauch (Zählung 15 statt 37 Partikel). Dazu: P5-Schwade/Rauch so dunkel wie der Rasen, Fliegen < 1 px. | ✅ `visibility_range` 40 m (> zoom_max 34); Schwaden-/Rauch-Textur zur Laufzeit aufgehellt (`WISP_LIFT 0,55`, Pinselstrich bleibt), hellere Farben im Rahmen von §9 (Alpha ≤ 0,35, Quad ≤ 0,6 m), längerer Aufstieg; **Fliegenwolke** (ein Billboard mit gemalten Tintenpunkten, kein Partikel, blendet mit der Fliegenzahl) | `test_decay_effects_reach_beyond_the_camera_zoom`, `test_fly_cloud_follows_the_flies`; Bilder `qa_decay_*`, `qa_smoke_*` |
| QA4-03 | klein (Art) | Grasbüschel stachen durch am Boden liegende Leichen. | ✅ `GrassClearMask`: orientierter Fußabdruck 2,0 × 0,8 m je Leiche am Boden; neu gemalt nur, wenn sich die liegenden Leichen ändern | `test_grass_cleared_under_a_corpse_on_the_ground`; Bild `qa_grass_corpse_8m` |
| QA4-04 | klein (Ton) | Ein Geist, dem nur die **Zähne** genommen wurden (Haar zu brüchig), fragte „Mein Zopf. Wo ist mein Zopf?“. | ✅ `GhostLines.by_harvest` (Haar: die Zopf-Zeile, Zähne: „Mein Mund ist still geworden. Stiller, als der Tod ihn macht.“), der allgemeine `robbed`-Pool neutral („Man hat mir etwas genommen. Ich spür die Stelle noch.“) | `test_robbed_lines_match_the_kind_taken` |
| QA4-05 | kosmetisch | Fundtexte (S1 Blatt, S3 Brief, S4 Marke, S5 Mantel/Liste) und die Schlüssel-Notiz schlossen ‚…' mit ASCII-Apostroph (die Merkbuch-Hinweise korrekt mit ‚…‘). | ✅ ‚…‘ und „Lorenz’“ | Scaffold-Abgleich (Abweichungsliste) |
| QA4-06 | klein (Perf) | Unsichtbare NPCs (Ilse tagsüber und vor dem Zettel, Osric zu Hause) werteten jeden Frame Zeitplan und Pfad aus und animierten ihr Skelett (12–35 µs/Frame je NPC). | ✅ versteckt nur einmal je Spielminute auswerten, Animation pausiert (Osric-Verhalten sichtbar unverändert, alle Npc-Tests grün) | `test_hidden_npc_rests_and_comes_back_on_time` |
| QA4-07 | klein (UI) | Abschluss-Panel „Sechs Gruben“ und Merkbuch-Seite „Ich“ zählten die optionale *Kranichfrau* mit – der würdevolle Bot hätte „Erkenntnisse 6/5“ gesehen. | ✅ `JournalManager.main_insight_count()` | `test_insight_count_of_five_without_the_optional_one` |
| QA4-08 | Art | Ilses Laterne las sich nachts an der Westmauer als schwacher Funke (0,4 / 3 m). | ✅ Energie 2,2, Reichweite 4,5 m, Dämpfung 1,8 – warmer Lichtkreis auf dem Boden und an ihr; weiter **ein** Licht ohne Schatten (Budget unverändert) | Konstanten in `test_night_trade`/`test_graveyard_world`; Bilder `qa_ilse_*` |

Geprüft ohne Befund (Tests der Besitzer + Bot + Fuzzer decken es ab): Speichern/Laden mitten in der Untersuchung, im Räucherfenster, nachts mit Ilse (Vorrat bleibt, kein Auffüllen beim Laden), nach Erkenntnis, im Innenraum; Migration v2→v3 und v1→v3 (Pietät aus der Wertsachen-Historie, Funde, stilles Merkbuch, `stench_day`/`piety_last_day` = Ladetag); Funde genau an der Schwelle (`freshness < min` = verloren); Sperren beim Verwerten (eingekleidet, schon genommen, volles Inventar – nichts geändert); keine Verkaufsschleife (Ilse kauft nur Zopf/Zahnsäckchen, verkauft nur Leinen/Wacholder), Vorrat je Nacht (Nacht ab 12:00); Werkzeug-Gabe einmalig und atomar; höchstens 4 Räucherfenster, nie überlappend; „Voll hergerichtet“ +3 genau einmal je Leiche; Pietät-Erholung genau einmal je Tag (auch mit Laden); Geistergabe 0/2/2/2/3 nach Stufe (bei „Hartherzig“ bleibt die Gabe am Grab für später); Geschichts-Lieferung mit Reservierung, Schlüssel-Rückfall ab Tag 12, Kapitelende – in keiner Strategie ein Softlock; Umbenennung „Kaspar Dorn“ bleibt über Speichern/Laden (im Record); Merkbuch-Verknüpfen nur mit gefundenen Hinweisen und exakter Menge, keine Doppel-Erkenntnis; Gruppen-/`is_inside_tree`-Guards; **keine Warnung, kein Fehler** in 5 × 24–28 Tagen Normalspiel.

## 2. Offene Punkte / Entscheidungen für den Benutzer

- **B1 Münzüberschuss (§2.15):** Je Grab stimmen die Zahlen genau (würdevoll 11,0 Münzen Bezahlung, Ilse ≈ 11 je voll verwerteter Leiche), aber der Überschuss des würdevollen Wegs **wächst** (Tag 14: 80 statt Phase 3: 58; Tag 24: 129), statt – wie §2.15 annimmt – durch Totenhemd und Wacholder zu sinken: Ilses Leinen (2) und die höhere Bezahlung (Q 12–13) überwiegen. Nicht geändert (keine Vertragszahl ist „falsch“); Vorschlag: Münzsenke in Phase 10 oder Totenhemd 4 Leinen.
- **B2 Verwerten, dann voll herrichten:** Haar nehmen und danach waschen/aufbahren/einkleiden ist erlaubt (nur das Einkleiden ist der Schnitt) und bringt trotzdem „Voll hergerichtet“ +3 Pietät: Zopf −4 +3 = −1 bei +4–5 Münzen. Ein Spieler, der jede zweite Leiche so behandelt, bleibt „Rücksichtsvoll“ (Messung: Pietät 37 an Tag 24). Die Vertragserwartung „mixed → Sachlich/Abgebrüht“ gilt nur, wenn an Verwertungstagen nicht hergerichtet wird (so spielt der Bot jetzt). Frage: Soll `full_prep` bei einer beraubten Leiche entfallen? (Nicht geändert.)
- **B3 Budget-Abweichungen der Art-Fixes (§8/§9):** Laterne 2,2 / 4,5 m statt 0,4 / 3 m; `visibility_range` 40 m statt 22 m. Partikelbudget, Alpha ≤ 0,35, Quad ≤ 0,6 m, Lichteranzahl unverändert.
- **CPU-Budget 1,5 ms:** siehe §5 – beide Builds liegen in diesem Container darüber; bitte auf dem Benutzer-PC messen.

## 3. Playthrough-Bot Phase 4

Bot: `tests/integration/phase4_bot.gd` (erweitert `Phase3Bot`) · Test: `tests/integration/test_phase4_playthrough.gd`.
Der Bot spielt ab einem **neuen Spiel** die echte Welt über `interact()` / `request_*()` mit `instant_actions`: Schritte bzw. „Gründlich untersuchen“, Wertsachen, Verwerten, Wacholder (Geschichts-Leichen und wartende Leichen), Waschen / Totenhemd oder Leichentuch / Aufbahren (Werkzeuge an der Werkbank), Holunderwinkel (Pförtchen zuerst), jeden Abend das Merkbuch (alle vier Seiten geöffnet) und Verknüpfen aller vollständigen Erkenntnisse (Reihenfolge umgedreht). Ab dem Zettel geht er um 23:05 zu Ilse: ihr Dialog läuft über den **echten `DialogueRunner`** (`data/dialogue/trader.tres`: Werkzeug, Fragen nach Lorenz / dem Zeichen / der Blüte, „Handeln.“), Verkauf/Kauf wie ihr Panel (`NightTrade.sell/buy`). Käufe bei Osric bilden die Dialog-Aktionen nach (Leinen 3, Wacholder 2).

Geprüft je Strategie: keine Engine-Fehler, **keine Warnungen**, keine Bot-Probleme (jede gewollte Handlung möglich → kein Softlock), Qualität 0…270, Ruf 0…100, Pietät −100…100, Münzen ≥ 0.

| Strategie | Verhalten | Tage | Erwartung (Vertrag §10) | Ergebnis |
|---|---|---|---|---|
| reverent | gründlich, voll hergerichtet (Totenhemd), Wacholder bei Geschichts-Leichen, verknüpft, verwertet nie | 24 | Kapitel ≤ Tag 22, 5 Erkenntnisse, „Andächtig“ | ✅ Kapitel **Tag 19**, 5 + *Kranichfrau*, „Andächtig“ ab Tag 16, 17 hergerichtet, 0 verloren |
| harvester | nimmt Wertsachen, Haar und Zähne, nur Leichentuch, verkauft bei Ilse, keine Zier | 28 | Kapitel ≤ Tag 28, Pietät ≤ −60 | ✅ Kapitel **Tag 24**, „Hartherzig“ ab Tag 9 (−100 ab Tag 15), 28 verwertet, Ruf pendelt 6–40 (Verrufen → Lieferung nur an ungeraden Tagen) |
| procrastinator | bearbeitet jede Leiche erst am Folgetag, nie Wacholder, keine Zier | 28 | ≥ 3 verlorene Funde, Gestank, Schlüssel-Rückfall, Kapitel | ✅ 27 verlorene Funde, 15× Gestank am Tor, Rückfall Tag 12, Kapitel **Tag 25** |
| mixed | würdevoll; an ungeraden Tagen ein Verwerter-Tag (nur Zopf, nur Tuch) | 24 | „Sachlich“ oder „Abgebrüht“ | ✅ „Sachlich“ (Pietät 10…18), Kapitel Tag 19 – siehe B2 |
| save_load4 | wie reverent, lädt **jeden Morgen** den Autosave | 24 | bitgleich zu reverent | ✅ alle 24 Tageszeilen identisch |

Münzen gegen §2.15: würdevoll **11,0** Münzen Bezahlung je Grab (Vertrag 11); verwertend 4,4 je Grab (Vertrag ≈ 6 – niedriger, weil „Verrufen“ keinen Ruf-Bonus gibt) und **11** je voll verwerteter Leiche bei Ilse (Vertrag 9–11) + 38 aus Wertsachen. Endstände: würdevoll 129 (Tag 24), verwertend 183 (Tag 28), mixed 131, procrastinator 15. Als Assertions im Test (würdevoll 9–13 je Grab, Ilse 8–13 je Leiche, verwertend 3–8 je Grab).
Phase-3-Bot (`test_phase3_playthrough.gd`, 6 Strategien × 14 Tage, §2.14): unverändert grün (diligent „Ehrwürdig“ Tag 9, neglectful/hoarder nie).

**Balancing:** keine Daten geändert (siehe B1/B2 in §2).

### Tag für Tag
#### diligent

`PLAYTHROUGH diligent  spent 119  gifts 24  income 170`

| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −0 | 9 | Verwahrlost | 26 | Unauffällig | 12 | – | – |
| 2 | 2 | 19 | 5 | −0 | 24 | Ordentlich | 31 | Unauffällig | 7 | – | – |
| 3 | 3 | 28 | 5 | −0 | 33 | Gepflegt | 35 | Geachtet | 12 | – | – |
| 4 | 4 | 38 | 5 | −0 | 43 | Gepflegt | 43 | Geachtet | 10 | ✓ | – |
| 5 | 5 | 48 | 5 | −0 | 53 | Würdevoll | 47 | Geachtet | 11 | ✓ | – |
| 6 | 6 | 57 | 8 | −0 | 65 | Würdevoll | 55 | Geschätzt | 11 | ✓ | ✓ |
| 7 | 7 | 67 | 17 | −0 | 84 | Würdevoll | 61 | Geschätzt | 14 | ✓ | ✓ |
| 8 | 8 | 76 | 20 | −0 | 96 | Würdevoll | 68 | Geschätzt | 19 | ✓ | ✓ |
| 9 | 9 | 85 | 20 | −0 | 105 | Ehrwürdig | 74 | Geschätzt | 28 | ✓ | ✓ |
| 10 | 10 | 95 | 26 | −0 | 121 | Ehrwürdig | 82 | Gerühmt | 36 | ✓ | ✓ |
| 11 | 11 | 104 | 29 | −0 | 133 | Ehrwürdig | 89 | Gerühmt | 43 | ✓ | ✓ |
| 12 | 12 | 113 | 29 | −0 | 142 | Ehrwürdig | 94 | Gerühmt | 54 | ✓ | ✓ |
| 13 | 12 | 113 | 30 | −0 | 143 | Ehrwürdig | 96 | Gerühmt | 54 | ✓ | ✓ |
| 14 | 12 | 113 | 30 | −0 | 143 | Ehrwürdig | 97 | Gerühmt | 56 | ✓ | ✓ |

#### neglectful

`PLAYTHROUGH neglectful  spent 119  gifts 24  income 157`

| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −3 | 6 | Verwahrlost | 26 | Unauffällig | 12 | – | – |
| 2 | 2 | 19 | 5 | −4 | 20 | Ordentlich | 30 | Unauffällig | 7 | – | – |
| 3 | 3 | 28 | 5 | −10 | 23 | Ordentlich | 33 | Unauffällig | 11 | – | – |
| 4 | 4 | 38 | 5 | −10 | 33 | Gepflegt | 37 | Geachtet | 11 | – | – |
| 5 | 5 | 48 | 8 | −17 | 39 | Gepflegt | 44 | Geachtet | 12 | ✓ | – |
| 6 | 6 | 57 | 11 | −20 | 48 | Gepflegt | 47 | Geachtet | 14 | ✓ | – |
| 7 | 7 | 67 | 14 | −24 | 57 | Würdevoll | 53 | Geachtet | 12 | ✓ | ✓ |
| 8 | 8 | 76 | 17 | −33 | 60 | Würdevoll | 55 | Geschätzt | 16 | ✓ | ✓ |
| 9 | 9 | 85 | 20 | −34 | 71 | Würdevoll | 59 | Geschätzt | 22 | ✓ | ✓ |
| 10 | 10 | 95 | 26 | −35 | 86 | Würdevoll | 65 | Geschätzt | 29 | ✓ | ✓ |
| 11 | 11 | 104 | 29 | −45 | 88 | Würdevoll | 69 | Geschätzt | 34 | ✓ | ✓ |
| 12 | 12 | 113 | 29 | −52 | 90 | Würdevoll | 72 | Geschätzt | 43 | ✓ | ✓ |
| 13 | 12 | 113 | 30 | −53 | 90 | Würdevoll | 73 | Geschätzt | 42 | ✓ | ✓ |
| 14 | 12 | 113 | 30 | −75 | 68 | Würdevoll | 70 | Geschätzt | 43 | ✓ | ✓ |

#### sloppy

`PLAYTHROUGH sloppy  spent 66  gifts 0  income 73`

| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −3 | 6 | Verwahrlost | 26 | Unauffällig | 10 | – | – |
| 2 | 2 | 14 | 0 | −4 | 10 | Verwahrlost | 21 | Unauffällig | 8 | – | – |
| 3 | 3 | 23 | 0 | −10 | 13 | Verwahrlost | 27 | Unauffällig | 7 | ✓ | – |
| 4 | 4 | 30 | 0 | −10 | 20 | Ordentlich | 23 | Unauffällig | 13 | ✓ | – |
| 5 | 5 | 37 | 0 | −17 | 20 | Ordentlich | 21 | Unauffällig | 17 | ✓ | – |
| 6 | 6 | 46 | 0 | −20 | 26 | Ordentlich | 27 | Unauffällig | 18 | ✓ | – |
| 7 | 7 | 53 | 0 | −24 | 29 | Ordentlich | 25 | Unauffällig | 27 | ✓ | – |
| 8 | 8 | 62 | 0 | −33 | 29 | Ordentlich | 30 | Unauffällig | 29 | ✓ | – |
| 9 | 9 | 71 | 0 | −39 | 32 | Gepflegt | 34 | Unauffällig | 32 | ✓ | – |
| 10 | 9 | 71 | 0 | −40 | 31 | Ordentlich | 36 | Geachtet | 34 | ✓ | – |
| 11 | 9 | 71 | 0 | −45 | 26 | Ordentlich | 36 | Geachtet | 36 | ✓ | – |
| 12 | 9 | 71 | 0 | −60 | 11 | Verwahrlost | 33 | Unauffällig | 37 | ✓ | – |
| 13 | 9 | 71 | 0 | −63 | 8 | Verwahrlost | 31 | Unauffällig | 38 | ✓ | – |
| 14 | 9 | 71 | 0 | −66 | 5 | Verwahrlost | 29 | Unauffällig | 39 | ✓ | – |

#### hoarder

`PLAYTHROUGH hoarder  spent 93  gifts 0  income 138`

| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −0 | 9 | Verwahrlost | 26 | Unauffällig | 10 | – | – |
| 2 | 2 | 19 | 0 | −0 | 19 | Ordentlich | 30 | Unauffällig | 8 | – | – |
| 3 | 3 | 28 | 0 | −0 | 28 | Ordentlich | 34 | Unauffällig | 7 | – | – |
| 4 | 4 | 38 | 0 | −0 | 38 | Gepflegt | 38 | Geachtet | 8 | – | – |
| 5 | 5 | 48 | 0 | −0 | 48 | Gepflegt | 46 | Geachtet | 10 | ✓ | – |
| 6 | 6 | 57 | 0 | −0 | 57 | Würdevoll | 50 | Geachtet | 10 | ✓ | – |
| 7 | 7 | 67 | 0 | −0 | 67 | Würdevoll | 55 | Geschätzt | 10 | ✓ | – |
| 8 | 8 | 76 | 0 | −0 | 76 | Würdevoll | 63 | Geschätzt | 13 | ✓ | ✓ |
| 9 | 9 | 85 | 0 | −0 | 85 | Würdevoll | 67 | Geschätzt | 20 | ✓ | ✓ |
| 10 | 10 | 95 | 0 | −0 | 95 | Würdevoll | 72 | Geschätzt | 28 | ✓ | ✓ |
| 11 | 11 | 104 | 0 | −0 | 104 | Würdevoll | 77 | Geschätzt | 34 | ✓ | ✓ |
| 12 | 12 | 113 | 0 | −0 | 113 | Würdevoll | 82 | Gerühmt | 42 | ✓ | ✓ |
| 13 | 12 | 113 | 0 | −0 | 113 | Würdevoll | 84 | Gerühmt | 46 | ✓ | ✓ |
| 14 | 12 | 113 | 0 | −0 | 113 | Würdevoll | 85 | Gerühmt | 50 | ✓ | ✓ |

#### save_load

`PLAYTHROUGH save_load  spent 119  gifts 24  income 170`

| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −0 | 9 | Verwahrlost | 26 | Unauffällig | 12 | – | – |
| 2 | 2 | 19 | 5 | −0 | 24 | Ordentlich | 31 | Unauffällig | 7 | – | – |
| 3 | 3 | 28 | 5 | −0 | 33 | Gepflegt | 35 | Geachtet | 12 | – | – |
| 4 | 4 | 38 | 5 | −0 | 43 | Gepflegt | 43 | Geachtet | 10 | ✓ | – |
| 5 | 5 | 48 | 5 | −0 | 53 | Würdevoll | 47 | Geachtet | 11 | ✓ | – |
| 6 | 6 | 57 | 8 | −0 | 65 | Würdevoll | 55 | Geschätzt | 11 | ✓ | ✓ |
| 7 | 7 | 67 | 17 | −0 | 84 | Würdevoll | 61 | Geschätzt | 14 | ✓ | ✓ |
| 8 | 8 | 76 | 20 | −0 | 96 | Würdevoll | 68 | Geschätzt | 19 | ✓ | ✓ |
| 9 | 9 | 85 | 20 | −0 | 105 | Ehrwürdig | 74 | Geschätzt | 28 | ✓ | ✓ |
| 10 | 10 | 95 | 26 | −0 | 121 | Ehrwürdig | 82 | Gerühmt | 36 | ✓ | ✓ |
| 11 | 11 | 104 | 29 | −0 | 133 | Ehrwürdig | 89 | Gerühmt | 43 | ✓ | ✓ |
| 12 | 12 | 113 | 29 | −0 | 142 | Ehrwürdig | 94 | Gerühmt | 54 | ✓ | ✓ |
| 13 | 12 | 113 | 30 | −0 | 143 | Ehrwürdig | 96 | Gerühmt | 54 | ✓ | ✓ |
| 14 | 12 | 113 | 30 | −0 | 143 | Ehrwürdig | 97 | Gerühmt | 56 | ✓ | ✓ |

#### early_sleeper

`PLAYTHROUGH early_sleeper  spent 119  gifts 0  income 144`

| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −0 | 9 | Verwahrlost | 26 | Unauffällig | 10 | – | – |
| 2 | 2 | 19 | 5 | −0 | 24 | Ordentlich | 31 | Unauffällig | 6 | – | – |
| 3 | 3 | 28 | 5 | −0 | 33 | Gepflegt | 35 | Geachtet | 9 | – | – |
| 4 | 4 | 38 | 5 | −0 | 43 | Gepflegt | 40 | Geachtet | 8 | – | – |
| 5 | 5 | 48 | 5 | −0 | 53 | Würdevoll | 45 | Geachtet | 10 | – | – |
| 6 | 6 | 57 | 5 | −0 | 62 | Würdevoll | 53 | Geachtet | 10 | ✓ | – |
| 7 | 7 | 67 | 8 | −0 | 75 | Würdevoll | 58 | Geschätzt | 10 | ✓ | – |
| 8 | 8 | 76 | 11 | −0 | 87 | Würdevoll | 67 | Geschätzt | 10 | ✓ | ✓ |
| 9 | 9 | 85 | 17 | −0 | 102 | Ehrwürdig | 73 | Geschätzt | 11 | ✓ | ✓ |
| 10 | 10 | 95 | 26 | −0 | 121 | Ehrwürdig | 81 | Gerühmt | 14 | ✓ | ✓ |
| 11 | 11 | 104 | 29 | −0 | 133 | Ehrwürdig | 89 | Gerühmt | 19 | ✓ | ✓ |
| 12 | 12 | 113 | 29 | −0 | 142 | Ehrwürdig | 94 | Gerühmt | 28 | ✓ | ✓ |
| 13 | 12 | 113 | 30 | −0 | 143 | Ehrwürdig | 96 | Gerühmt | 28 | ✓ | ✓ |
| 14 | 12 | 113 | 30 | −0 | 143 | Ehrwürdig | 97 | Gerühmt | 30 | ✓ | ✓ |

#### reverent

`PLAYTHROUGH4 reverent  chapter day 19  spent(Osric) 105  gifts 39  income 318 (burials 198 / 18 = 11.0, stipend 81)  ilse +0/−89  valuables 0  stench 0  key_fallback false  stories [&"s1_quendel", &"s2_hemmerling", &"s3_wernstein", &"s4_uhlig", &"s5_moor"]`

| Tag | Gräber | Qualität | Stufe | Ruf | Münzen | Pietät | Pietät-Stufe | Hinweise | Erk. | verloren | hergerichtet | verwertet | Ilse-Verk. | Gesch. | Holunder | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | Verwahrlost | 26 | 12 | 0 | Sachlich | 0 | 0 | 0 | 0 | 0 | 0 | 0 | – | – |
| 2 | 2 | 26 | Ordentlich | 31 | 8 | 6 | Sachlich | 0 | 0 | 0 | 1 | 0 | 0 | 0 | – | – |
| 3 | 3 | 37 | Gepflegt | 36 | 11 | 9 | Sachlich | 2 | 0 | 0 | 2 | 0 | 0 | 0 | – | – |
| 4 | 4 | 52 | Würdevoll | 45 | 9 | 15 | Sachlich | 4 | 0 | 0 | 3 | 0 | 0 | 0 | – | – |
| 5 | 5 | 64 | Würdevoll | 51 | 10 | 21 | Rücksichtsvoll | 5 | 0 | 0 | 4 | 0 | 0 | 0 | – | – |
| 6 | 6 | 78 | Würdevoll | 60 | 10 | 24 | Rücksichtsvoll | 7 | 1 | 0 | 5 | 0 | 0 | 1 | – | – |
| 7 | 7 | 96 | Würdevoll | 67 | 11 | 30 | Rücksichtsvoll | 7 | 1 | 0 | 6 | 0 | 0 | 1 | – | – |
| 8 | 8 | 111 | Ehrwürdig | 75 | 15 | 33 | Rücksichtsvoll | 7 | 1 | 0 | 7 | 0 | 0 | 1 | – | – |
| 9 | 9 | 123 | Ehrwürdig | 85 | 23 | 36 | Rücksichtsvoll | 10 | 2 | 0 | 8 | 0 | 0 | 2 | ✓ | – |
| 10 | 10 | 142 | Ehrwürdig | 91 | 33 | 42 | Rücksichtsvoll | 10 | 2 | 0 | 9 | 0 | 0 | 2 | ✓ | – |
| 11 | 11 | 157 | Ehrwürdig | 95 | 42 | 45 | Rücksichtsvoll | 10 | 2 | 0 | 10 | 0 | 0 | 2 | ✓ | – |
| 12 | 12 | 169 | Ehrwürdig | 98 | 55 | 48 | Rücksichtsvoll | 10 | 2 | 0 | 11 | 0 | 0 | 2 | ✓ | – |
| 13 | 13 | 181 | Ehrwürdig | 100 | 67 | 51 | Rücksichtsvoll | 12 | 4 | 0 | 12 | 0 | 0 | 3 | ✓ | – |
| 14 | 14 | 193 | Ehrwürdig | 100 | 80 | 54 | Rücksichtsvoll | 12 | 4 | 0 | 13 | 0 | 0 | 3 | ✓ | – |
| 15 | 15 | 205 | Ehrwürdig | 100 | 93 | 57 | Rücksichtsvoll | 12 | 4 | 0 | 14 | 0 | 0 | 3 | ✓ | – |
| 16 | 16 | 217 | Ehrwürdig | 100 | 105 | 60 | Andächtig | 14 | 5 | 0 | 15 | 0 | 0 | 4 | ✓ | – |
| 17 | 17 | 230 | Ehrwürdig | 100 | 119 | 66 | Andächtig | 14 | 5 | 0 | 16 | 0 | 0 | 4 | ✓ | – |
| 18 | 17 | 231 | Ehrwürdig | 100 | 113 | 66 | Andächtig | 14 | 5 | 0 | 16 | 0 | 0 | 4 | ✓ | – |
| 19 | 18 | 243 | Ehrwürdig | 100 | 125 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 20 | 18 | 245 | Ehrwürdig | 100 | 121 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 21 | 18 | 248 | Ehrwürdig | 100 | 121 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 22 | 18 | 249 | Ehrwürdig | 100 | 123 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 23 | 18 | 249 | Ehrwürdig | 100 | 126 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 24 | 18 | 249 | Ehrwürdig | 100 | 129 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |

#### harvester

`PLAYTHROUGH4 harvester  chapter day 24  spent(Osric) 48  gifts 4  income 102 (burials 80 / 18 = 4.4, stipend 18)  ilse +154/−68  valuables 38  stench 0  key_fallback false  stories [&"s1_quendel", &"s2_hemmerling", &"s3_wernstein", &"s4_uhlig", &"s5_moor"]`

| Tag | Gräber | Qualität | Stufe | Ruf | Münzen | Pietät | Pietät-Stufe | Hinweise | Erk. | verloren | hergerichtet | verwertet | Ilse-Verk. | Gesch. | Holunder | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | Verwahrlost | 26 | 12 | 0 | Sachlich | 0 | 0 | 0 | 0 | 0 | 0 | 0 | – | – |
| 2 | 2 | 16 | Ordentlich | 23 | 7 | -5 | Sachlich | 0 | 0 | 0 | 0 | 0 | 0 | 0 | – | – |
| 3 | 3 | 25 | Ordentlich | 28 | 11 | -4 | Sachlich | 2 | 0 | 0 | 0 | 0 | 0 | 0 | – | – |
| 4 | 4 | 32 | Gepflegt | 29 | 8 | -9 | Sachlich | 4 | 0 | 0 | 0 | 0 | 0 | 0 | – | – |
| 5 | 5 | 36 | Gepflegt | 19 | 23 | -25 | Abgebrüht | 5 | 0 | 0 | 0 | 2 | 2 | 0 | – | – |
| 6 | 6 | 42 | Gepflegt | 17 | 32 | -35 | Abgebrüht | 7 | 1 | 0 | 0 | 4 | 4 | 1 | – | – |
| 7 | 7 | 46 | Gepflegt | 7 | 48 | -51 | Abgebrüht | 7 | 1 | 0 | 0 | 6 | 6 | 1 | – | – |
| 8 | 7 | 46 | Gepflegt | 13 | 48 | -50 | Abgebrüht | 7 | 1 | 0 | 0 | 6 | 6 | 1 | – | – |
| 9 | 8 | 52 | Würdevoll | 15 | 49 | -60 | Hartherzig | 9 | 2 | 0 | 0 | 8 | 8 | 2 | 🔑 | – |
| 10 | 9 | 56 | Würdevoll | 10 | 66 | -76 | Hartherzig | 10 | 2 | 0 | 0 | 10 | 10 | 2 | ✓ | – |
| 11 | 10 | 62 | Würdevoll | 8 | 77 | -86 | Hartherzig | 10 | 2 | 0 | 0 | 12 | 12 | 2 | ✓ | – |
| 12 | 10 | 62 | Würdevoll | 14 | 77 | -85 | Hartherzig | 10 | 2 | 0 | 0 | 12 | 12 | 2 | ✓ | – |
| 13 | 11 | 68 | Würdevoll | 12 | 89 | -95 | Hartherzig | 12 | 4 | 0 | 0 | 14 | 14 | 3 | ✓ | – |
| 14 | 11 | 68 | Würdevoll | 18 | 90 | -94 | Hartherzig | 12 | 4 | 0 | 0 | 14 | 14 | 3 | ✓ | – |
| 15 | 12 | 74 | Würdevoll | 16 | 103 | -100 | Hartherzig | 12 | 4 | 0 | 0 | 16 | 16 | 3 | ✓ | – |
| 16 | 13 | 80 | Würdevoll | 14 | 114 | -100 | Hartherzig | 14 | 5 | 0 | 0 | 18 | 18 | 4 | ✓ | – |
| 17 | 14 | 84 | Würdevoll | 6 | 130 | -100 | Hartherzig | 14 | 5 | 0 | 0 | 20 | 20 | 4 | ✓ | – |
| 18 | 14 | 84 | Würdevoll | 12 | 130 | -99 | Hartherzig | 14 | 5 | 0 | 0 | 20 | 20 | 4 | ✓ | – |
| 19 | 15 | 90 | Würdevoll | 10 | 141 | -100 | Hartherzig | 18 | 6 | 0 | 0 | 22 | 22 | 5 | ✓ | – |
| 20 | 15 | 90 | Würdevoll | 16 | 142 | -99 | Hartherzig | 18 | 6 | 0 | 0 | 22 | 22 | 5 | ✓ | – |
| 21 | 16 | 96 | Würdevoll | 14 | 152 | -100 | Hartherzig | 18 | 6 | 0 | 0 | 24 | 24 | 5 | ✓ | – |
| 22 | 16 | 96 | Würdevoll | 20 | 153 | -99 | Hartherzig | 18 | 6 | 0 | 0 | 24 | 24 | 5 | ✓ | – |
| 23 | 17 | 102 | Würdevoll | 18 | 165 | -100 | Hartherzig | 18 | 6 | 0 | 0 | 26 | 26 | 5 | ✓ | – |
| 24 | 18 | 108 | Würdevoll | 16 | 178 | -100 | Hartherzig | 18 | 6 | 0 | 0 | 28 | 28 | 5 | ✓ | ✓ |
| 25 | 18 | 108 | Würdevoll | 22 | 179 | -99 | Hartherzig | 18 | 6 | 0 | 0 | 28 | 28 | 5 | ✓ | ✓ |
| 26 | 18 | 108 | Würdevoll | 28 | 180 | -98 | Hartherzig | 18 | 6 | 0 | 0 | 28 | 28 | 5 | ✓ | ✓ |
| 27 | 18 | 108 | Würdevoll | 34 | 181 | -97 | Hartherzig | 18 | 6 | 0 | 0 | 28 | 28 | 5 | ✓ | ✓ |
| 28 | 18 | 108 | Würdevoll | 40 | 183 | -96 | Hartherzig | 18 | 6 | 0 | 0 | 28 | 28 | 5 | ✓ | ✓ |

#### procrastinator

`PLAYTHROUGH4 procrastinator  chapter day 25  spent(Osric) 102  gifts 2  income 193 (burials 128 / 18 = 7.1, stipend 63)  ilse +0/−32  valuables 0  stench 15  key_fallback true  stories [&"s1_quendel", &"s2_hemmerling", &"s3_wernstein", &"s4_uhlig", &"s5_moor"]`

| Tag | Gräber | Qualität | Stufe | Ruf | Münzen | Pietät | Pietät-Stufe | Hinweise | Erk. | verloren | hergerichtet | verwertet | Ilse-Verk. | Gesch. | Holunder | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 0 | 0 | Verwahrlost | 23 | 3 | 0 | Sachlich | 0 | 0 | 0 | 0 | 0 | 0 | 0 | – | – |
| 2 | 1 | 6 | Verwahrlost | 22 | 7 | -1 | Sachlich | 0 | 0 | 1 | 0 | 0 | 0 | 0 | – | – |
| 3 | 2 | 13 | Verwahrlost | 23 | 7 | 0 | Sachlich | 1 | 0 | 2 | 0 | 0 | 0 | 0 | – | – |
| 4 | 3 | 19 | Ordentlich | 24 | 8 | -1 | Sachlich | 1 | 0 | 4 | 0 | 0 | 0 | 0 | – | – |
| 5 | 4 | 26 | Ordentlich | 27 | 9 | 0 | Sachlich | 2 | 0 | 5 | 0 | 0 | 0 | 0 | – | – |
| 6 | 5 | 33 | Gepflegt | 30 | 7 | 1 | Sachlich | 3 | 0 | 7 | 0 | 0 | 0 | 1 | – | – |
| 7 | 6 | 39 | Gepflegt | 34 | 7 | 0 | Sachlich | 4 | 1 | 10 | 0 | 0 | 0 | 1 | – | – |
| 8 | 6 | 39 | Gepflegt | 37 | 9 | 0 | Sachlich | 4 | 1 | 10 | 0 | 0 | 0 | 1 | – | – |
| 9 | 6 | 39 | Gepflegt | 39 | 8 | 0 | Sachlich | 4 | 1 | 10 | 0 | 0 | 0 | 1 | – | – |
| 10 | 6 | 39 | Gepflegt | 40 | 10 | 0 | Sachlich | 4 | 1 | 10 | 0 | 0 | 0 | 1 | – | – |
| 11 | 6 | 39 | Gepflegt | 41 | 9 | 0 | Sachlich | 5 | 1 | 10 | 0 | 0 | 0 | 1 | 🔑 | – |
| 12 | 6 | 39 | Gepflegt | 44 | 8 | 0 | Sachlich | 5 | 2 | 10 | 0 | 0 | 0 | 1 | 🔑 | – |
| 13 | 6 | 39 | Gepflegt | 44 | 4 | 0 | Sachlich | 5 | 2 | 10 | 0 | 0 | 0 | 2 | 🔑 | – |
| 14 | 7 | 45 | Gepflegt | 46 | 8 | -1 | Sachlich | 7 | 2 | 13 | 0 | 0 | 0 | 2 | ✓ | – |
| 15 | 8 | 51 | Würdevoll | 46 | 9 | -2 | Sachlich | 7 | 2 | 14 | 0 | 0 | 0 | 3 | ✓ | – |
| 16 | 9 | 57 | Würdevoll | 47 | 10 | -3 | Sachlich | 8 | 3 | 18 | 0 | 0 | 0 | 3 | ✓ | – |
| 17 | 10 | 64 | Würdevoll | 52 | 8 | -1 | Sachlich | 8 | 3 | 19 | 0 | 0 | 0 | 4 | ✓ | – |
| 18 | 11 | 70 | Würdevoll | 54 | 11 | -2 | Sachlich | 9 | 3 | 23 | 0 | 0 | 0 | 4 | ✓ | – |
| 19 | 12 | 76 | Würdevoll | 57 | 9 | -3 | Sachlich | 9 | 3 | 25 | 0 | 0 | 0 | 5 | ✓ | – |
| 20 | 13 | 84 | Würdevoll | 63 | 17 | -2 | Sachlich | 15 | 4 | 26 | 0 | 0 | 0 | 5 | ✓ | – |
| 21 | 14 | 91 | Würdevoll | 66 | 24 | 0 | Sachlich | 15 | 4 | 27 | 0 | 0 | 0 | 5 | ✓ | – |
| 22 | 15 | 97 | Würdevoll | 69 | 30 | -1 | Sachlich | 15 | 4 | 28 | 0 | 0 | 0 | 5 | ✓ | – |
| 23 | 16 | 104 | Würdevoll | 72 | 36 | 0 | Sachlich | 15 | 4 | 29 | 0 | 0 | 0 | 5 | ✓ | – |
| 24 | 17 | 110 | Würdevoll | 75 | 43 | -1 | Sachlich | 15 | 4 | 31 | 0 | 0 | 0 | 5 | ✓ | – |
| 25 | 18 | 116 | Würdevoll | 80 | 52 | -2 | Sachlich | 15 | 4 | 32 | 0 | 0 | 0 | 5 | ✓ | ✓ |
| 26 | 18 | 116 | Würdevoll | 83 | 56 | -1 | Sachlich | 15 | 4 | 32 | 0 | 0 | 0 | 5 | ✓ | ✓ |
| 27 | 18 | 116 | Würdevoll | 85 | 60 | 0 | Sachlich | 15 | 4 | 32 | 0 | 0 | 0 | 5 | ✓ | ✓ |
| 28 | 18 | 116 | Würdevoll | 87 | 64 | 0 | Sachlich | 15 | 4 | 32 | 0 | 0 | 0 | 5 | ✓ | ✓ |

#### mixed

`PLAYTHROUGH4 mixed  chapter day 19  spent(Osric) 114  gifts 20  income 277 (burials 178 / 18 = 9.9, stipend 79)  ilse +32/−69  valuables 0  stench 0  key_fallback false  stories [&"s1_quendel", &"s2_hemmerling", &"s3_wernstein", &"s4_uhlig", &"s5_moor"]`

| Tag | Gräber | Qualität | Stufe | Ruf | Münzen | Pietät | Pietät-Stufe | Hinweise | Erk. | verloren | hergerichtet | verwertet | Ilse-Verk. | Gesch. | Holunder | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | Verwahrlost | 26 | 12 | 0 | Sachlich | 0 | 0 | 0 | 0 | 0 | 0 | 0 | – | – |
| 2 | 2 | 26 | Ordentlich | 31 | 8 | 6 | Sachlich | 0 | 0 | 0 | 1 | 0 | 0 | 0 | – | – |
| 3 | 3 | 35 | Gepflegt | 36 | 10 | 6 | Sachlich | 2 | 0 | 0 | 1 | 0 | 0 | 0 | – | – |
| 4 | 4 | 50 | Würdevoll | 45 | 11 | 12 | Sachlich | 4 | 0 | 0 | 2 | 0 | 0 | 0 | – | – |
| 5 | 5 | 59 | Würdevoll | 48 | 12 | 11 | Sachlich | 5 | 0 | 0 | 2 | 1 | 1 | 0 | – | – |
| 6 | 6 | 70 | Würdevoll | 54 | 11 | 14 | Sachlich | 7 | 1 | 0 | 3 | 1 | 1 | 1 | – | – |
| 7 | 7 | 82 | Würdevoll | 61 | 14 | 13 | Sachlich | 7 | 1 | 0 | 3 | 2 | 2 | 1 | – | – |
| 8 | 8 | 99 | Würdevoll | 68 | 11 | 16 | Sachlich | 7 | 1 | 0 | 4 | 2 | 2 | 1 | – | – |
| 9 | 9 | 110 | Ehrwürdig | 76 | 15 | 12 | Sachlich | 10 | 2 | 0 | 4 | 3 | 3 | 2 | ✓ | – |
| 10 | 10 | 129 | Ehrwürdig | 84 | 24 | 18 | Sachlich | 10 | 2 | 0 | 5 | 3 | 3 | 2 | ✓ | – |
| 11 | 11 | 140 | Ehrwürdig | 89 | 33 | 14 | Sachlich | 10 | 2 | 0 | 5 | 4 | 4 | 2 | ✓ | – |
| 12 | 12 | 152 | Ehrwürdig | 94 | 46 | 17 | Sachlich | 10 | 2 | 0 | 6 | 4 | 4 | 2 | ✓ | – |
| 13 | 13 | 160 | Ehrwürdig | 95 | 58 | 13 | Sachlich | 12 | 4 | 0 | 6 | 5 | 5 | 3 | ✓ | – |
| 14 | 14 | 172 | Ehrwürdig | 98 | 71 | 16 | Sachlich | 12 | 4 | 0 | 7 | 5 | 5 | 3 | ✓ | – |
| 15 | 15 | 180 | Ehrwürdig | 98 | 84 | 12 | Sachlich | 12 | 4 | 0 | 7 | 6 | 6 | 3 | ✓ | – |
| 16 | 16 | 192 | Ehrwürdig | 100 | 95 | 15 | Sachlich | 14 | 5 | 0 | 8 | 6 | 6 | 4 | ✓ | – |
| 17 | 17 | 201 | Ehrwürdig | 99 | 110 | 14 | Sachlich | 14 | 5 | 0 | 8 | 7 | 7 | 4 | ✓ | – |
| 18 | 17 | 202 | Ehrwürdig | 99 | 110 | 14 | Sachlich | 14 | 5 | 0 | 8 | 7 | 7 | 4 | ✓ | – |
| 19 | 18 | 210 | Ehrwürdig | 99 | 123 | 10 | Sachlich | 18 | 6 | 0 | 8 | 8 | 8 | 5 | ✓ | ✓ |
| 20 | 18 | 212 | Ehrwürdig | 99 | 123 | 10 | Sachlich | 18 | 6 | 0 | 8 | 8 | 8 | 5 | ✓ | ✓ |
| 21 | 18 | 215 | Ehrwürdig | 99 | 123 | 10 | Sachlich | 18 | 6 | 0 | 8 | 8 | 8 | 5 | ✓ | ✓ |
| 22 | 18 | 216 | Ehrwürdig | 99 | 125 | 10 | Sachlich | 18 | 6 | 0 | 8 | 8 | 8 | 5 | ✓ | ✓ |
| 23 | 18 | 216 | Ehrwürdig | 99 | 128 | 10 | Sachlich | 18 | 6 | 0 | 8 | 8 | 8 | 5 | ✓ | ✓ |
| 24 | 18 | 216 | Ehrwürdig | 99 | 131 | 10 | Sachlich | 18 | 6 | 0 | 8 | 8 | 8 | 5 | ✓ | ✓ |

#### save_load4

`PLAYTHROUGH4 save_load4  chapter day 19  spent(Osric) 105  gifts 39  income 318 (burials 198 / 18 = 11.0, stipend 81)  ilse +0/−89  valuables 0  stench 0  key_fallback false  stories [&"s1_quendel", &"s2_hemmerling", &"s3_wernstein", &"s4_uhlig", &"s5_moor"]`

| Tag | Gräber | Qualität | Stufe | Ruf | Münzen | Pietät | Pietät-Stufe | Hinweise | Erk. | verloren | hergerichtet | verwertet | Ilse-Verk. | Gesch. | Holunder | Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | Verwahrlost | 26 | 12 | 0 | Sachlich | 0 | 0 | 0 | 0 | 0 | 0 | 0 | – | – |
| 2 | 2 | 26 | Ordentlich | 31 | 8 | 6 | Sachlich | 0 | 0 | 0 | 1 | 0 | 0 | 0 | – | – |
| 3 | 3 | 37 | Gepflegt | 36 | 11 | 9 | Sachlich | 2 | 0 | 0 | 2 | 0 | 0 | 0 | – | – |
| 4 | 4 | 52 | Würdevoll | 45 | 9 | 15 | Sachlich | 4 | 0 | 0 | 3 | 0 | 0 | 0 | – | – |
| 5 | 5 | 64 | Würdevoll | 51 | 10 | 21 | Rücksichtsvoll | 5 | 0 | 0 | 4 | 0 | 0 | 0 | – | – |
| 6 | 6 | 78 | Würdevoll | 60 | 10 | 24 | Rücksichtsvoll | 7 | 1 | 0 | 5 | 0 | 0 | 1 | – | – |
| 7 | 7 | 96 | Würdevoll | 67 | 11 | 30 | Rücksichtsvoll | 7 | 1 | 0 | 6 | 0 | 0 | 1 | – | – |
| 8 | 8 | 111 | Ehrwürdig | 75 | 15 | 33 | Rücksichtsvoll | 7 | 1 | 0 | 7 | 0 | 0 | 1 | – | – |
| 9 | 9 | 123 | Ehrwürdig | 85 | 23 | 36 | Rücksichtsvoll | 10 | 2 | 0 | 8 | 0 | 0 | 2 | ✓ | – |
| 10 | 10 | 142 | Ehrwürdig | 91 | 33 | 42 | Rücksichtsvoll | 10 | 2 | 0 | 9 | 0 | 0 | 2 | ✓ | – |
| 11 | 11 | 157 | Ehrwürdig | 95 | 42 | 45 | Rücksichtsvoll | 10 | 2 | 0 | 10 | 0 | 0 | 2 | ✓ | – |
| 12 | 12 | 169 | Ehrwürdig | 98 | 55 | 48 | Rücksichtsvoll | 10 | 2 | 0 | 11 | 0 | 0 | 2 | ✓ | – |
| 13 | 13 | 181 | Ehrwürdig | 100 | 67 | 51 | Rücksichtsvoll | 12 | 4 | 0 | 12 | 0 | 0 | 3 | ✓ | – |
| 14 | 14 | 193 | Ehrwürdig | 100 | 80 | 54 | Rücksichtsvoll | 12 | 4 | 0 | 13 | 0 | 0 | 3 | ✓ | – |
| 15 | 15 | 205 | Ehrwürdig | 100 | 93 | 57 | Rücksichtsvoll | 12 | 4 | 0 | 14 | 0 | 0 | 3 | ✓ | – |
| 16 | 16 | 217 | Ehrwürdig | 100 | 105 | 60 | Andächtig | 14 | 5 | 0 | 15 | 0 | 0 | 4 | ✓ | – |
| 17 | 17 | 230 | Ehrwürdig | 100 | 119 | 66 | Andächtig | 14 | 5 | 0 | 16 | 0 | 0 | 4 | ✓ | – |
| 18 | 17 | 231 | Ehrwürdig | 100 | 113 | 66 | Andächtig | 14 | 5 | 0 | 16 | 0 | 0 | 4 | ✓ | – |
| 19 | 18 | 243 | Ehrwürdig | 100 | 125 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 20 | 18 | 245 | Ehrwürdig | 100 | 121 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 21 | 18 | 248 | Ehrwürdig | 100 | 121 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 22 | 18 | 249 | Ehrwürdig | 100 | 123 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 23 | 18 | 249 | Ehrwürdig | 100 | 126 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |
| 24 | 18 | 249 | Ehrwürdig | 100 | 129 | 69 | Andächtig | 18 | 6 | 0 | 17 | 0 | 0 | 5 | ✓ | ✓ |

## 4. Save-Fuzzer (`tests/integration/test_save_fuzzer.gd`)

Neu: `test_fuzz_v3_save_of_a_phase4_game` – ein v3-Stand **mitten in Phase 4** (Bot „mixed“, Tag 7, 23:30: Leiche auf dem Tisch mit 2 von 4 Schritten, laufendes Räucherfenster, Zopf genommen, Hinweise + Erkenntnis im Merkbuch, Ilse an der Mauer mit halb verkauftem Leinen). Gekürzte Dateien, JSON- und Native-Mutationen wie bisher, dazu **80 gezielte Mutationen nur der Phase-4-Teile** (`journal`, `night_trade`, `npc_trader`, Pietät-/Verwertungs-Statistiken, alle neuen Record-Felder, Geschichts-Buchhaltung, Phase-4-Flags). Erlaubte Ausgänge wie Phase 3 (abgelehnt mit Meldung und unverändertem Spiel – oder geladen, konsistent und stabil über ein weiteres Speichern/Laden); zusätzlich geprüft: Pietät −100…100 und im Merkbuch nur bekannte Hinweise/Erkenntnisse.
Ergebnis: v3-Phase-3-Stand 97 geladen / 79 abgelehnt · **v3-Phase-4-Stand 179 / 77** · v2-Fixtures 205 / 147 · v1-Fixtures 298 / 230 – kein Absturz, kein halb angewendeter Stand.

## 5. Art- und Ton-Prüfung (ART STYLE LOCK, kein Gore)

Vorher/Nachher-Ausschnitte (`tools/qa/qa_p4_shots.gd`, Standard-Kamera 22 m bzw. Zoom-Minimum 12 m):
`qa_decay_day_22m.jpg`, `qa_decay_night_22m.jpg`, `qa_decay_day_12m.jpg`, `qa_smoke_day_22m.jpg`, `qa_ilse_night_22m.jpg`, `qa_ilse_night_12m.jpg`, `qa_grass_corpse_8m.jpg`.
- **Verfall (QA4-02):** Schwaden jetzt als fahl-olivfarbene Pinselkringel lesbar, bei Tag und Nacht; Fliegen als feine dunkle Wolke über dem Körper; alles gemalt/angedeutet, keine Wunden, kein Grün-Türkis. Wacholderrauch als heller, dünner Faden über der Schale. Maler-Shader unverändert.
- **Ilse (QA4-08):** warmer Lichtkreis auf Mauerstein, Boden und Mantel; Silhouette vor dem Lichtkreis klar, bei 22 m als Figur mit Laterne erkennbar.
- **Gras (QA4-03):** keine Büschel mehr durch liegende Leichen.
- **Texte:** alle neuen deutschen Texte gelesen (Funde, Hinweise, Erkenntnisse, Geschichts-Ankunft, Ilse-Dialog, Osric-Phase-4-Knoten, Geisterzeilen, Hinweise/Notizen, UI-Texte). Ton trocken-melancholisch und konsistent, kein Spott. Korrigiert: QA4-04 (Zopf-Zeile), QA4-05 (Anführungszeichen). Bewusst gelassen: „Was brauchst du.“ (Osric „kühl, knapp“), „Gepäck“ in UI-Texten wie in Phase 3.

## 6. Performance (CPU/Frame, headless)

Container verrauscht (±0,3 ms); Median über 600 Frames, abwechselnd gemessen.
**Gleiche Phase-3-Inszenierung** (`graveyard_shots_phase3.gd --cpu`), Phase-3-Build `febd2c7` vs. Phase-4-Build, 3 Durchläufe:

| | Tag P3 | Tag P4 | Nacht P3 | Nacht P4 |
|---|---|---|---|---|
| vor QA4-06 | 1,46 / 1,35 / 1,65 | 1,96 / 2,06 / 1,85 | 1,60 / 1,41 / 1,39 | 2,40 / 2,15 / 2,71 |
| nach QA4-06 | 1,38 / 1,67 / 1,50 | 1,98 / 2,26 / 2,07 | 1,61 / 1,51 / 2,25 | 2,29 / 2,35 / 2,15 |

→ Phase 4 kostet auf gleicher Inszenierung ≈ **+0,5 ms (Tag) / +0,5–0,8 ms (Nacht)**. Phase-4-Probe (3 verwesende Leichen, Ilse, Geister, 37 Partikel): Tag 2,0–2,7 ms, Nacht 2,2–2,7 ms (Median).
Zuordnung (`tools/qa/qa_p4_cpu.gd`, `qa_p4_cpu2.gd`, Mikro-Messungen): versteckte NPCs 12–35 µs/Frame je NPC → 0,3 µs (QA4-06); `CemeteryStatus.phase4_state` 34 µs je Spielminute; HUD-Zielzeile 0,6–1,3 ms je Spielminute (Phase-3-Anteil, in beiden Builds gleich); GhostManager 2–10 µs. **Alle Phase-4-Knoten im selben Lauf abgeschaltet → keine messbare Änderung** (Median 2,40–2,50 vs. 2,40–2,93 ms). Der Rest des Deltas liegt nicht in Phase-4-Skripten; er wächst mit den +331 Knoten der Holunderwinkel-Welt (Engine-Seite) und ist headless ohne Profiler nicht weiter zuzuordnen. Das Budget 1,5 ms verfehlen in diesem Container schon der Phase-3-Build (1,4–2,2 ms) → bitte auf dem Benutzer-PC messen.
Render (`docs/reviews/phase4_round1/render_stats.txt`): Spiel-Zoom-Maximum 24 m 432–441 k Dreiecke, 228–293 Draw Calls, 15 sichtbare / 2 Schatten-Omnis, 37 Partikel (≤ 60) – im Budget; die Übersichten aus 40 m (außerhalb des Spiel-Zooms) 529–530 k.

## 7. Screenshot-Satz Gate G4 (`docs/reviews/phase4_round1/`, 1280×720, echte Phase-4-Welt)

Welt (`graveyard_shots_phase4.gd --jpg`): `world_p4_01_overview_day`, `_02_holunderwinkel_locked`, `_03_story_corpse_table`, `_04_smoke_bowl`, `_05_decay_vfx_night`, `_05b_decay_vfx_close`, `_05c_decay_day` (neu), `_06_holunderwinkel_open`, `_07_ilse_west_wall_night`, `_08_holunderwinkel_night`, `_09_overview_end`, `perf_p4_01…03`.
UI (`ui_screenshots.gd --phase4`, jetzt über der echten Welt – alle Systemknoten kommen vom Builder): `ui_table_exam` (Geschichts-Leiche, verlorener Fund, Verlust-Hinweis), `ui_table_prep`, `ui_table_harvest` (Folgenzeile, „Wirklich?“), `ui_journal_clues` (roter Faden, offene Fragen), `ui_journal_insight`, `ui_journal_self`, `ui_door_note` (neu), `ui_osric_p4` (neu, Osrics Phase-4-Einführung), `ui_ilse_dialogue` (neu, Begrüßung „Abgebrüht“, Ilse sichtbar), `ui_trade_ilse` (Ilse neben dem Panel sichtbar), `ui_ghost_robbed` (neu, beraubt/unruhig neben hergerichtet/zufrieden, beide sprechen), `ui_chapter_six_pits` (5/5, Schlusszeile „Lorenz Aschau lebt …“).
Alle Bilder angesehen; behoben dabei: Ilse im Handels-/Dialogbild außerhalb (Kamera-Grenzen und Viewport-Skalierung im Director), Geister-Sprechblasen zu kurz, Kapitel-Panel „1/5“ bei gesetztem „Nicht Lorenz“ (jetzt echt verknüpft) bzw. „6/5“ (QA4-07). Die HUD-Friedhofsqualität 0 in den UI-Bildern ist richtig (die Inszenierung pflegt 8 Tage nicht → Pflegeabzug).
